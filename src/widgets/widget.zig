//! Base widget trait and utilities for TUI.zig

const std = @import("std");
const layout = @import("../layout/layout.zig");
const screen_mod = @import("../core/screen.zig");
const events = @import("../event/events.zig");
const style_mod = @import("../style/style.zig");
const theme_mod = @import("../style/theme.zig");

pub const Rect = layout.Rect;
pub const Screen = screen_mod.Screen;
pub const SubScreen = screen_mod.SubScreen;
pub const Event = events.Event;
pub const Style = style_mod.Style;
pub const Theme = theme_mod.Theme;

/// Widget state flags
pub const WidgetState = packed struct {
    focused: bool = false,
    hovered: bool = false,
    pressed: bool = false,
    disabled: bool = false,
    visible: bool = true,
    dirty: bool = true,
    _padding: u2 = 0,
};

/// Widget ID for event routing
pub const WidgetId = u32;

/// Focus direction
pub const FocusDirection = enum {
    next,
    previous,
    up,
    down,
    left,
    right,
};

/// Size hint for layout
pub const SizeHint = struct {
    min_width: u16 = 0,
    min_height: u16 = 0,
    preferred_width: u16 = 0,
    preferred_height: u16 = 0,
    max_width: u16 = std.math.maxInt(u16),
    max_height: u16 = std.math.maxInt(u16),
    expand_x: bool = false,
    expand_y: bool = false,
};

/// Context passed to widgets during rendering
pub const RenderContext = struct {
    screen: *Screen,
    theme: *const Theme,
    bounds: Rect,
    clip: Rect,
    focused_id: ?WidgetId,
    time_ns: u64,

    /// Get a sub-screen clipped to the current bounds
    pub fn getSubScreen(self: *RenderContext) SubScreen {
        return self.screen.subRegion(
            self.bounds.x,
            self.bounds.y,
            self.bounds.width,
            self.bounds.height,
        );
    }

    /// Create a child context with different bounds
    pub fn child(self: RenderContext, bounds: Rect) RenderContext {
        return .{
            .screen = self.screen,
            .theme = self.theme,
            .bounds = bounds,
            .clip = self.clip.intersection(bounds),
            .focused_id = self.focused_id,
            .time_ns = self.time_ns,
        };
    }
};

/// Event result indicating how an event was handled
pub const EventResult = enum {
    /// Event was not handled, propagate to parent
    ignored,

    /// Event was handled, stop propagation
    consumed,

    /// Request focus
    request_focus,

    /// Yield focus
    yield_focus,

    /// Request redraw
    needs_redraw,
};

/// Generic widget interface using comptime duck typing
pub fn Widget(comptime T: type) type {
    return struct {
        ptr: *T,

        const Self = @This();

        pub fn init(ptr: *T) Self {
            return .{ .ptr = ptr };
        }

        /// Render the widget
        pub fn render(self: Self, ctx: *RenderContext) void {
            if (@hasDecl(T, "render")) {
                self.ptr.render(ctx);
            }
        }

        /// Handle an event
        pub fn handleEvent(self: Self, event: Event) EventResult {
            if (@hasDecl(T, "handleEvent")) {
                return self.ptr.handleEvent(event);
            }
            return .ignored;
        }

        /// Get size hint
        pub fn sizeHint(self: Self) SizeHint {
            if (@hasDecl(T, "sizeHint")) {
                return self.ptr.sizeHint();
            }
            return .{};
        }

        /// Layout the widget within given bounds
        pub fn layout_widget(self: Self, bounds: Rect) void {
            if (@hasDecl(T, "layout")) {
                self.ptr.layout(bounds);
            }
        }

        /// Check if focusable
        pub fn isFocusable(self: Self) bool {
            if (@hasDecl(T, "isFocusable")) {
                return self.ptr.isFocusable();
            }
            return false;
        }

        /// Set focus
        pub fn setFocus(self: Self, focused: bool) void {
            if (@hasDecl(T, "setFocus")) {
                self.ptr.setFocus(focused);
            }
        }
    };
}

/// Stateful widget base
pub const StatefulWidget = struct {
    id: WidgetId = 0,
    state: WidgetState = .{},
    bounds: Rect = .{},
    user_data: ?*anyopaque = null,

    /// Mark as needing redraw
    pub fn markDirty(self: *StatefulWidget) void {
        self.state.dirty = true;
    }

    /// Clear dirty flag
    pub fn clearDirty(self: *StatefulWidget) void {
        self.state.dirty = false;
    }

    /// Check if visible and should render
    pub fn shouldRender(self: StatefulWidget) bool {
        return self.state.visible and !self.bounds.isEmpty();
    }

    /// Enable/disable the widget
    pub fn setEnabled(self: *StatefulWidget, enabled: bool) void {
        self.state.disabled = !enabled;
        self.markDirty();
    }

    /// Set visibility
    pub fn setVisible(self: *StatefulWidget, visible: bool) void {
        self.state.visible = visible;
        self.markDirty();
    }
};

/// Callback types
pub const VoidCallback = *const fn () void;
pub const BoolCallback = *const fn (bool) void;
pub const StringCallback = *const fn ([]const u8) void;
pub const IntCallback = *const fn (i64) void;

/// Optional callback that can be null
pub fn OptionalCallback(comptime T: type) type {
    return ?*const fn (T) void;
}

/// Wrap a widget in a bordered container
pub fn Bordered(comptime ChildType: type) type {
    return struct {
        child: ChildType,
        border_style: style_mod.BorderStyle = .single,
        title: ?[]const u8 = null,
        style: Style = .{},
        base: StatefulWidget = .{},

        const Self = @This();

        pub fn init(child: ChildType) Self {
            return .{ .child = child };
        }

        pub fn withTitle(self: Self, title: []const u8) Self {
            var result = self;
            result.title = title;
            return result;
        }

        pub fn withBorder(self: Self, border: style_mod.BorderStyle) Self {
            var result = self;
            result.border_style = border;
            return result;
        }

        pub fn render(self: *Self, ctx: *RenderContext) void {
            // Draw border
            ctx.screen.setStyle(self.style);
            ctx.screen.drawBox(
                self.base.bounds.x,
                self.base.bounds.y,
                self.base.bounds.width,
                self.base.bounds.height,
                self.border_style,
            );

            // Draw title if present
            if (self.title) |t| {
                const title_x = self.base.bounds.x + 2;
                const title_y = self.base.bounds.y;
                ctx.screen.setStyle(self.style.bold());
                ctx.screen.putStringAt(title_x, title_y, t);
            }

            // Render child in inner area
            if (@hasDecl(ChildType, "render")) {
                const inner = Rect.init(
                    self.base.bounds.x + 1,
                    self.base.bounds.y + 1,
                    self.base.bounds.width -| 2,
                    self.base.bounds.height -| 2,
                );
                var child_ctx = ctx.child(inner);
                self.child.render(&child_ctx);
            }
        }
    };
}

test "widget state" {
    var state = WidgetState{};
    try std.testing.expect(!state.focused);
    try std.testing.expect(state.visible);
    try std.testing.expect(state.dirty);

    state.focused = true;
    try std.testing.expect(state.focused);
}

test "size hint" {
    const hint = SizeHint{
        .min_width = 10,
        .preferred_width = 50,
    };
    try std.testing.expectEqual(@as(u16, 10), hint.min_width);
    try std.testing.expectEqual(@as(u16, 50), hint.preferred_width);
}
