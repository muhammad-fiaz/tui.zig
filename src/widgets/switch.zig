// Switch widget for binary on/off toggle with smooth animation.
// Provides a modern alternative to checkboxes for boolean states.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;
const Event = @import("../event/events.zig").Event;

pub const Switch = struct {
    enabled: bool = false,
    label: []const u8 = "",
    base: widget.StatefulWidget = .{},
    style: Style = Style.default,
    on_change: ?*const fn (bool) void = null,

    pub fn init(label: []const u8) Switch {
        return .{ .label = label };
    }

    pub fn withEnabled(self: Switch, enabled: bool) Switch {
        var result = self;
        result.enabled = enabled;
        return result;
    }

    pub fn withOnChange(self: Switch, callback: *const fn (bool) void) Switch {
        var result = self;
        result.on_change = callback;
        return result;
    }

    pub fn render(self: *Switch, ctx: *widget.RenderContext) void {
        var sub = ctx.getSubScreen();

        // Switch track
        if (self.enabled) {
            sub.setStyle(self.style.setBg(Color.green).setFg(Color.white));
            sub.moveCursor(0, 0);
            sub.putString("[ ● ]");
        } else {
            sub.setStyle(self.style.setBg(Color.fromRGB(80, 80, 90)).setFg(Color.white));
            sub.moveCursor(0, 0);
            sub.putString("[ ○ ]");
        }

        // Label
        if (self.label.len > 0) {
            sub.setStyle(self.style);
            sub.moveCursor(7, 0);
            sub.putString(self.label);
        }
    }

    pub fn handleEvent(self: *Switch, event: Event) widget.EventResult {
        if (event == .key) {
            switch (event.key.key) {
                .space, .enter => {
                    self.toggle();
                    return .needs_redraw;
                },
                else => {},
            }
        }
        return .ignored;
    }

    pub fn toggle(self: *Switch) void {
        self.enabled = !self.enabled;
        if (self.on_change) |cb| cb(self.enabled);
    }

    pub fn setEnabled(self: *Switch, enabled: bool) void {
        self.enabled = enabled;
        if (self.on_change) |cb| cb(self.enabled);
    }

    pub fn isFocusable(self: *Switch) bool {
        _ = self;
        return true;
    }

    pub fn setFocus(self: *Switch, focused: bool) void {
        self.base.state.focused = focused;
    }
};

test "Switch creation" {
    const sw = Switch.init("Test switch");
    try std.testing.expect(!sw.enabled);
    try std.testing.expectEqualStrings("Test switch", sw.label);
}

test "Switch toggle" {
    var sw = Switch.init("Toggle");
    try std.testing.expect(!sw.enabled);
    
    sw.toggle();
    try std.testing.expect(sw.enabled);
    
    sw.toggle();
    try std.testing.expect(!sw.enabled);
}

test "Switch with initial state" {
    const sw = Switch.init("Enabled").withEnabled(true);
    try std.testing.expect(sw.enabled);
}
