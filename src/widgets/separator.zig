// Separator widget for visual division of content sections.
// Supports horizontal and vertical orientations with various styles.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;

pub const SeparatorOrientation = enum {
    horizontal,
    vertical,
};

pub const SeparatorStyle = enum {
    solid,
    dashed,
    dotted,
    double,
    thick,
};

pub const Separator = struct {
    orientation: SeparatorOrientation = .horizontal,
    separator_style: SeparatorStyle = .solid,
    label: ?[]const u8 = null,
    base: widget.StatefulWidget = .{},
    style: Style = Style.default,

    pub fn init() Separator {
        return .{};
    }

    pub fn withOrientation(self: Separator, orientation: SeparatorOrientation) Separator {
        var result = self;
        result.orientation = orientation;
        return result;
    }

    pub fn withStyle(self: Separator, separator_style: SeparatorStyle) Separator {
        var result = self;
        result.separator_style = separator_style;
        return result;
    }

    pub fn withLabel(self: Separator, label: []const u8) Separator {
        var result = self;
        result.label = label;
        return result;
    }

    pub fn render(self: *Separator, ctx: *widget.RenderContext) void {
        var sub = ctx.getSubScreen();
        sub.setStyle(self.style.setFg(Color.fromRGB(100, 100, 120)));

        if (self.orientation == .horizontal) {
            self.renderHorizontal(&sub);
        } else {
            self.renderVertical(&sub);
        }
    }

    fn renderHorizontal(self: *Separator, sub: anytype) void {
        const char = self.getChar();
        const y: u16 = 0;

        if (self.label) |label| {
            const label_len: u16 = @intCast(label.len);
            const label_x = (sub.width -| label_len) / 2;
            const left_width = if (label_x > 2) label_x - 2 else 0;
            const right_start = label_x + label_len + 2;

            // Left line
            sub.moveCursor(0, y);
            for (0..left_width) |_| sub.putString(char);

            // Label
            sub.moveCursor(label_x, y);
            sub.setStyle(self.style.bold());
            sub.putString(label);
            sub.setStyle(self.style.setFg(Color.fromRGB(100, 100, 120)));

            // Right line
            if (right_start < sub.width) {
                sub.moveCursor(right_start, y);
                for (right_start..sub.width) |_| sub.putString(char);
            }
        } else {
            sub.moveCursor(0, y);
            for (0..sub.width) |_| sub.putString(char);
        }
    }

    fn renderVertical(self: *Separator, sub: anytype) void {
        const char = self.getChar();
        const x: u16 = 0;

        for (0..sub.height) |dy| {
            sub.moveCursor(x, @intCast(dy));
            sub.putString(char);
        }
    }

    fn getChar(self: *Separator) []const u8 {
        if (self.orientation == .horizontal) {
            return switch (self.separator_style) {
                .solid => "─",
                .dashed => "╌",
                .dotted => "┄",
                .double => "═",
                .thick => "━",
            };
        } else {
            return switch (self.separator_style) {
                .solid => "│",
                .dashed => "╎",
                .dotted => "┆",
                .double => "║",
                .thick => "┃",
            };
        }
    }
};
