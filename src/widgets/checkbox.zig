//! Checkbox widget

const std = @import("std");
const widget = @import("widget.zig");
const layout = @import("../layout/layout.zig");
const style_mod = @import("../style/style.zig");
const events = @import("../event/events.zig");
const input_mod = @import("../event/input.zig");
const unicode = @import("../unicode/unicode.zig");

pub const RenderContext = widget.RenderContext;
pub const StatefulWidget = widget.StatefulWidget;
pub const SizeHint = widget.SizeHint;
pub const EventResult = widget.EventResult;
pub const Style = style_mod.Style;
pub const Event = events.Event;
pub const Rect = layout.Rect;

/// Checkbox widget
pub const Checkbox = struct {
    /// Label text
    label: []const u8,

    /// Whether checked
    checked: bool = false,

    /// Change callback
    on_change: ?*const fn (bool) void = null,

    /// Checked symbol
    checked_symbol: []const u8 = "☑",

    /// Unchecked symbol
    unchecked_symbol: []const u8 = "☐",

    /// Style
    style: Style = .{},

    /// Base widget state
    base: StatefulWidget = .{},

    /// Create a checkbox
    pub fn init(label: []const u8, on_change: ?*const fn (bool) void) Checkbox {
        return .{
            .label = label,
            .on_change = on_change,
        };
    }

    /// Create with initial checked state
    pub fn initChecked(label: []const u8, checked: bool, on_change: ?*const fn (bool) void) Checkbox {
        return .{
            .label = label,
            .checked = checked,
            .on_change = on_change,
        };
    }

    /// Set checked state
    pub fn setChecked(self: *Checkbox, checked: bool) void {
        if (self.checked != checked) {
            self.checked = checked;
            self.base.markDirty();
            if (self.on_change) |callback| {
                callback(checked);
            }
        }
    }

    /// Toggle checked state
    pub fn toggle(self: *Checkbox) void {
        self.setChecked(!self.checked);
    }

    /// Render the checkbox
    pub fn render(self: *Checkbox, ctx: *RenderContext) void {
        var sub = ctx.getSubScreen();

        // Determine style
        var current_style = self.style;
        if (self.base.state.focused) {
            current_style = current_style.bold();
        }
        if (self.base.state.disabled) {
            current_style = ctx.theme.disabled;
        }

        sub.setStyle(current_style);

        // Draw checkbox
        sub.moveCursor(0, 0);
        sub.putString(if (self.checked) self.checked_symbol else self.unchecked_symbol);
        sub.putString(" ");
        sub.putString(self.label);
    }

    /// Handle events
    pub fn handleEvent(self: *Checkbox, event: Event) EventResult {
        if (self.base.state.disabled) return .ignored;

        switch (event) {
            .key => |key_event| {
                if (key_event.key == .enter or key_event.key == .space) {
                    self.toggle();
                    return .consumed;
                }
            },
            .mouse => |mouse_event| {
                if (mouse_event.kind == .press and mouse_event.button == .left) {
                    self.toggle();
                    return .consumed;
                }
            },
            else => {},
        }

        return .ignored;
    }

    /// Check if focusable
    pub fn isFocusable(self: *Checkbox) bool {
        return !self.base.state.disabled;
    }

    /// Set focus
    pub fn setFocus(self: *Checkbox, focused: bool) void {
        self.base.state.focused = focused;
        self.base.markDirty();
    }

    /// Get size hint
    pub fn sizeHint(self: *Checkbox) SizeHint {
        const label_width = unicode.stringWidth(self.label);
        return .{
            .min_width = @intCast(label_width + 2),
            .preferred_width = @intCast(label_width + 2),
            .min_height = 1,
            .preferred_height = 1,
        };
    }
};

/// Radio button widget
pub const RadioButton = struct {
    label: []const u8,
    selected: bool = false,
    group: ?*RadioGroup = null,
    on_select: ?*const fn () void = null,
    selected_symbol: []const u8 = "●",
    unselected_symbol: []const u8 = "○",
    style: Style = .{},
    base: StatefulWidget = .{},

    pub fn init(label: []const u8) RadioButton {
        return .{ .label = label };
    }

    pub fn select(self: *RadioButton) void {
        if (self.group) |group| {
            group.select(self);
        } else {
            self.selected = true;
            self.base.markDirty();
        }
        if (self.on_select) |callback| {
            callback();
        }
    }

    pub fn render(self: *RadioButton, ctx: *RenderContext) void {
        var sub = ctx.getSubScreen();

        var current_style = self.style;
        if (self.base.state.focused) {
            current_style = current_style.bold();
        }

        sub.setStyle(current_style);
        sub.moveCursor(0, 0);
        sub.putString(if (self.selected) self.selected_symbol else self.unselected_symbol);
        sub.putString(" ");
        sub.putString(self.label);
    }

    pub fn handleEvent(self: *RadioButton, event: Event) EventResult {
        if (self.base.state.disabled) return .ignored;

        switch (event) {
            .key => |key_event| {
                if (key_event.key == .enter or key_event.key == .space) {
                    self.select();
                    return .consumed;
                }
            },
            .mouse => |mouse_event| {
                if (mouse_event.kind == .press and mouse_event.button == .left) {
                    self.select();
                    return .consumed;
                }
            },
            else => {},
        }

        return .ignored;
    }

    pub fn isFocusable(self: *RadioButton) bool {
        return !self.base.state.disabled;
    }
};

/// Radio button group manager
pub const RadioGroup = struct {
    buttons: std.ArrayList(*RadioButton),
    selected_index: ?usize = null,

    pub fn init(allocator: std.mem.Allocator) RadioGroup {
        return .{
            .buttons = std.ArrayList(*RadioButton).init(allocator),
        };
    }

    pub fn deinit(self: *RadioGroup) void {
        self.buttons.deinit();
    }

    pub fn add(self: *RadioGroup, button: *RadioButton) !void {
        button.group = self;
        try self.buttons.append(button);
    }

    pub fn select(self: *RadioGroup, button: *RadioButton) void {
        for (self.buttons.items, 0..) |btn, i| {
            if (btn == button) {
                btn.selected = true;
                btn.base.markDirty();
                self.selected_index = i;
            } else {
                btn.selected = false;
                btn.base.markDirty();
            }
        }
    }
};

test "checkbox creation" {
    const cb = Checkbox.init("Test", null);
    try std.testing.expect(!cb.checked);
}

test "checkbox toggle" {
    var cb = Checkbox.init("Test", null);
    cb.toggle();
    try std.testing.expect(cb.checked);
    cb.toggle();
    try std.testing.expect(!cb.checked);
}
