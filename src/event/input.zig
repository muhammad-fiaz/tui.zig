//! Input handling for keyboard and mouse events.

const std = @import("std");
const builtin = @import("builtin");
const events = @import("events.zig");

pub const Event = events.Event;
pub const KeyEvent = events.KeyEvent;
pub const MouseEvent = events.MouseEvent;
pub const Modifiers = events.Modifiers;
pub const MouseKind = events.MouseKind;
pub const MouseButton = events.MouseButton;

/// Key representation
pub const Key = union(enum) {
    /// Regular character
    char: u21,

    /// Function keys
    f: u8, // F1-F12

    /// Special keys
    enter,
    tab,
    backspace,
    escape,
    space,
    insert,
    delete,
    home,
    end,
    page_up,
    page_down,

    /// Arrow keys
    up,
    down,
    left,
    right,

    /// Null (no key)
    null_key,

    /// Unknown key with raw bytes
    unknown: u8,

    /// Create a key from a character
    pub fn fromChar(c: u21) Key {
        return .{ .char = c };
    }

    /// Check if this is a printable character
    pub fn isPrintable(self: Key) bool {
        return switch (self) {
            .char => |c| c >= 0x20 and c != 0x7F,
            else => false,
        };
    }

    /// Get the character if this is a char key
    pub fn toChar(self: Key) ?u21 {
        return switch (self) {
            .char => |c| c,
            .space => ' ',
            .tab => '\t',
            .enter => '\n',
            else => null,
        };
    }

    /// Check if keys are equal
    pub fn eql(self: Key, other: Key) bool {
        return std.meta.eql(self, other);
    }
};

/// Input reader for parsing terminal input
pub const InputReader = struct {
    allocator: std.mem.Allocator,

    /// Buffer for accumulating partial escape sequences
    buffer: [32]u8 = undefined,
    buffer_len: usize = 0,

    /// Timeout for escape sequences in nanoseconds
    escape_timeout_ns: u64 = 50_000_000, // 50ms

    /// Last input time
    last_input_time: i128 = 0,

    pub fn init(allocator: std.mem.Allocator) InputReader {
        return .{
            .allocator = allocator,
        };
    }

    /// Parse input bytes into events
    pub fn parse(self: *InputReader, bytes: []const u8) !?Event {
        if (bytes.len == 0) return null;

        // Check for escape sequences
        if (bytes[0] == 0x1B) {
            return self.parseEscapeSequence(bytes);
        }

        // Control characters
        if (bytes[0] < 0x20) {
            return self.parseControlChar(bytes[0]);
        }

        // Regular UTF-8 character
        return self.parseUtf8Char(bytes);
    }

    /// Parse escape sequence
    fn parseEscapeSequence(self: *InputReader, bytes: []const u8) !?Event {
        _ = self;

        if (bytes.len == 1) {
            // Just escape key
            return Event{ .key = .{ .key = .escape } };
        }

        // CSI sequences (ESC [)
        if (bytes.len >= 2 and bytes[1] == '[') {
            return parseCSI(bytes);
        }

        // SS3 sequences (ESC O) - often used for function keys
        if (bytes.len >= 2 and bytes[1] == 'O') {
            return parseSS3(bytes);
        }

        // Alt + key
        if (bytes.len >= 2 and bytes[1] >= 0x20) {
            const key = if (bytes[1] < 0x7F)
                Key{ .char = bytes[1] }
            else
                Key{ .unknown = bytes[1] };

            return Event{
                .key = .{
                    .key = key,
                    .modifiers = .{ .alt = true },
                },
            };
        }

        return Event{ .key = .{ .key = .escape } };
    }

    /// Parse CSI (Control Sequence Introducer) sequence
    fn parseCSI(bytes: []const u8) ?Event {
        if (bytes.len < 3) return null;

        // Check for mouse events
        if (bytes.len >= 3 and bytes[2] == '<') {
            return parseMouseSGR(bytes);
        }

        if (bytes.len >= 3 and bytes[2] == 'M') {
            return parseMouseX10(bytes);
        }

        // Arrow keys
        if (bytes.len >= 3) {
            const key: ?Key = switch (bytes[2]) {
                'A' => .up,
                'B' => .down,
                'C' => .right,
                'D' => .left,
                'H' => .home,
                'F' => .end,
                else => null,
            };

            if (key) |k| {
                return Event{ .key = .{ .key = k } };
            }
        }

        // Function keys and special keys with parameters
        if (bytes.len >= 4) {
            return parseFunctionKey(bytes);
        }

        return null;
    }

    /// Parse function key sequences
    fn parseFunctionKey(bytes: []const u8) ?Event {
        // Format: ESC [ num ~
        if (bytes[bytes.len - 1] == '~') {
            // Extract the number
            var num: u8 = 0;
            var i: usize = 2;
            while (i < bytes.len - 1 and bytes[i] >= '0' and bytes[i] <= '9') : (i += 1) {
                num = num * 10 + (bytes[i] - '0');
            }

            const key: ?Key = switch (num) {
                1, 7 => .home,
                2 => .insert,
                3 => .delete,
                4, 8 => .end,
                5 => .page_up,
                6 => .page_down,
                11 => .{ .f = 1 },
                12 => .{ .f = 2 },
                13 => .{ .f = 3 },
                14 => .{ .f = 4 },
                15 => .{ .f = 5 },
                17 => .{ .f = 6 },
                18 => .{ .f = 7 },
                19 => .{ .f = 8 },
                20 => .{ .f = 9 },
                21 => .{ .f = 10 },
                23 => .{ .f = 11 },
                24 => .{ .f = 12 },
                else => null,
            };

            if (key) |k| {
                return Event{ .key = .{ .key = k } };
            }
        }

        return null;
    }

    /// Parse SS3 sequences
    fn parseSS3(bytes: []const u8) ?Event {
        if (bytes.len < 3) return null;

        const key: ?Key = switch (bytes[2]) {
            'A' => .up,
            'B' => .down,
            'C' => .right,
            'D' => .left,
            'H' => .home,
            'F' => .end,
            'P' => .{ .f = 1 },
            'Q' => .{ .f = 2 },
            'R' => .{ .f = 3 },
            'S' => .{ .f = 4 },
            else => null,
        };

        if (key) |k| {
            return Event{ .key = .{ .key = k } };
        }

        return null;
    }

    /// Parse SGR-encoded mouse events (modern format)
    fn parseMouseSGR(bytes: []const u8) ?Event {
        // Format: ESC [ < Cb ; Cx ; Cy M/m
        if (bytes.len < 9) return null;

        var i: usize = 3;
        var cb: u16 = 0;
        var cx: u16 = 0;
        var cy: u16 = 0;

        // Parse button code
        while (i < bytes.len and bytes[i] >= '0' and bytes[i] <= '9') : (i += 1) {
            cb = cb * 10 + @as(u16, bytes[i] - '0');
        }
        if (i >= bytes.len or bytes[i] != ';') return null;
        i += 1;

        // Parse X coordinate
        while (i < bytes.len and bytes[i] >= '0' and bytes[i] <= '9') : (i += 1) {
            cx = cx * 10 + @as(u16, bytes[i] - '0');
        }
        if (i >= bytes.len or bytes[i] != ';') return null;
        i += 1;

        // Parse Y coordinate
        while (i < bytes.len and bytes[i] >= '0' and bytes[i] <= '9') : (i += 1) {
            cy = cy * 10 + @as(u16, bytes[i] - '0');
        }

        if (i >= bytes.len) return null;
        const is_release = bytes[i] == 'm';

        // Decode button
        const button: MouseButton = switch (cb & 0x03) {
            0 => .left,
            1 => .middle,
            2 => .right,
            3 => .none,
            else => .none,
        };

        const kind: MouseKind = if (is_release)
            .release
        else if (cb & 0x20 != 0)
            .drag
        else if (cb & 0x40 != 0)
            if (cb & 0x01 != 0) .scroll_down else .scroll_up
        else
            .press;

        return Event{
            .mouse = .{
                .kind = kind,
                .x = if (cx > 0) cx - 1 else 0,
                .y = if (cy > 0) cy - 1 else 0,
                .button = button,
                .modifiers = .{
                    .shift = cb & 0x04 != 0,
                    .alt = cb & 0x08 != 0,
                    .ctrl = cb & 0x10 != 0,
                },
            },
        };
    }

    /// Parse X10 mouse events (legacy format)
    fn parseMouseX10(bytes: []const u8) ?Event {
        if (bytes.len < 6) return null;

        const cb = bytes[3] -| 32;
        const cx = bytes[4] -| 33;
        const cy = bytes[5] -| 33;

        const button: MouseButton = switch (cb & 0x03) {
            0 => .left,
            1 => .middle,
            2 => .right,
            3 => .none,
            else => .none,
        };

        return Event{
            .mouse = .{
                .kind = if (cb & 0x03 == 3) .release else .press,
                .x = cx,
                .y = cy,
                .button = button,
            },
        };
    }

    /// Parse control character
    fn parseControlChar(self: *InputReader, byte: u8) ?Event {
        _ = self;

        const key: Key = switch (byte) {
            0x00 => .{ .char = ' ' }, // Ctrl+Space/Ctrl+@ -> treat as null
            0x08, 0x7F => .backspace,
            0x09 => .tab,
            0x0A, 0x0D => .enter,
            0x1B => .escape,
            else => if (byte < 27)
                // Ctrl+A through Ctrl+Z
                Key{ .char = @as(u21, byte) + 'a' - 1 }
            else
                Key{ .unknown = byte },
        };

        var mods = Modifiers{};
        if (byte > 0 and byte < 27) {
            mods.ctrl = true;
        }

        return Event{
            .key = .{
                .key = key,
                .modifiers = mods,
            },
        };
    }

    /// Parse UTF-8 character
    fn parseUtf8Char(self: *InputReader, bytes: []const u8) ?Event {
        _ = self;

        const cp = std.unicode.utf8Decode(bytes) catch {
            return Event{
                .key = .{ .key = .{ .unknown = bytes[0] } },
            };
        };

        return Event{
            .key = .{ .key = .{ .char = cp } },
        };
    }
};

/// Non-blocking input reader using poll/select
pub const AsyncInputReader = struct {
    reader: InputReader,
    stdin: std.fs.File,

    pub fn init(allocator: std.mem.Allocator) AsyncInputReader {
        const stdin = if (builtin.os.tag == .windows)
            std.fs.File{ .handle = std.os.windows.GetStdHandle(std.os.windows.STD_INPUT_HANDLE) catch unreachable }
        else
            std.fs.File{ .handle = std.posix.STDIN_FILENO };
        return .{
            .reader = InputReader.init(allocator),
            .stdin = stdin,
        };
    }

    /// Poll for input with optional timeout
    pub fn poll(self: *AsyncInputReader, timeout_ms: ?u32) !?Event {
        _ = timeout_ms;

        // Read available bytes
        var buf: [32]u8 = undefined;
        const bytes_read = self.stdin.read(&buf) catch |err| {
            if (err == error.WouldBlock) return null;
            return err;
        };

        if (bytes_read == 0) return null;

        return self.reader.parse(buf[0..bytes_read]);
    }
};

test "key creation" {
    const key = Key.fromChar('a');
    try std.testing.expect(key.isPrintable());
    try std.testing.expectEqual(@as(u21, 'a'), key.toChar().?);
}

test "key equality" {
    const key1 = Key{ .char = 'a' };
    const key2 = Key{ .char = 'a' };
    const key3 = Key{ .char = 'b' };

    try std.testing.expect(key1.eql(key2));
    try std.testing.expect(!key1.eql(key3));
}

test "control character parsing" {
    const allocator = std.testing.allocator;
    var reader = InputReader.init(allocator);

    // Ctrl+C
    const event = try reader.parse(&.{0x03});
    try std.testing.expect(event != null);
}
