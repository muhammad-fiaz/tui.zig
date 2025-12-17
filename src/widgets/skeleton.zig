// Skeleton loader widget for displaying loading placeholders.
// Provides animated shimmer effect while content loads.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;

pub const SkeletonVariant = enum {
    text,
    circle,
    rectangle,
};

pub const Skeleton = struct {
    variant: SkeletonVariant = .rectangle,
    width: u16 = 20,
    height: u16 = 1,
    animate: bool = true,
    animation_offset: u16 = 0,
    base: widget.StatefulWidget = .{},

    pub fn init(variant: SkeletonVariant) Skeleton {
        return .{ .variant = variant };
    }

    pub fn withSize(self: Skeleton, width: u16, height: u16) Skeleton {
        var result = self;
        result.width = width;
        result.height = height;
        return result;
    }

    pub fn withAnimate(self: Skeleton, animate: bool) Skeleton {
        var result = self;
        result.animate = animate;
        return result;
    }

    pub fn update(self: *Skeleton) void {
        if (self.animate) {
            self.animation_offset = (self.animation_offset + 1) % (self.width + 10);
        }
    }

    pub fn render(self: *Skeleton, ctx: *widget.RenderContext) void {
        var sub = ctx.getSubScreen();

        switch (self.variant) {
            .text => self.renderText(&sub),
            .circle => self.renderCircle(&sub),
            .rectangle => self.renderRectangle(&sub),
        }
    }

    fn renderText(self: *Skeleton, sub: anytype) void {
        const base_color = Color.fromRGB(60, 60, 70);
        const shimmer_color = Color.fromRGB(80, 80, 90);

        for (0..@min(self.height, sub.height)) |dy| {
            sub.moveCursor(0, @intCast(dy));
            for (0..@min(self.width, sub.width)) |dx| {
                const color = if (self.animate and self.isShimmerPosition(@intCast(dx)))
                    shimmer_color
                else
                    base_color;
                
                sub.setStyle(Style.default.setBg(color));
                sub.putChar(' ');
            }
        }
    }

    fn renderCircle(self: *Skeleton, sub: anytype) void {
        const base_color = Color.fromRGB(60, 60, 70);
        const shimmer_color = Color.fromRGB(80, 80, 90);
        const radius = @min(self.width, self.height) / 2;
        const center_x = self.width / 2;
        const center_y = self.height / 2;

        for (0..@min(self.height, sub.height)) |dy| {
            sub.moveCursor(0, @intCast(dy));
            for (0..@min(self.width, sub.width)) |dx| {
                const dist_x = if (dx > center_x) dx - center_x else center_x - dx;
                const dist_y = if (dy > center_y) dy - center_y else center_y - dy;
                const dist = @sqrt(@as(f32, @floatFromInt(dist_x * dist_x + dist_y * dist_y)));

                if (dist <= @as(f32, @floatFromInt(radius))) {
                    const color = if (self.animate and self.isShimmerPosition(@intCast(dx)))
                        shimmer_color
                    else
                        base_color;
                    
                    sub.setStyle(Style.default.setBg(color));
                    sub.putChar(' ');
                } else {
                    sub.putChar(' ');
                }
            }
        }
    }

    fn renderRectangle(self: *Skeleton, sub: anytype) void {
        const base_color = Color.fromRGB(60, 60, 70);
        const shimmer_color = Color.fromRGB(80, 80, 90);

        for (0..@min(self.height, sub.height)) |dy| {
            sub.moveCursor(0, @intCast(dy));
            for (0..@min(self.width, sub.width)) |dx| {
                const color = if (self.animate and self.isShimmerPosition(@intCast(dx)))
                    shimmer_color
                else
                    base_color;
                
                sub.setStyle(Style.default.setBg(color));
                sub.putChar(' ');
            }
        }
    }

    fn isShimmerPosition(self: *Skeleton, x: u16) bool {
        const shimmer_width: u16 = 5;
        const start = if (self.animation_offset >= shimmer_width) 
            self.animation_offset - shimmer_width 
        else 
            0;
        const end = self.animation_offset;
        return x >= start and x <= end;
    }
};
