//! Button widget for TUI.zig

const std = @import("std");
const widget = @import("widget.zig");
const layout = @import("../layout/layout.zig");
const style_mod = @import("../style/style.zig");
const theme_mod = @import("../style/theme.zig");
const events = @import("../event/events.zig");
const input = @import("../event/input.zig");
const unicode = @import("../unicode/unicode.zig");
const screen_mod = @import("../core/screen.zig");

pub const RenderContext = widget.RenderContext;
pub const StatefulWidget = widget.StatefulWidget;
pub const SizeHint = widget.SizeHint;
pub const EventResult = widget.EventResult;
pub const Style = style_mod.Style;
pub const Theme = theme_mod.Theme;
pub const Event = events.Event;
pub const Key = input.Key;
pub const Rect = layout.Rect;

/// Button widget
pub const Button = struct {
    /// Button label
    label: []const u8,

    /// Click callback
    on_click: ?*const fn () void = null,

    /// Normal style
    style: Style = .{},

    /// Hover style
    hover_style: ?Style = null,

    /// Pressed style
    pressed_style: ?Style = null,

    /// Focused style
    focused_style: ?Style = null,

    /// Disabled style
    disabled_style: ?Style = null,

    /// Base widget state
    base: StatefulWidget = .{},

    /// Create a button
    pub fn init(label: []const u8, on_click: ?*const fn () void) Button {
        return .{
            .label = label,
            .on_click = on_click,
        };
    }

    /// Set normal style
    pub fn withStyle(self: Button, s: Style) Button {
        var result = self;
        result.style = s;
        return result;
    }

    /// Set hover style
    pub fn withHoverStyle(self: Button, s: Style) Button {
        var result = self;
        result.hover_style = s;
        return result;
    }

    /// Render the button
    pub fn render(self: *Button, ctx: *RenderContext) void {
        const current_style = self.getCurrentStyle(ctx.theme);
        var sub = ctx.getSubScreen();
        sub.setStyle(current_style);

        // Clear background
        sub.clear();

        // Calculate label position (centered)
        const label_width = unicode.stringWidth(self.label);
        const x_offset = if (sub.width > label_width)
            (sub.width - @as(u16, @intCast(label_width))) / 2
        else
            0;

        const y_offset = sub.height / 2;

        // Draw brackets or border
        if (sub.width >= 4) {
            sub.moveCursor(0, y_offset);
            sub.putString("[");
            sub.moveCursor(sub.width - 1, y_offset);
            sub.putString("]");
        }

        // Draw label
        sub.moveCursor(x_offset, y_offset);
        sub.putString(self.label);
    }

    fn getCurrentStyle(self: *Button, theme: *const Theme) Style {
        if (self.base.state.disabled) {
            return self.disabled_style orelse theme.disabled;
        }
        if (self.base.state.pressed) {
            return self.pressed_style orelse theme.button_pressed;
        }
        if (self.base.state.hovered) {
            return self.hover_style orelse theme.button_hover;
        }
        if (self.base.state.focused) {
            return self.focused_style orelse theme.focus;
        }
        return self.style.merge(theme.button);
    }

    /// Handle events
    pub fn handleEvent(self: *Button, event: Event) EventResult {
        if (self.base.state.disabled) return .ignored;

        switch (event) {
            .key => |key_event| {
                if (key_event.key == .enter or key_event.key == .space) {
                    self.activate();
                    return .consumed;
                }
            },
            .mouse => |mouse_event| {
                switch (mouse_event.kind) {
                    .press => {
                        if (mouse_event.button == .left) {
                            self.base.state.pressed = true;
                            self.base.markDirty();
                            return .consumed;
                        }
                    },
                    .release => {
                        if (self.base.state.pressed) {
                            self.base.state.pressed = false;
                            self.activate();
                            return .consumed;
                        }
                    },
                    .move => {
                        self.base.state.hovered = true;
                        self.base.markDirty();
                        return .needs_redraw;
                    },
                    else => {},
                }
            },
            else => {},
        }

        return .ignored;
    }

    fn activate(self: *Button) void {
        self.base.state.pressed = false;
        self.base.markDirty();

        if (self.on_click) |callback| {
            callback();
        }
    }

    /// Check if focusable
    pub fn isFocusable(self: *Button) bool {
        return !self.base.state.disabled;
    }

    /// Set focus
    pub fn setFocus(self: *Button, focused: bool) void {
        self.base.state.focused = focused;
        self.base.markDirty();
    }

    /// Get size hint
    pub fn sizeHint(self: *Button) SizeHint {
        const label_width = unicode.stringWidth(self.label);
        return .{
            .min_width = @intCast(label_width + 4),
            .preferred_width = @intCast(label_width + 4),
            .min_height = 1,
            .preferred_height = 1,
        };
    }

    /// Layout
    pub fn layout_button(self: *Button, bounds: Rect) void {
        self.base.bounds = bounds;
    }
};

test "button creation" {
    const btn = Button.init("Click Me", null);
    try std.testing.expectEqualStrings("Click Me", btn.label);
}

test "button focusable" {
    var btn = Button.init("Test", null);
    try std.testing.expect(btn.isFocusable());

    btn.base.state.disabled = true;
    try std.testing.expect(!btn.isFocusable());
}
