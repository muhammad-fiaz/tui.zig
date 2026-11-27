//! Deterministic in-memory backend for headless rendering, tests, and snapshots.

const std = @import("std");
const core_root = @import("../core/root.zig");
const event_root = @import("../event/root.zig");
const caps_mod = @import("capabilities.zig");
const ansi_mod = @import("ansi.zig");
const testing = std.testing;

pub const Buffer = core_root.Buffer;
pub const BufferDiff = core_root.BufferDiff;
pub const Rect = core_root.Rect;
pub const Size = core_root.Size;
pub const Position = core_root.Position;
pub const Event = event_root.Event;
pub const TerminalCapabilities = caps_mod.TerminalCapabilities;

/// Headless in-memory terminal backend recording rendered cells, cursor state, and queued events.
pub const MemoryBackend = struct {
    allocator: std.mem.Allocator,
    buffer: Buffer,
    cursor_pos: Position = .origin,
    cursor_visible: bool = true,
    cursor_shape: core_root.CursorShape = .default_shape,
    in_alternate_screen: bool = false,
    raw_mode: bool = false,
    mouse_enabled: bool = false,
    window_title: [256]u8 = @splat(0),
    window_title_len: usize = 0,
    caps: TerminalCapabilities,
    events: std.ArrayList(Event) = .empty,
    event_head: usize = 0,
    ansi_log: std.ArrayList(u8) = .empty,
    scrollback_lines: std.ArrayList(u8) = .empty,
    snapshot_buf: std.ArrayList(u8) = .empty,

    /// Allocates a `MemoryBackend` of `sz` columns by rows. Must be freed with `deinit()`.
    pub fn init(allocator: std.mem.Allocator, sz: Size) std.mem.Allocator.Error!MemoryBackend {
        var buffer = try Buffer.init(allocator, Rect.fromPosSize(.origin, sz));
        errdefer buffer.deinit();
        return .{
            .allocator = allocator,
            .buffer = buffer,
            .caps = .{
                .color = .trueColor,
                .is_tty = true,
                .ansi_sequences = true,
                .unicode = true,
                .alternate_screen = true,
                .mouse = true,
                .synchronized_output = false,
                .hyperlinks = true,
                .kitty_keyboard = true,
                .resize_events = true,
            },
        };
    }

    pub fn deinit(self: *MemoryBackend) void {
        self.buffer.deinit();
        self.events.deinit(self.allocator);
        self.ansi_log.deinit(self.allocator);
        self.scrollback_lines.deinit(self.allocator);
        self.snapshot_buf.deinit(self.allocator);
    }

    pub fn setTitle(self: *MemoryBackend, title: []const u8) void {
        const n = @min(title.len, self.window_title.len);
        @memcpy(self.window_title[0..n], title[0..n]);
        self.window_title_len = n;
    }

    pub fn titleSlice(self: *const MemoryBackend) []const u8 {
        return self.window_title[0..self.window_title_len];
    }

    /// Appends inserted plain-text buffer lines above an inline viewport for test verification.
    pub fn recordInsertedBuffer(self: *MemoryBackend, inserted: *const Buffer) !void {
        const text = try inserted.toPlainTextAlloc(self.allocator);
        defer self.allocator.free(text);
        if (self.scrollback_lines.items.len > 0) {
            try self.scrollback_lines.append(self.allocator, '\n');
        }
        try self.scrollback_lines.appendSlice(self.allocator, text);
    }

    /// Returns recorded scrollback text accumulated via `insertBefore`.
    pub fn scrollbackSlice(self: *const MemoryBackend) []const u8 {
        return self.scrollback_lines.items;
    }

    pub fn resize(self: *MemoryBackend, new_size: Size) std.mem.Allocator.Error!void {
        try self.buffer.resize(Rect.fromPosSize(.origin, new_size));
        try self.pushEvent(.{ .resize = new_size });
    }

    pub fn pushEvent(self: *MemoryBackend, ev: Event) std.mem.Allocator.Error!void {
        try self.events.append(self.allocator, ev);
    }

    pub fn pollEvent(self: *MemoryBackend) Event {
        if (self.event_head >= self.events.items.len) {
            self.events.clearRetainingCapacity();
            self.event_head = 0;
            return .none;
        }
        const ev = self.events.items[self.event_head];
        self.event_head += 1;
        if (self.event_head >= self.events.items.len) {
            self.events.clearRetainingCapacity();
            self.event_head = 0;
        }
        return ev;
    }

    pub fn drawDiff(self: *MemoryBackend, diff_iter: *BufferDiff) void {
        while (diff_iter.nextEntry()) |entry| {
            if (self.buffer.getMut(entry.x, entry.y)) |dst| {
                dst.* = entry.cell.*;
                if (entry.cell.symbol_len == 255) {
                    if (entry.cell.overflow) |ov| {
                        self.buffer.setCellSymbol(dst, ov) catch {};
                    }
                }
            }
        }
    }

    pub fn clear(self: *MemoryBackend, clear_type: ansi_mod.ClearType) void {
        if (clear_type == .all) {
            self.buffer.clear();
        }
    }

    pub fn size(self: *const MemoryBackend) Size {
        return self.buffer.area.size();
    }

    /// Renders the rendered plain text snapshot into an internal capacity-retaining buffer
    /// owned by this backend (`deinit` releases it automatically).
    pub fn snapshot(self: *MemoryBackend) std.mem.Allocator.Error![]const u8 {
        try self.buffer.writePlainText(self.allocator, &self.snapshot_buf);
        return self.snapshot_buf.items;
    }
};

test "memory backend stores events and snapshots" {
    var mb = try MemoryBackend.init(testing.allocator, Size.init(6, 2));
    defer mb.deinit();

    try mb.pushEvent(.{ .key = .{ .code = .enter } });
    try testing.expectEqual(event_root.KeyCode.enter, mb.pollEvent().key.code);
    try testing.expectEqual(Event.none, mb.pollEvent());
}
