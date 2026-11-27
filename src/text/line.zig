//! Single-line styled text composed of one or more `Span`s.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const span_mod = @import("span.zig");
const testing = std.testing;

pub const Span = span_mod.Span;
pub const Style = style_root.Style;
pub const Alignment = core_root.Alignment;
pub const Buffer = core_root.Buffer;
pub const Rect = core_root.Rect;

/// A single horizontal line of styled `Span`s with optional alignment and base style.
///
/// `spans` is borrowed by default; caller controls its lifetime.
pub const Line = struct {
    /// Borrowed slice of spans comprising this line.
    spans: []const Span = &.{},
    /// Base style inherited by every span on this line.
    style: Style = .{},
    /// Optional per-line alignment overriding container alignment.
    alignment: ?Alignment = null,

    /// Creates a `Line` from a borrowed slice of `Span`s.
    pub fn fromSpans(spans: []const Span) Line {
        return .{ .spans = spans };
    }

    /// Creates a `Line` pointing into a caller-supplied 1-element `Span` slot (zero allocation).
    pub fn fromSingle(slot: *[1]Span, content: []const u8, s: Style) Line {
        slot[0] = Span.styled(content, s);
        return .{ .spans = slot[0..], .style = .{} };
    }

    /// Returns a copy with `s` patched onto the line style.
    pub fn patchStyle(self: Line, s: Style) Line {
        var copy = self;
        copy.style = self.style.patch(s);
        return copy;
    }

    /// Returns a copy with explicit `align_mode`.
    pub fn aligned(self: Line, align_mode: Alignment) Line {
        var copy = self;
        copy.alignment = align_mode;
        return copy;
    }

    /// Total display column width across all spans in this line.
    pub fn width(self: Line) u16 {
        var total: u32 = 0;
        for (self.spans) |sp| {
            total += sp.width();
            if (total >= std.math.maxInt(u16)) return std.math.maxInt(u16);
        }
        return @intCast(total);
    }

    /// Renders this line into `buf` on the first row of `area`, honoring alignment and clipping.
    pub fn render(self: Line, buf: *Buffer, area: Rect, fallback_align: Alignment, base_style: Style) void {
        if (area.isEmpty()) return;
        const row_rect = Rect.init(area.x, area.y, area.width, 1);
        const line_style = base_style.patch(self.style);
        if (!line_style.background.isInherit() or !line_style.foreground.isInherit()) {
            buf.setStyle(row_rect, line_style);
        }

        const total_w = self.width();
        const eff_align = self.alignment orelse fallback_align;
        var cursor_x: u16 = switch (eff_align) {
            .left => area.x,
            .center => if (total_w < area.width) area.x + (area.width - total_w) / 2 else area.x,
            .right => if (total_w < area.width) area.x + (area.width - total_w) else area.x,
        };

        for (self.spans) |sp| {
            if (cursor_x >= area.right()) break;
            const remaining = area.right() - cursor_x;
            const span_area = Rect.init(cursor_x, area.y, remaining, 1);
            const end_pos = sp.render(buf, span_area, line_style);
            cursor_x = end_pos.x;
        }
    }
};

test "line computes width and honors alignment" {
    const alloc = testing.allocator;
    var buf = try Buffer.init(alloc, Rect.init(0, 0, 10, 1));
    defer buf.deinit();

    const spans = [_]Span{
        Span.styled("Hi", .{ .bold = true }),
        Span.raw("!"),
    };
    const ln = Line.fromSpans(&spans).aligned(.right);
    try testing.expectEqual(@as(u16, 3), ln.width());
    ln.render(&buf, Rect.init(0, 0, 10, 1), .left, .{});

    const out = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(out);
    try testing.expectEqualStrings("       Hi!", out);
}
