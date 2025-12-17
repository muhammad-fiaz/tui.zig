// Card widget for grouped content with header, body, and footer sections.
// Provides a container with optional borders and shadows.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;
const border_mod = @import("border.zig");

pub const Card = struct {
    title: ?[]const u8 = null,
    content: []const u8,
    footer: ?[]const u8 = null,
    border_style: border_mod.BorderStyle = .single,
    base: widget.StatefulWidget = .{},
    style: Style = Style.default,
    padding: u16 = 1,

    pub fn init(content: []const u8) Card {
        return .{ .content = content };
    }

    pub fn withTitle(self: Card, title: []const u8) Card {
        var result = self;
        result.title = title;
        return result;
    }

    pub fn withFooter(self: Card, footer: []const u8) Card {
        var result = self;
        result.footer = footer;
        return result;
    }

    pub fn withBorder(self: Card, border_style: border_mod.BorderStyle) Card {
        var result = self;
        result.border_style = border_style;
        return result;
    }

    pub fn withPadding(self: Card, padding: u16) Card {
        var result = self;
        result.padding = padding;
        return result;
    }

    pub fn render(self: *Card, ctx: *widget.RenderContext) void {
        var sub = ctx.getSubScreen();
        const chars = border_mod.BorderChars.fromStyle(self.border_style);

        // Draw border
        sub.setStyle(self.style.setFg(Color.fromRGB(150, 150, 170)));
        
        // Top
        sub.moveCursor(0, 0);
        sub.putString(chars.top_left);
        for (1..sub.width - 1) |_| sub.putString(chars.horizontal);
        sub.putString(chars.top_right);

        // Sides
        for (1..sub.height - 1) |dy| {
            sub.moveCursor(0, @intCast(dy));
            sub.putString(chars.vertical);
            sub.moveCursor(sub.width - 1, @intCast(dy));
            sub.putString(chars.vertical);
        }

        // Bottom
        sub.moveCursor(0, sub.height - 1);
        sub.putString(chars.bottom_left);
        for (1..sub.width - 1) |_| sub.putString(chars.horizontal);
        sub.putString(chars.bottom_right);

        var y: u16 = self.padding;

        // Title
        if (self.title) |title| {
            sub.setStyle(self.style.bold().setFg(Color.cyan));
            sub.moveCursor(self.padding + 1, y);
            sub.putString(title);
            y += 2;

            // Separator
            sub.setStyle(self.style.setFg(Color.fromRGB(100, 100, 120)));
            sub.moveCursor(1, y);
            for (1..sub.width - 1) |_| sub.putString(chars.horizontal);
            y += 1;
        }

        // Content
        sub.setStyle(self.style);
        const lines = std.mem.splitSequence(u8, self.content, "\n");
        var line_iter = lines;
        while (line_iter.next()) |line| {
            if (y >= sub.height - self.padding - 1) break;
            sub.moveCursor(self.padding + 1, y);
            sub.putString(line);
            y += 1;
        }

        // Footer
        if (self.footer) |footer| {
            const footer_y = sub.height - self.padding - 2;
            
            // Separator
            sub.setStyle(self.style.setFg(Color.fromRGB(100, 100, 120)));
            sub.moveCursor(1, footer_y);
            for (1..sub.width - 1) |_| sub.putString(chars.horizontal);

            // Footer text
            sub.setStyle(self.style.dim());
            sub.moveCursor(self.padding + 1, footer_y + 1);
            sub.putString(footer);
        }
    }
};
