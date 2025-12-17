//! Text widget for displaying text content

const std = @import("std");
const widget = @import("widget.zig");
const layout = @import("../layout/layout.zig");
const style_mod = @import("../style/style.zig");
const unicode = @import("../unicode/unicode.zig");
const screen_mod = @import("../core/screen.zig");

pub const RenderContext = widget.RenderContext;
pub const StatefulWidget = widget.StatefulWidget;
pub const SizeHint = widget.SizeHint;
pub const Style = style_mod.Style;
pub const Alignment = style_mod.Alignment;
pub const Screen = screen_mod.Screen;
pub const Rect = layout.Rect;

/// Text widget for displaying text
pub const Text = struct {
    /// Text content
    content: []const u8,

    /// Text style
    style: Style = .{},

    /// Horizontal alignment
    alignment: Alignment = .left,

    /// Whether to wrap text
    wrap: bool = false,

    /// Base widget state
    base: StatefulWidget = .{},

    /// Create a text widget
    pub fn init(content: []const u8) Text {
        return .{
            .content = content,
        };
    }

    /// Create with immediate value for tuples
    pub fn from(content: anytype) Text {
        return init(content);
    }

    /// Set style
    pub fn withStyle(self: Text, s: Style) Text {
        var result = self;
        result.style = s;
        return result;
    }

    /// Set alignment
    pub fn withAlignment(self: Text, a: Alignment) Text {
        var result = self;
        result.alignment = a;
        return result;
    }

    /// Enable word wrapping
    pub fn wrapped(self: Text) Text {
        var result = self;
        result.wrap = true;
        return result;
    }

    /// Set as bold
    pub fn bold(self: Text) Text {
        var result = self;
        result.style = result.style.bold();
        return result;
    }

    /// Set as italic
    pub fn italic(self: Text) Text {
        var result = self;
        result.style = result.style.italic();
        return result;
    }

    /// Set foreground color
    pub fn fg(self: Text, color: style_mod.Color) Text {
        var result = self;
        result.style = result.style.fg(color);
        return result;
    }

    /// Set background color
    pub fn bg(self: Text, color: style_mod.Color) Text {
        var result = self;
        result.style = result.style.bg(color);
        return result;
    }

    /// Render the text widget
    pub fn render(self: *Text, ctx: *RenderContext) void {
        var sub = ctx.getSubScreen();
        sub.setStyle(self.style);

        if (self.wrap) {
            self.renderWrapped(&sub);
        } else {
            self.renderSingleLine(&sub);
        }
    }

    fn renderSingleLine(self: *Text, sub: *screen_mod.SubScreen) void {
        const text_width = unicode.stringWidth(self.content);
        const x_offset = self.alignment.calculate(text_width, sub.width);

        sub.moveCursor(@intCast(x_offset), 0);
        sub.putString(self.content);
    }

    fn renderWrapped(self: *Text, sub: *screen_mod.SubScreen) void {
        var line: u16 = 0;
        var iter = std.mem.splitScalar(u8, self.content, ' ');
        var line_buf: [256]u8 = undefined;
        var line_len: usize = 0;

        while (iter.next()) |word| {
            const word_width = unicode.stringWidth(word);

            if (line_len > 0 and unicode.stringWidth(line_buf[0..line_len]) + 1 + word_width > sub.width) {
                // Flush current line
                sub.moveCursor(0, line);
                sub.putString(line_buf[0..line_len]);
                line += 1;
                line_len = 0;

                if (line >= sub.height) break;
            }

            // Add word to line
            if (line_len > 0) {
                line_buf[line_len] = ' ';
                line_len += 1;
            }
            @memcpy(line_buf[line_len..][0..word.len], word);
            line_len += word.len;
        }

        // Flush remaining line
        if (line_len > 0 and line < sub.height) {
            sub.moveCursor(0, line);
            sub.putString(line_buf[0..line_len]);
        }
    }

    /// Get size hint
    pub fn sizeHint(self: *Text) SizeHint {
        const width = unicode.stringWidth(self.content);
        return .{
            .min_width = @intCast(@min(width, std.math.maxInt(u16))),
            .preferred_width = @intCast(@min(width, std.math.maxInt(u16))),
            .min_height = 1,
            .preferred_height = 1,
        };
    }

    /// Layout
    pub fn layout_text(self: *Text, bounds: Rect) void {
        self.base.bounds = bounds;
    }
};

/// Rich text with multiple styled spans
pub const RichText = struct {
    spans: []const Span,
    base: StatefulWidget = .{},

    pub const Span = struct {
        text: []const u8,
        style: Style = .{},
    };

    pub fn init(spans: []const Span) RichText {
        return .{ .spans = spans };
    }

    pub fn render(self: *RichText, ctx: *RenderContext) void {
        var sub = ctx.getSubScreen();

        for (self.spans) |span| {
            sub.setStyle(span.style);
            sub.putString(span.text);
        }
    }

    pub fn sizeHint(self: *RichText) SizeHint {
        var total_width: usize = 0;
        for (self.spans) |span| {
            total_width += unicode.stringWidth(span.text);
        }
        return .{
            .min_width = @intCast(@min(total_width, std.math.maxInt(u16))),
            .preferred_width = @intCast(@min(total_width, std.math.maxInt(u16))),
            .min_height = 1,
            .preferred_height = 1,
        };
    }
};

test "text creation" {
    const text = Text.init("Hello, World!");
    try std.testing.expectEqualStrings("Hello, World!", text.content);
}

test "text styling" {
    const text = Text.init("Test").bold().italic();
    try std.testing.expect(text.style.attrs.bold);
    try std.testing.expect(text.style.attrs.italic);
}
