// Slider widget for selecting numeric values within a range.
// Supports horizontal and vertical orientations with customizable steps.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;
const Event = @import("../event/events.zig").Event;

pub const SliderOrientation = enum {
    horizontal,
    vertical,
};

pub const Slider = struct {
    value: f32 = 0.5,
    min: f32 = 0.0,
    max: f32 = 1.0,
    step: f32 = 0.01,
    orientation: SliderOrientation = .horizontal,
    base: widget.StatefulWidget = .{},
    style: Style = Style.default,
    on_change: ?*const fn (f32) void = null,

    pub fn init(min: f32, max: f32) Slider {
        return .{ .min = min, .max = max, .value = (min + max) / 2.0 };
    }

    pub fn withValue(self: Slider, value: f32) Slider {
        var result = self;
        result.value = std.math.clamp(value, self.min, self.max);
        return result;
    }

    pub fn withStep(self: Slider, step: f32) Slider {
        var result = self;
        result.step = step;
        return result;
    }

    pub fn withOrientation(self: Slider, orientation: SliderOrientation) Slider {
        var result = self;
        result.orientation = orientation;
        return result;
    }

    pub fn withOnChange(self: Slider, callback: *const fn (f32) void) Slider {
        var result = self;
        result.on_change = callback;
        return result;
    }

    pub fn render(self: *Slider, ctx: *widget.RenderContext) void {
        var sub = ctx.getSubScreen();

        if (self.orientation == .horizontal) {
            self.renderHorizontal(&sub);
        } else {
            self.renderVertical(&sub);
        }
    }

    fn renderHorizontal(self: *Slider, sub: anytype) void {
        const width = sub.width;
        const normalized = (self.value - self.min) / (self.max - self.min);
        const pos = @as(u16, @intFromFloat(@as(f32, @floatFromInt(width)) * normalized));

        // Track
        sub.setStyle(self.style.setFg(Color.fromRGB(100, 100, 120)));
        sub.moveCursor(0, 0);
        for (0..width) |_| sub.putString("─");

        // Filled portion
        sub.setStyle(self.style.setFg(Color.cyan));
        sub.moveCursor(0, 0);
        for (0..pos) |_| sub.putString("━");

        // Handle
        sub.setStyle(self.style.setFg(Color.white).bold());
        sub.moveCursor(pos, 0);
        sub.putString("●");

        // Value display
        if (sub.height > 1) {
            var buf: [32]u8 = undefined;
            const value_str = std.fmt.bufPrint(&buf, "{d:.2}", .{self.value}) catch "?";
            sub.setStyle(self.style.dim());
            sub.moveCursor(0, 1);
            sub.putString(value_str);
        }
    }

    fn renderVertical(self: *Slider, sub: anytype) void {
        const height = sub.height;
        const normalized = (self.value - self.min) / (self.max - self.min);
        const pos = height - 1 - @as(u16, @intFromFloat(@as(f32, @floatFromInt(height - 1)) * normalized));

        // Track
        sub.setStyle(self.style.setFg(Color.fromRGB(100, 100, 120)));
        for (0..height) |dy| {
            sub.moveCursor(0, @intCast(dy));
            sub.putString("│");
        }

        // Filled portion
        sub.setStyle(self.style.setFg(Color.cyan));
        for (pos..height) |dy| {
            sub.moveCursor(0, @intCast(dy));
            sub.putString("┃");
        }

        // Handle
        sub.setStyle(self.style.setFg(Color.white).bold());
        sub.moveCursor(0, pos);
        sub.putString("●");
    }

    pub fn handleEvent(self: *Slider, event: Event) widget.EventResult {
        var changed = false;

        if (event == .key) {
            switch (event.key.key) {
                .left, .down => {
                    self.value = std.math.clamp(self.value - self.step, self.min, self.max);
                    changed = true;
                },
                .right, .up => {
                    self.value = std.math.clamp(self.value + self.step, self.min, self.max);
                    changed = true;
                },
                .home => {
                    self.value = self.min;
                    changed = true;
                },
                .end => {
                    self.value = self.max;
                    changed = true;
                },
                else => {},
            }
        }

        if (changed) {
            if (self.on_change) |cb| cb(self.value);
            return .needs_redraw;
        }

        return .ignored;
    }

    pub fn setValue(self: *Slider, value: f32) void {
        self.value = std.math.clamp(value, self.min, self.max);
        if (self.on_change) |cb| cb(self.value);
    }

    pub fn getValue(self: *Slider) f32 {
        return self.value;
    }
};

test "Slider creation and value" {
    const slider = Slider.init(0.0, 100.0);
    try std.testing.expectEqual(@as(f32, 50.0), slider.value);
    try std.testing.expectEqual(@as(f32, 0.0), slider.min);
    try std.testing.expectEqual(@as(f32, 100.0), slider.max);
}

test "Slider with custom value" {
    const slider = Slider.init(0.0, 100.0).withValue(75.0);
    try std.testing.expectEqual(@as(f32, 75.0), slider.value);
}

test "Slider value clamping" {
    var slider = Slider.init(0.0, 100.0);
    slider.setValue(150.0);
    try std.testing.expectEqual(@as(f32, 100.0), slider.value);
    
    slider.setValue(-50.0);
    try std.testing.expectEqual(@as(f32, 0.0), slider.value);
}

test "Slider orientation" {
    const h_slider = Slider.init(0.0, 1.0).withOrientation(.horizontal);
    try std.testing.expectEqual(SliderOrientation.horizontal, h_slider.orientation);
    
    const v_slider = Slider.init(0.0, 1.0).withOrientation(.vertical);
    try std.testing.expectEqual(SliderOrientation.vertical, v_slider.orientation);
}
