//! Styled text span primitive.
//!
//! A `Span` borrows a UTF-8 byte slice without owning heap memory and pairs it
//! with a `Style`. Lifetime of `content` is managed by the caller.

const std = @import("std");
const style_root = @import("../style/root.zig");
const core_root = @import("../core/root.zig");
const grapheme = @import("grapheme.zig");
const testing = std.testing;

pub const Style = style_root.Style;
pub const Buffer = core_root.Buffer;
pub const Rect = core_root.Rect;
pub const Position = core_root.Position;

/// A borrowed string slice paired with a `Style`.
pub const Span = struct {
    /// Borrowed UTF-8 text content.
    content: []const u8 = "",
    /// Visual style applied to this span.
    style: Style = .{},

    /// Creates an unstyled `Span` borrowing `content`.
    pub fn raw(content: []const u8) Span {
        return .{ .content = content, .style = .{} };
    }

    /// Creates a styled `Span` borrowing `content`.
    pub fn styled(content: []const u8, s: Style) Span {
        return .{ .content = content, .style = s };
    }

    /// Creates an underlined hyperlink `Span` targeting `url` via OSC 8.
    pub fn link(content: []const u8, url: []const u8) Span {
        return .{
            .content = content,
            .style = .{ .underline = true, .hyperlink = url },
        };
    }

    /// Attaches an OSC 8 hyperlink `url` to an existing `Span`.
    pub fn withLink(self: Span, url: []const u8) Span {
        var copy = self;
        copy.style.hyperlink = url;
        copy.style.underline = true;
        return copy;
    }

    /// Returns a copy with `s` patched over the current style.
    pub fn patchStyle(self: Span, s: Style) Span {
        var copy = self;
        copy.style = self.style.patch(s);
        return copy;
    }

    /// Returns the total terminal cell width of `content`.
    pub fn width(self: Span) u16 {
        return grapheme.displayWidth(self.content);
    }

    /// Renders this span into `buf` inside `area`, returning the end cursor position.
    pub fn render(self: Span, buf: *Buffer, area: Rect, base_style: Style) Position {
        if (area.isEmpty() or self.content.len == 0) return area.position();
        const effective = base_style.patch(self.style);
        return buf.setStringClipped(area.x, area.y, self.content, area.width, effective, area);
    }
};

test "span width and rendering clip properly" {
    const alloc = testing.allocator;
    var buf = try Buffer.init(alloc, Rect.init(0, 0, 8, 1));
    defer buf.deinit();

    const sp = Span.styled("HelloWorld", .{ .foreground = .cyan });
    try testing.expectEqual(@as(u16, 10), sp.width());
    _ = sp.render(&buf, Rect.init(0, 0, 5, 1), .{});

    const plain = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(plain);
    try testing.expectEqualStrings("Hello   ", plain);
}
