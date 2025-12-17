//! Style definitions for TUI.zig
//!
//! Styles combine colors and text attributes for rendering cells.

const std = @import("std");
const color = @import("color.zig");
pub const Color = color.Color;

/// Text style attributes
pub const Style = struct {
    /// Foreground color
    fg: Color = .default,

    /// Background color
    bg: Color = .default,

    /// Text attributes
    attrs: Attributes = .{},

    /// Default style (no colors, no attributes)
    pub const default = Style{};

    /// Text attributes/modifiers
    pub const Attributes = packed struct {
        bold: bool = false,
        dim: bool = false,
        italic: bool = false,
        underline: bool = false,
        blink: bool = false,
        reverse: bool = false,
        hidden: bool = false,
        strikethrough: bool = false,
        double_underline: bool = false,
        curly_underline: bool = false,
        dotted_underline: bool = false,
        dashed_underline: bool = false,
        overline: bool = false,
        _padding: u3 = 0,
    };

    /// Set foreground color
    pub fn setFg(self: Style, c: Color) Style {
        var s = self;
        s.fg = c;
        return s;
    }

    /// Set background color
    pub fn setBg(self: Style, c: Color) Style {
        var s = self;
        s.bg = c;
        return s;
    }

    /// Enable bold
    pub fn bold(self: Style) Style {
        var s = self;
        s.attrs.bold = true;
        return s;
    }

    /// Enable dim
    pub fn dim(self: Style) Style {
        var s = self;
        s.attrs.dim = true;
        return s;
    }

    /// Enable italic
    pub fn italic(self: Style) Style {
        var s = self;
        s.attrs.italic = true;
        return s;
    }

    /// Enable underline
    pub fn underline(self: Style) Style {
        var s = self;
        s.attrs.underline = true;
        return s;
    }

    /// Enable blink
    pub fn blink(self: Style) Style {
        var s = self;
        s.attrs.blink = true;
        return s;
    }

    /// Enable reverse (swap fg/bg)
    pub fn reverse(self: Style) Style {
        var s = self;
        s.attrs.reverse = true;
        return s;
    }

    /// Enable strikethrough
    pub fn strikethrough(self: Style) Style {
        var s = self;
        s.attrs.strikethrough = true;
        return s;
    }

    /// Enable hidden text
    pub fn hidden(self: Style) Style {
        var s = self;
        s.attrs.hidden = true;
        return s;
    }

    /// Enable double underline
    pub fn doubleUnderline(self: Style) Style {
        var s = self;
        s.attrs.double_underline = true;
        s.attrs.underline = false;
        return s;
    }

    /// Enable curly underline
    pub fn curlyUnderline(self: Style) Style {
        var s = self;
        s.attrs.curly_underline = true;
        s.attrs.underline = false;
        return s;
    }

    /// Enable overline
    pub fn overline(self: Style) Style {
        var s = self;
        s.attrs.overline = true;
        return s;
    }

    /// Check if two styles are equal
    pub fn eql(self: Style, other: Style) bool {
        return std.meta.eql(self.fg, other.fg) and
            std.meta.eql(self.bg, other.bg) and
            std.meta.eql(self.attrs, other.attrs);
    }

    /// Merge two styles (other overrides self for non-default values)
    pub fn merge(self: Style, other: Style) Style {
        var result = self;

        if (!other.fg.isDefault()) {
            result.fg = other.fg;
        }
        if (!other.bg.isDefault()) {
            result.bg = other.bg;
        }

        // Merge attributes (other takes precedence for any set attribute)
        const self_attrs = @as(u16, @bitCast(self.attrs));
        const other_attrs = @as(u16, @bitCast(other.attrs));
        result.attrs = @bitCast(self_attrs | other_attrs);

        return result;
    }

    /// Write the style as ANSI escape sequences
    pub fn toAnsi(self: Style, writer: anytype) !void {
        // Reset first
        try writer.writeAll("\x1b[0m");

        // Foreground
        try self.fg.toFgAnsi(writer);

        // Background
        try self.bg.toBgAnsi(writer);

        // Attributes
        if (self.attrs.bold) try writer.writeAll("\x1b[1m");
        if (self.attrs.dim) try writer.writeAll("\x1b[2m");
        if (self.attrs.italic) try writer.writeAll("\x1b[3m");
        if (self.attrs.underline) try writer.writeAll("\x1b[4m");
        if (self.attrs.blink) try writer.writeAll("\x1b[5m");
        if (self.attrs.reverse) try writer.writeAll("\x1b[7m");
        if (self.attrs.hidden) try writer.writeAll("\x1b[8m");
        if (self.attrs.strikethrough) try writer.writeAll("\x1b[9m");
        if (self.attrs.double_underline) try writer.writeAll("\x1b[21m");
        if (self.attrs.curly_underline) try writer.writeAll("\x1b[4:3m");
        if (self.attrs.dotted_underline) try writer.writeAll("\x1b[4:4m");
        if (self.attrs.dashed_underline) try writer.writeAll("\x1b[4:5m");
        if (self.attrs.overline) try writer.writeAll("\x1b[53m");
    }

    /// Write only the differences from another style
    pub fn toDiffAnsi(self: Style, prev: Style, writer: anytype) !void {
        // Check if we need a full reset
        const need_reset = (prev.attrs.bold and !self.attrs.bold) or
            (prev.attrs.dim and !self.attrs.dim) or
            (prev.attrs.italic and !self.attrs.italic) or
            (prev.attrs.underline and !self.attrs.underline) or
            (prev.attrs.blink and !self.attrs.blink) or
            (prev.attrs.reverse and !self.attrs.reverse) or
            (prev.attrs.hidden and !self.attrs.hidden) or
            (prev.attrs.strikethrough and !self.attrs.strikethrough);

        if (need_reset) {
            try self.toAnsi(writer);
            return;
        }

        // Apply only differences
        if (!std.meta.eql(self.fg, prev.fg)) {
            try self.fg.toFgAnsi(writer);
        }

        if (!std.meta.eql(self.bg, prev.bg)) {
            try self.bg.toBgAnsi(writer);
        }

        if (self.attrs.bold and !prev.attrs.bold) try writer.writeAll("\x1b[1m");
        if (self.attrs.dim and !prev.attrs.dim) try writer.writeAll("\x1b[2m");
        if (self.attrs.italic and !prev.attrs.italic) try writer.writeAll("\x1b[3m");
        if (self.attrs.underline and !prev.attrs.underline) try writer.writeAll("\x1b[4m");
        if (self.attrs.blink and !prev.attrs.blink) try writer.writeAll("\x1b[5m");
        if (self.attrs.reverse and !prev.attrs.reverse) try writer.writeAll("\x1b[7m");
        if (self.attrs.hidden and !prev.attrs.hidden) try writer.writeAll("\x1b[8m");
        if (self.attrs.strikethrough and !prev.attrs.strikethrough) try writer.writeAll("\x1b[9m");
    }
};

/// Border styles for boxes and containers
pub const BorderStyle = enum {
    none,
    single,
    double,
    rounded,
    thick,
    dashed,
    dotted,
    ascii,

    /// Get the border characters for a style
    pub fn chars(self: BorderStyle) BorderChars {
        return switch (self) {
            .none => .{
                .top_left = ' ',
                .top_right = ' ',
                .bottom_left = ' ',
                .bottom_right = ' ',
                .horizontal = ' ',
                .vertical = ' ',
            },
            .single => .{
                .top_left = '┌',
                .top_right = '┐',
                .bottom_left = '└',
                .bottom_right = '┘',
                .horizontal = '─',
                .vertical = '│',
            },
            .double => .{
                .top_left = '╔',
                .top_right = '╗',
                .bottom_left = '╚',
                .bottom_right = '╝',
                .horizontal = '═',
                .vertical = '║',
            },
            .rounded => .{
                .top_left = '╭',
                .top_right = '╮',
                .bottom_left = '╰',
                .bottom_right = '╯',
                .horizontal = '─',
                .vertical = '│',
            },
            .thick => .{
                .top_left = '┏',
                .top_right = '┓',
                .bottom_left = '┗',
                .bottom_right = '┛',
                .horizontal = '━',
                .vertical = '┃',
            },
            .dashed => .{
                .top_left = '┌',
                .top_right = '┐',
                .bottom_left = '└',
                .bottom_right = '┘',
                .horizontal = '╌',
                .vertical = '╎',
            },
            .dotted => .{
                .top_left = '┌',
                .top_right = '┐',
                .bottom_left = '└',
                .bottom_right = '┘',
                .horizontal = '┄',
                .vertical = '┆',
            },
            .ascii => .{
                .top_left = '+',
                .top_right = '+',
                .bottom_left = '+',
                .bottom_right = '+',
                .horizontal = '-',
                .vertical = '|',
            },
        };
    }
};

/// Characters used for drawing borders
pub const BorderChars = struct {
    top_left: u21,
    top_right: u21,
    bottom_left: u21,
    bottom_right: u21,
    horizontal: u21,
    vertical: u21,
};

/// Styled border configuration
pub const Border = struct {
    style: BorderStyle = .single,
    color: Color = .default,
    title: ?[]const u8 = null,
    title_alignment: Alignment = .left,

    pub const none = Border{ .style = .none };
    pub const single = Border{ .style = .single };
    pub const double = Border{ .style = .double };
    pub const rounded = Border{ .style = .rounded };
    pub const thick = Border{ .style = .thick };
};

/// Text alignment
pub const Alignment = enum {
    left,
    center,
    right,

    /// Calculate the starting position for aligned text
    pub fn calculate(self: Alignment, text_width: usize, available_width: usize) usize {
        return switch (self) {
            .left => 0,
            .center => if (available_width > text_width) (available_width - text_width) / 2 else 0,
            .right => if (available_width > text_width) available_width - text_width else 0,
        };
    }
};

/// Vertical alignment
pub const VerticalAlignment = enum {
    top,
    middle,
    bottom,

    pub fn calculate(self: VerticalAlignment, content_height: usize, available_height: usize) usize {
        return switch (self) {
            .top => 0,
            .middle => if (available_height > content_height) (available_height - content_height) / 2 else 0,
            .bottom => if (available_height > content_height) available_height - content_height else 0,
        };
    }
};

test "style chaining" {
    const s = Style.default
        .setFg(Color.hex(0xFF0000))
        .setBg(Color{ .basic = .blue })
        .bold()
        .italic();

    try std.testing.expect(s.attrs.bold);
    try std.testing.expect(s.attrs.italic);
    try std.testing.expect(!s.attrs.underline);
}

test "style equality" {
    const s1 = Style.default.bold().italic();
    const s2 = Style.default.bold().italic();
    const s3 = Style.default.bold();

    try std.testing.expect(s1.eql(s2));
    try std.testing.expect(!s1.eql(s3));
}

test "alignment calculation" {
    try std.testing.expectEqual(@as(usize, 0), Alignment.left.calculate(5, 20));
    try std.testing.expectEqual(@as(usize, 7), Alignment.center.calculate(6, 20));
    try std.testing.expectEqual(@as(usize, 15), Alignment.right.calculate(5, 20));
}
