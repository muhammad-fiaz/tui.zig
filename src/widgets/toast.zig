// Toast notification widget for temporary messages.
// Auto-dismisses after a timeout with smooth fade animations.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;

pub const ToastType = enum {
    info,
    success,
    warning,
    error_toast,
};

pub const ToastPosition = enum {
    top_left,
    top_center,
    top_right,
    bottom_left,
    bottom_center,
    bottom_right,
};

pub const Toast = struct {
    message: []const u8,
    toast_type: ToastType = .info,
    position: ToastPosition = .bottom_right,
    visible: bool = false,
    duration_ms: u32 = 3000,
    elapsed_ms: u32 = 0,
    base: widget.StatefulWidget = .{},

    pub fn init(message: []const u8) Toast {
        return .{ .message = message };
    }

    pub fn withType(self: Toast, toast_type: ToastType) Toast {
        var result = self;
        result.toast_type = toast_type;
        return result;
    }

    pub fn withPosition(self: Toast, position: ToastPosition) Toast {
        var result = self;
        result.position = position;
        return result;
    }

    pub fn withDuration(self: Toast, duration_ms: u32) Toast {
        var result = self;
        result.duration_ms = duration_ms;
        return result;
    }

    pub fn show(self: *Toast) void {
        self.visible = true;
        self.elapsed_ms = 0;
    }

    pub fn hide(self: *Toast) void {
        self.visible = false;
    }

    pub fn update(self: *Toast, delta_ms: u32) void {
        if (!self.visible) return;

        self.elapsed_ms += delta_ms;
        if (self.elapsed_ms >= self.duration_ms) {
            self.hide();
        }
    }

    pub fn render(self: *Toast, ctx: *widget.RenderContext) void {
        if (!self.visible) return;

        var sub = ctx.getSubScreen();
        const colors = self.getColors();
        const icon = self.getIcon();
        
        const msg_len: u16 = @intCast(self.message.len);
        const width = msg_len + 6;
        const height: u16 = 3;

        // Calculate position
        const pos = self.calculatePosition(sub.width, sub.height, width, height);

        // Background
        sub.setStyle(Style.default.setBg(colors.bg).setFg(colors.fg));
        for (0..height) |dy| {
            sub.moveCursor(pos.x, pos.y + @as(u16, @intCast(dy)));
            for (0..width) |_| sub.putChar(' ');
        }

        // Icon and message
        sub.moveCursor(pos.x + 2, pos.y + 1);
        sub.setStyle(Style.default.setBg(colors.bg).setFg(colors.icon).bold());
        sub.putString(icon);
        sub.putString(" ");
        sub.setStyle(Style.default.setBg(colors.bg).setFg(colors.fg));
        sub.putString(self.message);

        // Progress bar
        if (self.duration_ms > 0) {
            const progress = @as(f32, @floatFromInt(self.elapsed_ms)) / @as(f32, @floatFromInt(self.duration_ms));
            const bar_width = @as(u16, @intFromFloat(@as(f32, @floatFromInt(width - 2)) * (1.0 - progress)));
            
            sub.setStyle(Style.default.setBg(colors.icon));
            sub.moveCursor(pos.x + 1, pos.y + height - 1);
            for (0..bar_width) |_| sub.putChar(' ');
        }
    }

    fn calculatePosition(self: *Toast, screen_width: u16, screen_height: u16, width: u16, height: u16) struct { x: u16, y: u16 } {
        return switch (self.position) {
            .top_left => .{ .x = 2, .y = 2 },
            .top_center => .{ .x = (screen_width -| width) / 2, .y = 2 },
            .top_right => .{ .x = screen_width -| width - 2, .y = 2 },
            .bottom_left => .{ .x = 2, .y = screen_height -| height - 2 },
            .bottom_center => .{ .x = (screen_width -| width) / 2, .y = screen_height -| height - 2 },
            .bottom_right => .{ .x = screen_width -| width - 2, .y = screen_height -| height - 2 },
        };
    }

    fn getColors(self: *Toast) struct { bg: Color, fg: Color, icon: Color } {
        return switch (self.toast_type) {
            .info => .{
                .bg = Color.fromRGB(40, 60, 100),
                .fg = Color.fromRGB(220, 230, 255),
                .icon = Color.fromRGB(100, 180, 255),
            },
            .success => .{
                .bg = Color.fromRGB(30, 70, 40),
                .fg = Color.fromRGB(220, 255, 230),
                .icon = Color.fromRGB(100, 255, 150),
            },
            .warning => .{
                .bg = Color.fromRGB(90, 70, 30),
                .fg = Color.fromRGB(255, 240, 220),
                .icon = Color.fromRGB(255, 200, 100),
            },
            .error_toast => .{
                .bg = Color.fromRGB(90, 30, 30),
                .fg = Color.fromRGB(255, 220, 220),
                .icon = Color.fromRGB(255, 100, 100),
            },
        };
    }

    fn getIcon(self: *Toast) []const u8 {
        return switch (self.toast_type) {
            .info => "ℹ",
            .success => "✓",
            .warning => "⚠",
            .error_toast => "✗",
        };
    }
};

pub const ToastManager = struct {
    toasts: std.ArrayList(Toast),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ToastManager {
        return .{
            .toasts = std.ArrayList(Toast){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ToastManager) void {
        self.toasts.deinit();
    }

    pub fn show(self: *ToastManager, toast: Toast) !void {
        var new_toast = toast;
        new_toast.show();
        try self.toasts.append(self.allocator, new_toast);
    }

    pub fn update(self: *ToastManager, delta_ms: u32) void {
        var i: usize = 0;
        while (i < self.toasts.items.len) {
            self.toasts.items[i].update(delta_ms);
            if (!self.toasts.items[i].visible) {
                _ = self.toasts.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }

    pub fn render(self: *ToastManager, ctx: *widget.RenderContext) void {
        for (self.toasts.items) |*toast| {
            toast.render(ctx);
        }
    }

    pub fn clear(self: *ToastManager) void {
        self.toasts.clearRetainingCapacity();
    }
};

test "Toast creation and visibility" {
    var toast = Toast.init("Test message");
    try std.testing.expect(!toast.visible);
    
    toast.show();
    try std.testing.expect(toast.visible);
    try std.testing.expectEqual(@as(u32, 0), toast.elapsed_ms);
    
    toast.hide();
    try std.testing.expect(!toast.visible);
}

test "Toast with type and position" {
    const toast = Toast.init("Success")
        .withType(.success)
        .withPosition(.top_center)
        .withDuration(5000);
    
    try std.testing.expectEqual(ToastType.success, toast.toast_type);
    try std.testing.expectEqual(ToastPosition.top_center, toast.position);
    try std.testing.expectEqual(@as(u32, 5000), toast.duration_ms);
}

test "Toast auto-dismiss" {
    var toast = Toast.init("Auto dismiss").withDuration(1000);
    toast.show();
    
    toast.update(500);
    try std.testing.expect(toast.visible);
    
    toast.update(600);
    try std.testing.expect(!toast.visible);
}
