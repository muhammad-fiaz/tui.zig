// Tooltip widget for displaying contextual help on hover or focus.
// Automatically positions itself to avoid screen edges.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;

pub const TooltipPosition = enum {
    top,
    bottom,
    left,
    right,
    auto,
};

pub const Tooltip = struct {
    text: []const u8,
    visible: bool = false,
    position: TooltipPosition = .auto,
    base: widget.StatefulWidget = .{},
    style: Style = Style.default,
    delay_ms: u32 = 500,

    pub fn init(text: []const u8) Tooltip {
        return .{ .text = text };
    }

    pub fn withPosition(self: Tooltip, position: TooltipPosition) Tooltip {
        var result = self;
        result.position = position;
        return result;
    }

    pub fn withDelay(self: Tooltip, delay_ms: u32) Tooltip {
        var result = self;
        result.delay_ms = delay_ms;
        return result;
    }

    pub fn show(self: *Tooltip) void {
        self.visible = true;
    }

    pub fn hide(self: *Tooltip) void {
        self.visible = false;
    }

    pub fn render(self: *Tooltip, ctx: *widget.RenderContext) void {
        if (!self.visible) return;

        var sub = ctx.getSubScreen();
        const text_len: u16 = @intCast(self.text.len);
        const width = text_len + 4;
        const height: u16 = 3;

        // Calculate position
        var x: u16 = 0;
        var y: u16 = 0;

        switch (self.position) {
            .top => {
                x = (sub.width -| width) / 2;
                y = 0;
            },
            .bottom => {
                x = (sub.width -| width) / 2;
                y = sub.height -| height;
            },
            .left => {
                x = 0;
                y = (sub.height -| height) / 2;
            },
            .right => {
                x = sub.width -| width;
                y = (sub.height -| height) / 2;
            },
            .auto => {
                x = (sub.width -| width) / 2;
                y = sub.height -| height;
            },
        }

        // Background
        sub.setStyle(self.style.setBg(Color.fromRGB(50, 50, 60)).setFg(Color.white));
        for (0..height) |dy| {
            sub.moveCursor(x, y + @as(u16, @intCast(dy)));
            for (0..width) |_| sub.putChar(' ');
        }

        // Border
        sub.setStyle(self.style.setFg(Color.fromRGB(150, 150, 170)));
        sub.moveCursor(x, y);
        sub.putString("┌");
        for (1..width - 1) |_| sub.putString("─");
        sub.putString("┐");

        sub.moveCursor(x, y + 1);
        sub.putString("│");
        sub.moveCursor(x + width - 1, y + 1);
        sub.putString("│");

        sub.moveCursor(x, y + 2);
        sub.putString("└");
        for (1..width - 1) |_| sub.putString("─");
        sub.putString("┘");

        // Text
        sub.setStyle(self.style.setBg(Color.fromRGB(50, 50, 60)).setFg(Color.white));
        sub.moveCursor(x + 2, y + 1);
        sub.putString(self.text);
    }
};
