//! ANSI / VT escape sequence emitter for terminal rendering and control.
//!
//! All SGR styling and color transitions delegate to `style.Style.writeAnsiDiff`
//! and `tint`, writing directly into a caller-provided `*std.Io.Writer` with
//! zero intermediate allocations.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const caps_mod = @import("capabilities.zig");
const testing = std.testing;

pub const Buffer = core_root.Buffer;
pub const BufferDiff = core_root.BufferDiff;
pub const Rect = core_root.Rect;
pub const Position = core_root.Position;
pub const Style = style_root.Style;
pub const Capability = style_root.Capability;
pub const EnterOptions = core_root.EnterOptions;
pub const CursorShape = core_root.CursorShape;
pub const TerminalCapabilities = caps_mod.TerminalCapabilities;

/// Tracks which ANSI terminal protocol toggles are currently enabled so cleanup restores only active modes.
pub const SessionState = struct {
    alt_active: bool = false,
    mouse_active: bool = false,
    paste_active: bool = false,
    focus_active: bool = false,
    cursor_hidden: bool = false,
    cursor_shape_modified: bool = false,
};

/// Emits ANSI sequences entering interactive terminal state according to `opts` and `caps`,
/// recording active flags inside `session` for symmetric restoration.
pub fn writeEnterSession(
    w: *std.Io.Writer,
    session: *SessionState,
    opts: EnterOptions,
    caps: TerminalCapabilities,
) std.Io.Writer.Error!void {
    if (opts.alternate_screen and caps.alternate_screen and !session.alt_active) {
        try writeEnterAlternateScreen(w);
        session.alt_active = true;
    }
    if (opts.mouse and caps.mouse and !session.mouse_active) {
        try writeEnableMouse(w);
        session.mouse_active = true;
    }
    if (opts.bracketed_paste and !session.paste_active) {
        try writeEnableBracketedPaste(w);
        session.paste_active = true;
    }
    if (opts.focus_events and !session.focus_active) {
        try writeEnableFocusEvents(w);
        session.focus_active = true;
    }
    if (opts.hide_cursor and !session.cursor_hidden) {
        try writeHideCursor(w);
        session.cursor_hidden = true;
    }
    if (opts.title) |t| {
        try writeTitle(w, t);
    }
}

/// Emits ANSI sequences reversing active flags recorded in `session`.
pub fn writeLeaveSession(w: *std.Io.Writer, session: *SessionState) std.Io.Writer.Error!void {
    if (session.cursor_shape_modified) {
        try writeCursorShape(w, .default_shape);
        session.cursor_shape_modified = false;
    }
    if (session.cursor_hidden) {
        try writeShowCursor(w);
        session.cursor_hidden = false;
    }
    if (session.focus_active) {
        try writeDisableFocusEvents(w);
        session.focus_active = false;
    }
    if (session.paste_active) {
        try writeDisableBracketedPaste(w);
        session.paste_active = false;
    }
    if (session.mouse_active) {
        try writeDisableMouse(w);
        session.mouse_active = false;
    }
    if (session.alt_active) {
        try writeLeaveAlternateScreen(w);
        session.alt_active = false;
    }
}

/// Screen clearing region mode.
pub const ClearType = enum {
    all,
    after_cursor,
    before_cursor,
    current_line,
    until_new_line,
};

pub fn writeHideCursor(w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll("\x1b[?25l");
}

pub fn writeShowCursor(w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll("\x1b[?25h");
}

/// Sets the terminal hardware cursor shape via DECSCUSR (`ESC [ <n> SP q`).
pub fn writeCursorShape(w: *std.Io.Writer, shape: CursorShape) std.Io.Writer.Error!void {
    try w.print("\x1b[{d} q", .{@backingInt(shape)});
}

pub fn writeMoveTo(w: *std.Io.Writer, x: u16, y: u16) std.Io.Writer.Error!void {
    try w.print("\x1b[{d};{d}H", .{ @as(u32, y) + 1, @as(u32, x) + 1 });
}

pub fn writeSaveCursor(w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll("\x1b7");
}

pub fn writeRestoreCursor(w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll("\x1b8");
}

pub fn writeEnterAlternateScreen(w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll("\x1b[?1049h");
}

pub fn writeLeaveAlternateScreen(w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll("\x1b[?1049l");
}

pub fn writeEnableMouse(w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll("\x1b[?1000h\x1b[?1002h\x1b[?1003h\x1b[?1006h");
}

pub fn writeDisableMouse(w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll("\x1b[?1006l\x1b[?1003l\x1b[?1002l\x1b[?1000l");
}

pub fn writeEnableBracketedPaste(w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll("\x1b[?2004h");
}

pub fn writeDisableBracketedPaste(w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll("\x1b[?2004l");
}

pub fn writeEnableFocusEvents(w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll("\x1b[?1004h");
}

pub fn writeDisableFocusEvents(w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll("\x1b[?1004l");
}

pub fn writeBeginSync(w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll("\x1b[?2026h");
}

pub fn writeEndSync(w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll("\x1b[?2026l");
}

pub fn writeClear(w: *std.Io.Writer, clear_type: ClearType) std.Io.Writer.Error!void {
    const seq = switch (clear_type) {
        .all => "\x1b[2J",
        .after_cursor => "\x1b[0J",
        .before_cursor => "\x1b[1J",
        .current_line => "\x1b[2K",
        .until_new_line => "\x1b[0K",
    };
    try w.writeAll(seq);
}

pub fn writeTitle(w: *std.Io.Writer, title: []const u8) std.Io.Writer.Error!void {
    try w.writeAll("\x1b]0;");
    for (title) |ch| {
        // Strip control characters from OSC title strings.
        if (ch >= 0x20 and ch != 0x7F) try w.writeByte(ch);
    }
    try w.writeAll("\x07");
}

pub fn writeHyperlinkStart(w: *std.Io.Writer, url: []const u8) std.Io.Writer.Error!void {
    try w.writeAll("\x1b]8;;");
    try w.writeAll(url);
    try w.writeAll("\x1b\\");
}

pub fn writeHyperlinkEnd(w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll("\x1b]8;;\x1b\\");
}

pub fn writeScrollRegionUp(w: *std.Io.Writer, first_row: u16, last_row: u16, lines: u16) std.Io.Writer.Error!void {
    if (lines == 0) return;
    try w.print("\x1b[{d};{d}r\x1b[{d}S\x1b[r", .{
        @as(u32, first_row) + 1,
        @as(u32, last_row) + 1,
        lines,
    });
}

pub fn writeScrollRegionDown(w: *std.Io.Writer, first_row: u16, last_row: u16, lines: u16) std.Io.Writer.Error!void {
    if (lines == 0) return;
    try w.print("\x1b[{d};{d}r\x1b[{d}T\x1b[r", .{
        @as(u32, first_row) + 1,
        @as(u32, last_row) + 1,
        lines,
    });
}

/// Emits minimal cursor moves, SGR diffs, OSC 8 hyperlinks, and cell glyphs for `diff` into `w`.
/// Tracks cursor position across sequential cells to elide redundant CUP moves.
pub fn writeDiff(
    w: *std.Io.Writer,
    diff_iter: *BufferDiff,
    caps: TerminalCapabilities,
    synchronized: bool,
) std.Io.Writer.Error!void {
    var active_style: Style = Style.reset;
    var active_link: ?[]const u8 = null;
    var cursor_pos: ?Position = null;
    var cursor_width: u16 = 0;
    var wrote_any = false;

    while (diff_iter.nextEntry()) |entry| {
        if (!wrote_any) {
            wrote_any = true;
            if (synchronized and caps.synchronized_output) try writeBeginSync(w);
        }

        const sequential = if (cursor_pos) |p|
            p.y == entry.y and (p.x +| cursor_width) == entry.x
        else
            false;

        if (!sequential) {
            if (active_link != null) {
                try writeHyperlinkEnd(w);
                active_link = null;
            }
            try writeMoveTo(w, entry.x, entry.y);
        }

        const cell_style = entry.cell.style();
        try Style.writeAnsiDiff(active_style, cell_style, caps.color, w);
        active_style = cell_style;

        if (caps.hyperlinks) {
            const next_link = entry.cell.hyperlink;
            const changed = !optSliceEql(active_link, next_link);
            if (changed) {
                if (active_link != null) try writeHyperlinkEnd(w);
                if (next_link) |url| try writeHyperlinkStart(w, url);
                active_link = next_link;
            }
        }

        const sym = entry.cell.symbol();
        try w.writeAll(sym);

        const cw = entry.cell.cellWidth();
        const has_vs16 = cw > 1 and std.mem.indexOf(u8, sym, "\xef\xb8\x8f") != null;
        if (has_vs16) {
            // VS16 emoji terminal cursor advance varies across emulators; force next move.
            cursor_pos = null;
            cursor_width = 0;
        } else {
            cursor_pos = .{ .x = entry.x, .y = entry.y };
            cursor_width = cw;
        }
    }

    if (wrote_any) {
        if (active_link != null) try writeHyperlinkEnd(w);
        try w.writeAll("\x1b[0m");
        if (synchronized and caps.synchronized_output) try writeEndSync(w);
    }
}

fn optSliceEql(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;
    return std.mem.eql(u8, a.?, b.?);
}

test "ansi writeDiff elides sequential cursor moves and emits osc8 links cleanly" {
    const alloc = testing.allocator;
    var prev = try Buffer.init(alloc, Rect.init(0, 0, 5, 1));
    defer prev.deinit();
    var next = try Buffer.init(alloc, Rect.init(0, 0, 5, 1));
    defer next.deinit();

    _ = next.setString(1, 0, "AB", .{ .foreground = .red });
    var diff = next.diff(&prev);

    var out: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&out);
    try writeDiff(&writer, &diff, .{ .color = .trueColor, .synchronized_output = false, .hyperlinks = true }, false);

    try testing.expectEqualStrings("\x1b[1;2H\x1b[31mAB\x1b[0m", writer.buffered());

    var link_prev = try Buffer.init(alloc, Rect.init(0, 0, 4, 1));
    defer link_prev.deinit();
    var link_next = try Buffer.init(alloc, Rect.init(0, 0, 4, 1));
    defer link_next.deinit();
    _ = link_next.setString(0, 0, "Hi", .{ .hyperlink = "https://ziglang.org" });

    var l_diff = link_next.diff(&link_prev);
    var l_out: [256]u8 = undefined;
    var l_writer = std.Io.Writer.fixed(&l_out);
    try writeDiff(&l_writer, &l_diff, .{ .hyperlinks = true, .synchronized_output = false }, false);
    try testing.expect(std.mem.indexOf(u8, l_writer.buffered(), "\x1b]8;;https://ziglang.org\x1b\\") != null);

    var cs_buf: [64]u8 = undefined;
    var cs_writer = std.Io.Writer.fixed(&cs_buf);
    var sess = SessionState{ .cursor_shape_modified = true };
    try writeCursorShape(&cs_writer, .steady_bar);
    try writeLeaveSession(&cs_writer, &sess);
    try testing.expectEqualStrings("\x1b[6 q\x1b[0 q", cs_writer.buffered());
}
