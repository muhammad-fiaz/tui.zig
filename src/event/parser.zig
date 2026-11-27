//! Incremental, zero-hot-path-allocation VT/ANSI/CSI/SS3/SGR-mouse/Kitty/UTF-8 input parser.
//!
//! Bytes fed via `feed()` are parsed incrementally into `Event` values without
//! allocating memory for ordinary keystrokes or mouse movements. Bracketed paste
//! payloads accumulate into an explicitly owned reusable `ArrayList(u8)`.

const std = @import("std");
const event_mod = @import("event.zig");
const testing = std.testing;

pub const Event = event_mod.Event;
pub const KeyEvent = event_mod.KeyEvent;
pub const KeyCode = event_mod.KeyCode;
pub const KeyModifiers = event_mod.KeyModifiers;
pub const KeyEventKind = event_mod.KeyEventKind;
pub const MouseEvent = event_mod.MouseEvent;
pub const MouseButton = event_mod.MouseButton;
pub const MouseEventKind = event_mod.MouseEventKind;

/// Incremental ANSI / UTF-8 input stream decoder.
pub const EventParser = struct {
    allocator: std.mem.Allocator,
    buf: [512]u8 = undefined,
    len: usize = 0,
    in_paste: bool = false,
    paste_buf: std.ArrayList(u8) = .empty,

    /// Creates an `EventParser` using `allocator` only for reusable bracketed paste buffering.
    pub fn init(allocator: std.mem.Allocator) EventParser {
        return .{ .allocator = allocator };
    }

    /// Releases any paste buffer capacity owned by the parser.
    pub fn deinit(self: *EventParser) void {
        self.paste_buf.deinit(self.allocator);
        self.len = 0;
        self.in_paste = false;
    }

    /// Appends raw terminal input bytes into the internal parse ring/staging buffer.
    /// Returns the number of bytes accepted.
    pub fn feed(self: *EventParser, bytes: []const u8) usize {
        const space = self.buf.len - self.len;
        const count = @min(space, bytes.len);
        if (count > 0) {
            @memcpy(self.buf[self.len..][0..count], bytes[0..count]);
            self.len += count;
        }
        return count;
    }

    /// True if buffered bytes are waiting to be parsed or form a pending Escape sequence.
    pub fn hasPending(self: *const EventParser) bool {
        return self.len > 0;
    }

    /// Parses the next complete `Event` from buffered bytes, or returns `null` if more bytes are needed.
    /// If `flush_escape` is true and only a lone `0x1B` remains, emits `.escape` immediately.
    pub fn nextEvent(self: *EventParser, flush_escape: bool) std.mem.Allocator.Error!?Event {
        if (self.in_paste) {
            return try self.parsePasteChunk();
        }
        if (self.len == 0) return null;

        const b0 = self.buf[0];

        // Escape sequences.
        if (b0 == 0x1B) {
            if (self.len == 1) {
                if (!flush_escape) return null;
                self.consume(1);
                return .{ .key = .{ .code = .escape } };
            }
            const b1 = self.buf[1];
            if (b1 == '[') {
                return try self.parseCsi();
            }
            if (b1 == 'O') {
                return self.parseSs3();
            }
            // Alt + Escape
            if (b1 == 0x1B and self.len == 2) {
                if (!flush_escape) return null;
                self.consume(2);
                return .{ .key = .{ .code = .escape, .modifiers = KeyModifiers.alt_only } };
            }
            // Alt + ASCII/UTF-8 character
            const ev = self.parseSingleCharAt(1, KeyModifiers.alt_only) orelse return null;
            return ev;
        }

        // Plain control / UTF-8 character.
        return self.parseSingleCharAt(0, .none);
    }

    fn consume(self: *EventParser, n: usize) void {
        if (n >= self.len) {
            self.len = 0;
            return;
        }
        const rem = self.len - n;
        std.mem.copyForwards(u8, self.buf[0..rem], self.buf[n..self.len]);
        self.len = rem;
    }

    fn parseSingleCharAt(self: *EventParser, offset: usize, base_mods: KeyModifiers) ?Event {
        if (offset >= self.len) return null;
        const b = self.buf[offset];

        if (b < 0x80) {
            self.consume(offset + 1);
            return .{ .key = decodeControlOrAscii(b, base_mods) };
        }

        const seq_len = std.unicode.utf8ByteSequenceLength(b) catch {
            self.consume(offset + 1);
            return .{ .key = .{ .code = .{ .char = b }, .modifiers = base_mods } };
        };
        if (offset + seq_len > self.len) return null;

        const cp: u21 = switch (seq_len) {
            2 => std.unicode.utf8Decode2(self.buf[offset..][0..2].*) catch 0xFFFD,
            3 => std.unicode.utf8Decode3(self.buf[offset..][0..3].*) catch 0xFFFD,
            4 => std.unicode.utf8Decode4(self.buf[offset..][0..4].*) catch 0xFFFD,
            else => 0xFFFD,
        };
        self.consume(offset + seq_len);
        return .{ .key = .{ .code = .{ .char = cp }, .modifiers = base_mods } };
    }

    fn decodeControlOrAscii(b: u8, base_mods: KeyModifiers) KeyEvent {
        var mods = base_mods;
        return switch (b) {
            '\r', '\n' => .{ .code = .enter, .modifiers = mods },
            '\t' => .{ .code = .tab, .modifiers = mods },
            0x08, 0x7F => .{ .code = .backspace, .modifiers = mods },
            0x00 => blk: {
                mods.ctrl = true;
                break :blk .{ .code = .{ .char = ' ' }, .modifiers = mods };
            },
            0x01...0x07, 0x0B...0x0C, 0x0E...0x1A => blk: {
                mods.ctrl = true;
                break :blk .{ .code = .{ .char = 'a' + (b - 1) }, .modifiers = mods };
            },
            0x1C...0x1F => blk: {
                mods.ctrl = true;
                break :blk .{ .code = .{ .char = b + '@' }, .modifiers = mods };
            },
            else => .{ .code = .{ .char = b }, .modifiers = mods },
        };
    }

    fn parseSs3(self: *EventParser) ?Event {
        if (self.len < 3) return null;
        const final = self.buf[2];
        self.consume(3);
        const code: KeyCode = switch (final) {
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
            else => return null,
        };
        return .{ .key = .{ .code = code } };
    }

    fn parseCsi(self: *EventParser) std.mem.Allocator.Error!?Event {
        if (self.len < 3) return null;

        // X10 legacy mouse: ESC [ M cb cx cy (6 bytes).
        if (self.buf[2] == 'M') {
            if (self.len < 6) return null;
            const cb = self.buf[3];
            const cx = self.buf[4];
            const cy = self.buf[5];
            self.consume(6);
            return decodeX10Mouse(cb, cx, cy);
        }

        // Scan for CSI final byte (`0x40..0x7E`).
        var idx: usize = 2;
        while (idx < self.len) : (idx += 1) {
            const c = self.buf[idx];
            if (c >= 0x40 and c <= 0x7E) {
                var param_copy: [64]u8 = undefined;
                const param_len = idx - 2;
                @memcpy(param_copy[0..param_len], self.buf[2..idx]);
                const final = c;
                self.consume(idx + 1);
                return try self.decodeCsi(param_copy[0..param_len], final);
            }
            if (idx >= 66) {
                // Malformed runaway CSI sequence: discard prefix cleanly.
                self.consume(idx + 1);
                return null;
            }
        }
        return null;
    }

    fn decodeCsi(self: *EventParser, params: []const u8, final: u8) std.mem.Allocator.Error!?Event {
        // SGR mouse: `<Cb;Cx;CyM` or `<Cb;Cx;Cym`
        if (params.len > 0 and params[0] == '<' and (final == 'M' or final == 'm')) {
            return decodeSgrMouse(params[1..], final == 'm');
        }

        // Bracketed paste start: `200~`
        if (final == '~' and std.mem.eql(u8, params, "200")) {
            self.in_paste = true;
            self.paste_buf.clearRetainingCapacity();
            return try self.parsePasteChunk();
        }

        // Focus events.
        if (params.len == 0 and final == 'I') return .focus_gained;
        if (params.len == 0 and final == 'O') return .focus_lost;

        // Shift+Tab (`CSI Z`).
        if (params.len == 0 and final == 'Z') {
            return .{ .key = .{ .code = .back_tab, .modifiers = KeyModifiers.shift_only } };
        }

        // Kitty keyboard protocol (`CSI key[:shifted];mod[:kind]u`).
        if (final == 'u') {
            return decodeKittyKey(params);
        }

        // Special key sequences ending in A..Z or ~
        var p0: u32 = 0;
        var p1: u32 = 1;
        var p2: u32 = 0;
        var part_idx: usize = 0;
        var it = std.mem.splitScalar(u8, params, ';');
        while (it.next()) |seg| {
            const val = parseParamInt(seg) orelse 0;
            switch (part_idx) {
                0 => p0 = val,
                1 => p1 = if (val == 0) 1 else val,
                2 => p2 = val,
                else => {},
            }
            part_idx += 1;
        }

        // modifyOtherKeys (`CSI 27 ; mod ; keycode ~`)
        if (final == '~' and p0 == 27 and part_idx >= 3) {
            const mods = decodeCsiModifiers(p1);
            return .{ .key = .{ .code = .{ .char = @intCast(@min(p2, 0x10FFFF)) }, .modifiers = mods } };
        }

        const mods = if (part_idx >= 2) decodeCsiModifiers(p1) else KeyModifiers.none;

        const code: KeyCode = switch (final) {
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
            '~' => switch (p0) {
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
                else => return null,
            },
            else => return null,
        };

        return .{ .key = .{ .code = code, .modifiers = mods } };
    }

    fn parsePasteChunk(self: *EventParser) std.mem.Allocator.Error!?Event {
        const end_marker = "\x1b[201~";
        const data = self.buf[0..self.len];
        if (std.mem.indexOf(u8, data, end_marker)) |pos| {
            try self.paste_buf.appendSlice(self.allocator, data[0..pos]);
            self.consume(pos + end_marker.len);
            self.in_paste = false;
            return .{ .paste = self.paste_buf.items };
        }
        // Keep trailing bytes that might be a partial end marker.
        const keep = @min(data.len, end_marker.len - 1);
        const safe_len = data.len - keep;
        if (safe_len > 0) {
            try self.paste_buf.appendSlice(self.allocator, data[0..safe_len]);
            self.consume(safe_len);
        }
        return null;
    }
};

fn parseParamInt(seg: []const u8) ?u32 {
    if (seg.len == 0) return null;
    // Strip sub-parameters (`:` separated) if present for primary number.
    const clean = if (std.mem.indexOfScalar(u8, seg, ':')) |colon| seg[0..colon] else seg;
    if (clean.len == 0) return null;
    return std.fmt.parseInt(u32, clean, 10) catch null;
}

fn decodeCsiModifiers(code: u32) KeyModifiers {
    const bits = if (code > 0) code - 1 else 0;
    return .{
        .shift = (bits & 1) != 0,
        .alt = (bits & 2) != 0,
        .ctrl = (bits & 4) != 0,
        .super = (bits & 8) != 0,
        .hyper = (bits & 16) != 0,
        .meta = (bits & 32) != 0,
    };
}

fn decodeKittyKey(params: []const u8) ?Event {
    var it = std.mem.splitScalar(u8, params, ';');
    const key_part = it.next() orelse return null;
    const mod_part = it.next();

    const cp = parseParamInt(key_part) orelse return null;
    var mods: KeyModifiers = .none;
    var kind: KeyEventKind = .press;

    if (mod_part) |mp| {
        if (std.mem.indexOfScalar(u8, mp, ':')) |colon| {
            const mval = std.fmt.parseInt(u32, mp[0..colon], 10) catch 1;
            mods = decodeCsiModifiers(mval);
            const kval = std.fmt.parseInt(u32, mp[colon + 1 ..], 10) catch 1;
            kind = switch (kval) {
                2 => .repeat,
                3 => .release,
                else => .press,
            };
        } else {
            const mval = std.fmt.parseInt(u32, mp, 10) catch 1;
            mods = decodeCsiModifiers(mval);
        }
    }

    const code: KeyCode = switch (cp) {
        9 => if (mods.shift) .back_tab else .tab,
        13 => .enter,
        27 => .escape,
        127 => .backspace,
        else => if (cp <= 0x10FFFF) .{ .char = @intCast(cp) } else return null,
    };
    return .{ .key = .{ .code = code, .modifiers = mods, .kind = kind } };
}

fn decodeSgrMouse(body: []const u8, released: bool) ?Event {
    var it = std.mem.splitScalar(u8, body, ';');
    const cb = std.fmt.parseInt(u32, it.next() orelse return null, 10) catch return null;
    const cx = std.fmt.parseInt(u16, it.next() orelse return null, 10) catch return null;
    const cy = std.fmt.parseInt(u16, it.next() orelse return null, 10) catch return null;

    const mods: KeyModifiers = .{
        .shift = (cb & 4) != 0,
        .alt = (cb & 8) != 0,
        .ctrl = (cb & 16) != 0,
    };

    const x: u16 = cx -| 1;
    const y: u16 = cy -| 1;

    const low = cb & 0x43;
    const motion = (cb & 32) != 0;

    if ((cb & 64) != 0) {
        const wheel_kind: MouseEventKind = switch (cb & 3) {
            0 => .scroll_up,
            1 => .scroll_down,
            2 => .scroll_left,
            3 => .scroll_right,
            else => unreachable,
        };
        return .{ .mouse = .{
            .kind = wheel_kind,
            .button = .none,
            .x = x,
            .y = y,
            .modifiers = mods,
        } };
    }

    const button: MouseButton = switch (low & 3) {
        0 => .left,
        1 => .middle,
        2 => .right,
        3 => .none,
        else => unreachable,
    };

    const kind: MouseEventKind = if (released)
        .up
    else if (motion)
        (if (button == .none) .moved else .drag)
    else
        .down;

    return .{ .mouse = .{
        .kind = kind,
        .button = button,
        .x = x,
        .y = y,
        .modifiers = mods,
    } };
}

fn decodeX10Mouse(cb: u8, cx: u8, cy: u8) ?Event {
    if (cb < 32 or cx < 33 or cy < 33) return null;
    const raw = cb - 32;
    const x: u16 = cx - 33;
    const y: u16 = cy - 33;
    const mods: KeyModifiers = .{
        .shift = (raw & 4) != 0,
        .alt = (raw & 8) != 0,
        .ctrl = (raw & 16) != 0,
    };
    if ((raw & 64) != 0) {
        return .{ .mouse = .{
            .kind = if ((raw & 1) == 0) .scroll_up else .scroll_down,
            .x = x,
            .y = y,
            .modifiers = mods,
        } };
    }
    const btn: MouseButton = switch (raw & 3) {
        0 => .left,
        1 => .middle,
        2 => .right,
        else => .none,
    };
    const kind: MouseEventKind = if ((raw & 32) != 0)
        (if (btn == .none) .moved else .drag)
    else if (btn == .none)
        .up
    else
        .down;

    return .{ .mouse = .{
        .kind = kind,
        .button = btn,
        .x = x,
        .y = y,
        .modifiers = mods,
    } };
}

test "event parser decodes keys, modifiers, CSI arrows, SGR mouse, and bracketed paste" {
    var parser = EventParser.init(testing.allocator);
    defer parser.deinit();

    _ = parser.feed("a\x1b[1;5C\x1b[<0;15;8M\x1b[200~hi!\x1b[201~");

    const ev1 = (try parser.nextEvent(false)).?;
    try testing.expect(ev1.isChar('a'));

    const ev2 = (try parser.nextEvent(false)).?;
    try testing.expectEqual(KeyCode.right, ev2.key.code);
    try testing.expect(ev2.key.modifiers.ctrl);

    const ev3 = (try parser.nextEvent(false)).?;
    try testing.expectEqual(MouseEventKind.down, ev3.mouse.kind);
    try testing.expectEqual(MouseButton.left, ev3.mouse.button);
    try testing.expectEqual(@as(u16, 14), ev3.mouse.x);
    try testing.expectEqual(@as(u16, 7), ev3.mouse.y);

    const ev4 = (try parser.nextEvent(false)).?;
    try testing.expectEqualStrings("hi!", ev4.paste);
    try testing.expect((try parser.nextEvent(false)) == null);
}

test "event parser disambiguates lone escape and kitty release" {
    var parser = EventParser.init(testing.allocator);
    defer parser.deinit();

    _ = parser.feed("\x1b");
    try testing.expect((try parser.nextEvent(false)) == null);
    const esc = (try parser.nextEvent(true)).?;
    try testing.expect(esc.isEscape());

    _ = parser.feed("\x1b[97;5:3u");
    const rel = (try parser.nextEvent(false)).?;
    try testing.expectEqual(KeyEventKind.release, rel.key.kind);
    try testing.expectEqual(KeyCode{ .char = 'a' }, rel.key.code);
    try testing.expect(rel.key.modifiers.ctrl);
}
