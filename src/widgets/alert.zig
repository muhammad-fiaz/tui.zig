// Alert widget for displaying important messages with severity levels.
// Supports info, success, warning, and error variants.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;
const Event = @import("../event/events.zig").Event;

pub const AlertType = enum {
    info,
    success,
    warning,
    error_alert,
};

pub const Alert = struct {
    title: []const u8,
    message: []const u8,
    alert_type: AlertType = .info,
    dismissible: bool = false,
    visible: bool = true,
    base: widget.StatefulWidget = .{},
    on_dismiss: ?*const fn () void = null,

    pub fn init(title: []const u8, message: []const u8) Alert {
        return .{ .title = title, .message = message };
    }

    pub fn withType(self: Alert, alert_type: AlertType) Alert {
        var result = self;
        result.alert_type = alert_type;
        return result;
    }

    pub fn withDismissible(self: Alert, dismissible: bool) Alert {
        var result = self;
        result.dismissible = dismissible;
        return result;
    }

    pub fn withOnDismiss(self: Alert, callback: *const fn () void) Alert {
        var result = self;
        result.on_dismiss = callback;
        return result;
    }

    pub fn render(self: *Alert, ctx: *widget.RenderContext) void {
        if (!self.visible) return;

        var sub = ctx.getSubScreen();
        const colors = self.getColors();

        // Background
        sub.setStyle(Style.default.setBg(colors.bg).setFg(colors.fg));
        for (0..@min(sub.height, 5)) |dy| {
            sub.moveCursor(0, @intCast(dy));
            for (0..sub.width) |_| sub.putChar(' ');
        }

        // Icon and title
        sub.moveCursor(2, 1);
        sub.setStyle(Style.default.setBg(colors.bg).setFg(colors.icon).bold());
        sub.putString(self.getIcon());
        sub.putString(" ");
        sub.putString(self.title);

        // Dismiss button
        if (self.dismissible) {
            sub.moveCursor(sub.width -| 4, 1);
            sub.setStyle(Style.default.setBg(colors.bg).setFg(colors.fg));
            sub.putString("[X]");
        }

        // Message
        sub.moveCursor(2, 2);
        sub.setStyle(Style.default.setBg(colors.bg).setFg(colors.fg));
        
        var remaining = self.message;
        var y: u16 = 2;
        while (remaining.len > 0 and y < sub.height) {
            const line_width = @min(remaining.len, sub.width -| 4);
            sub.moveCursor(2, y);
            sub.putString(remaining[0..line_width]);
            remaining = if (line_width < remaining.len) remaining[line_width..] else "";
            y += 1;
        }
    }

    pub fn handleEvent(self: *Alert, event: Event) widget.EventResult {
        if (!self.dismissible or !self.visible) return .ignored;

        if (event == .key) {
            if (event.key.key == .escape or 
               (event.key.key == .char and (event.key.key.char == 'x' or event.key.key.char == 'X'))) {
                self.dismiss();
                return .needs_redraw;
            }
        }
        return .ignored;
    }

    pub fn dismiss(self: *Alert) void {
        self.visible = false;
        if (self.on_dismiss) |cb| cb();
    }

    pub fn show(self: *Alert) void {
        self.visible = true;
    }

    fn getColors(self: *Alert) struct { bg: Color, fg: Color, icon: Color } {
        return switch (self.alert_type) {
            .info => .{
                .bg = Color.fromRGB(30, 60, 100),
                .fg = Color.fromRGB(200, 220, 255),
                .icon = Color.fromRGB(100, 180, 255),
            },
            .success => .{
                .bg = Color.fromRGB(20, 60, 30),
                .fg = Color.fromRGB(200, 255, 220),
                .icon = Color.fromRGB(100, 255, 150),
            },
            .warning => .{
                .bg = Color.fromRGB(80, 60, 20),
                .fg = Color.fromRGB(255, 240, 200),
                .icon = Color.fromRGB(255, 200, 100),
            },
            .error_alert => .{
                .bg = Color.fromRGB(80, 20, 20),
                .fg = Color.fromRGB(255, 220, 220),
                .icon = Color.fromRGB(255, 100, 100),
            },
        };
    }

    fn getIcon(self: *Alert) []const u8 {
        return switch (self.alert_type) {
            .info => "ℹ",
            .success => "✓",
            .warning => "⚠",
            .error_alert => "✗",
        };
    }
};

pub const AlertDialog = struct {
    title: []const u8,
    message: []const u8,
    confirm_text: []const u8 = "OK",
    cancel_text: []const u8 = "Cancel",
    visible: bool = false,
    base: widget.StatefulWidget = .{},
    on_confirm: ?*const fn () void = null,
    on_cancel: ?*const fn () void = null,
    focused_button: u8 = 0,

    pub fn init(title: []const u8, message: []const u8) AlertDialog {
        return .{ .title = title, .message = message };
    }

    pub fn show(self: *AlertDialog) void {
        self.visible = true;
    }

    pub fn hide(self: *AlertDialog) void {
        self.visible = false;
    }

    pub fn render(self: *AlertDialog, ctx: *widget.RenderContext) void {
        if (!self.visible) return;

        var sub = ctx.getSubScreen();
        const width: u16 = 50;
        const height: u16 = 12;
        const x = (sub.width -| width) / 2;
        const y = (sub.height -| height) / 2;

        // Overlay
        sub.setStyle(Style.default.setBg(Color.fromRGB(40, 42, 54)));
        for (0..height) |dy| {
            sub.moveCursor(x, y + @as(u16, @intCast(dy)));
            for (0..width) |_| sub.putChar(' ');
        }

        // Border
        sub.setStyle(Style.default.setFg(Color.fromRGB(150, 150, 170)));
        sub.moveCursor(x, y);
        sub.putString("╔");
        for (1..width - 1) |_| sub.putString("═");
        sub.putString("╗");

        for (1..height - 1) |dy| {
            sub.moveCursor(x, y + @as(u16, @intCast(dy)));
            sub.putString("║");
            sub.moveCursor(x + width - 1, y + @as(u16, @intCast(dy)));
            sub.putString("║");
        }

        sub.moveCursor(x, y + height - 1);
        sub.putString("╚");
        for (1..width - 1) |_| sub.putString("═");
        sub.putString("╝");

        // Title
        sub.setStyle(Style.default.setFg(Color.yellow).bold());
        sub.moveCursor(x + 2, y + 1);
        sub.putString(self.title);

        // Message
        sub.setStyle(Style.default.setFg(Color.white));
        sub.moveCursor(x + 2, y + 3);
        sub.putString(self.message);

        // Buttons
        const button_y = y + height - 3;
        const confirm_x = x + width / 2 - 15;
        const cancel_x = x + width / 2 + 3;

        if (self.focused_button == 0) {
            sub.setStyle(Style.default.setBg(Color.green).setFg(Color.black).bold());
        } else {
            sub.setStyle(Style.default.setFg(Color.green));
        }
        sub.moveCursor(confirm_x, button_y);
        sub.putString(" ");
        sub.putString(self.confirm_text);
        sub.putString(" ");

        if (self.focused_button == 1) {
            sub.setStyle(Style.default.setBg(Color.red).setFg(Color.white).bold());
        } else {
            sub.setStyle(Style.default.setFg(Color.red));
        }
        sub.moveCursor(cancel_x, button_y);
        sub.putString(" ");
        sub.putString(self.cancel_text);
        sub.putString(" ");
    }

    pub fn handleEvent(self: *AlertDialog, event: Event) widget.EventResult {
        if (!self.visible) return .ignored;

        if (event == .key) {
            switch (event.key.key) {
                .left, .right, .tab => {
                    self.focused_button = 1 - self.focused_button;
                    return .needs_redraw;
                },
                .enter => {
                    if (self.focused_button == 0) {
                        if (self.on_confirm) |cb| cb();
                    } else {
                        if (self.on_cancel) |cb| cb();
                    }
                    self.hide();
                    return .needs_redraw;
                },
                .escape => {
                    if (self.on_cancel) |cb| cb();
                    self.hide();
                    return .needs_redraw;
                },
                else => {},
            }
        }
        return .ignored;
    }
};
