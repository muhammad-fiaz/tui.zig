// Badge widget for labels, tags, and status indicators.
// Supports various colors and sizes for different use cases.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;

pub const BadgeVariant = enum {
    default,
    primary,
    secondary,
    success,
    warning,
    error_badge,
    info,
};

pub const BadgeSize = enum {
    small,
    medium,
    large,
};

pub const Badge = struct {
    text: []const u8,
    variant: BadgeVariant = .default,
    size: BadgeSize = .medium,
    base: widget.StatefulWidget = .{},

    pub fn init(text: []const u8) Badge {
        return .{ .text = text };
    }

    pub fn withVariant(self: Badge, variant: BadgeVariant) Badge {
        var result = self;
        result.variant = variant;
        return result;
    }

    pub fn withSize(self: Badge, size: BadgeSize) Badge {
        var result = self;
        result.size = size;
        return result;
    }

    pub fn render(self: *Badge, ctx: *widget.RenderContext) void {
        var sub = ctx.getSubScreen();
        const colors = self.getColors();
        const padding = self.getPadding();

        sub.setStyle(Style.default.setBg(colors.bg).setFg(colors.fg).bold());
        sub.moveCursor(0, 0);
        
        for (0..padding) |_| sub.putChar(' ');
        sub.putString(self.text);
        for (0..padding) |_| sub.putChar(' ');
    }

    fn getColors(self: *Badge) struct { bg: Color, fg: Color } {
        return switch (self.variant) {
            .default => .{ .bg = Color.fromRGB(80, 80, 90), .fg = Color.white },
            .primary => .{ .bg = Color.fromRGB(60, 120, 255), .fg = Color.white },
            .secondary => .{ .bg = Color.fromRGB(100, 100, 120), .fg = Color.white },
            .success => .{ .bg = Color.fromRGB(50, 200, 100), .fg = Color.black },
            .warning => .{ .bg = Color.fromRGB(255, 180, 50), .fg = Color.black },
            .error_badge => .{ .bg = Color.fromRGB(255, 80, 80), .fg = Color.white },
            .info => .{ .bg = Color.fromRGB(80, 180, 255), .fg = Color.white },
        };
    }

    fn getPadding(self: *Badge) usize {
        return switch (self.size) {
            .small => 1,
            .medium => 2,
            .large => 3,
        };
    }
};
