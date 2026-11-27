//! Multi-line styled `Text` and zero-allocation line splitting utilities.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const grapheme = @import("grapheme.zig");
const span_mod = @import("span.zig");
const line_mod = @import("line.zig");
const testing = std.testing;

pub const Span = span_mod.Span;
pub const Line = line_mod.Line;
pub const Style = style_root.Style;
pub const Alignment = core_root.Alignment;
pub const Buffer = core_root.Buffer;
pub const Rect = core_root.Rect;

/// Multi-line rich text borrowing a slice of `Line`s.
pub const Text = struct {
    /// Borrowed slice of lines.
    lines: []const Line = &.{},
    /// Base style applied across all lines.
    style: Style = .{},
    /// Default horizontal alignment for lines that do not specify their own.
    alignment: ?Alignment = null,

    /// Creates a `Text` from a borrowed slice of `Line`s.
    pub fn fromLines(lines: []const Line) Text {
        return .{ .lines = lines };
    }

    /// Number of lines in this `Text`.
    pub fn height(self: Text) usize {
        return self.lines.len;
    }

    /// Maximum cell width across all lines.
    pub fn width(self: Text) u16 {
        var max_w: u16 = 0;
        for (self.lines) |ln| {
            max_w = @max(max_w, ln.width());
        }
        return max_w;
    }

    /// Renders visible lines into `buf` inside `area`.
    pub fn render(self: Text, buf: *Buffer, area: Rect, fallback_align: Alignment, base_style: Style) void {
        if (area.isEmpty()) return;
        const text_style = base_style.patch(self.style);
        if (!text_style.background.isInherit() or !text_style.foreground.isInherit()) {
            buf.setStyle(area, text_style);
        }
        const eff_align = self.alignment orelse fallback_align;

        var row: u16 = 0;
        for (self.lines) |ln| {
            if (row >= area.height) break;
            const row_area = Rect.init(area.x, area.y + row, area.width, 1);
            ln.render(buf, row_area, eff_align, text_style);
            row += 1;
        }
    }
};

/// Splits a raw multi-line UTF-8 string on `\n` (stripping trailing `\r`) with zero allocations.
pub fn splitLinesIter(raw: []const u8) RawLineIterator {
    return .{ .bytes = raw };
}

/// Zero-allocation iterator yielding lines from raw UTF-8 text.
pub const RawLineIterator = struct {
    bytes: []const u8,
    pos: usize = 0,
    done: bool = false,

    pub fn next(self: *RawLineIterator) ?[]const u8 {
        if (self.done) return null;
        if (self.pos > self.bytes.len) {
            self.done = true;
            return null;
        }
        if (self.pos == self.bytes.len) {
            self.done = true;
            return if (self.bytes.len == 0) "" else null;
        }

        const start = self.pos;
        if (std.mem.indexOfScalarPos(u8, self.bytes, start, '\n')) |nl| {
            self.pos = nl + 1;
            const slice = self.bytes[start..nl];
            return if (slice.len > 0 and slice[slice.len - 1] == '\r')
                slice[0 .. slice.len - 1]
            else
                slice;
        }
        self.pos = self.bytes.len;
        self.done = true;
        return self.bytes[start..];
    }
};

/// Helper returning the display width of plain UTF-8 text.
pub fn textWidth(s: []const u8) u16 {
    var max_w: u16 = 0;
    var it = splitLinesIter(s);
    while (it.next()) |ln| {
        max_w = @max(max_w, grapheme.displayWidth(ln));
    }
    return max_w;
}

test "raw line iterator handles CRLF, LF, and empty strings" {
    var it = splitLinesIter("one\r\ntwo\nthree");
    try testing.expectEqualStrings("one", it.next().?);
    try testing.expectEqualStrings("two", it.next().?);
    try testing.expectEqualStrings("three", it.next().?);
    try testing.expect(it.next() == null);

    var empty = splitLinesIter("");
    try testing.expectEqualStrings("", empty.next().?);
    try testing.expect(empty.next() == null);
}

test "text renders lines with alignment" {
    const alloc = testing.allocator;
    var buf = try Buffer.init(alloc, Rect.init(0, 0, 8, 2));
    defer buf.deinit();

    var s1 = [_]Span{Span.raw("top")};
    var s2 = [_]Span{Span.raw("bot")};
    const lines = [_]Line{
        Line.fromSpans(&s1),
        Line.fromSpans(&s2),
    };
    const txt = Text.fromLines(&lines);
    txt.render(&buf, Rect.init(0, 0, 8, 2), .center, .{});

    const out = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(out);
    try testing.expectEqualStrings("  top   \n  bot   ", out);
}
