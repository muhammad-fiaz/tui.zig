//! Split view widget

const std = @import("std");
const widget = @import("widget.zig");
const layout = @import("../layout/layout.zig");
const style_mod = @import("../style/style.zig");
const events = @import("../event/events.zig");

pub const RenderContext = widget.RenderContext;
pub const StatefulWidget = widget.StatefulWidget;
pub const SizeHint = widget.SizeHint;
pub const EventResult = widget.EventResult;
pub const Style = style_mod.Style;
pub const Event = events.Event;
pub const Rect = layout.Rect;
pub const BorderStyle = style_mod.BorderStyle;

/// Split view orientation
pub const Orientation = enum {
    horizontal,
    vertical,
};

/// Split view widget with resizable panes
pub fn SplitView(comptime FirstType: type, comptime SecondType: type) type {
    return struct {
        /// First pane content
        first: FirstType,

        /// Second pane content
        second: SecondType,

        /// Split orientation
        orientation: Orientation = .horizontal,

        /// Split ratio (0.0 - 1.0, position of divider)
        ratio: f32 = 0.5,

        /// Minimum pane size
        min_size: u16 = 5,

        /// Is dragging the divider
        dragging: bool = false,

        /// Show divider
        show_divider: bool = true,

        /// Divider character
        divider_char: []const u8 = "│",
        horizontal_divider_char: []const u8 = "─",

        /// Divider style
        divider_style: ?Style = null,

        /// Focus indicator (0 = first, 1 = second)
        focused_pane: u8 = 0,

        /// Base widget state
        base: StatefulWidget = .{},

        const Self = @This();

        /// Create a horizontal split view
        pub fn horizontal(first: FirstType, second: SecondType) Self {
            return .{
                .first = first,
                .second = second,
                .orientation = .horizontal,
            };
        }

        /// Create a vertical split view
        pub fn vertical(first: FirstType, second: SecondType) Self {
            return .{
                .first = first,
                .second = second,
                .orientation = .vertical,
            };
        }

        /// Set split ratio
        pub fn withRatio(self: Self, r: f32) Self {
            var result = self;
            result.ratio = std.math.clamp(r, 0.1, 0.9);
            return result;
        }

        /// Set minimum pane size
        pub fn withMinSize(self: Self, size: u16) Self {
            var result = self;
            result.min_size = size;
            return result;
        }

        /// Hide divider
        pub fn hideDivider(self: Self) Self {
            var result = self;
            result.show_divider = false;
            return result;
        }

        /// Get pane rects
        fn getPaneRects(self: *Self, bounds: Rect) struct { first: Rect, second: Rect, divider: ?Rect } {
            const divider_size: u16 = if (self.show_divider) 1 else 0;

            if (self.orientation == .horizontal) {
                // Vertical divider, horizontal split
                const total = bounds.width -| divider_size;
                var first_width = @as(u16, @intFromFloat(@as(f32, @floatFromInt(total)) * self.ratio));
                first_width = @max(first_width, self.min_size);
                first_width = @min(first_width, total -| self.min_size);

                const second_x = bounds.x + first_width + divider_size;
                const second_width = bounds.width -| first_width -| divider_size;

                return .{
                    .first = Rect.init(bounds.x, bounds.y, first_width, bounds.height),
                    .second = Rect.init(second_x, bounds.y, second_width, bounds.height),
                    .divider = if (self.show_divider)
                        Rect.init(bounds.x + first_width, bounds.y, 1, bounds.height)
                    else
                        null,
                };
            } else {
                // Horizontal divider, vertical split
                const total = bounds.height -| divider_size;
                var first_height = @as(u16, @intFromFloat(@as(f32, @floatFromInt(total)) * self.ratio));
                first_height = @max(first_height, self.min_size);
                first_height = @min(first_height, total -| self.min_size);

                const second_y = bounds.y + first_height + divider_size;
                const second_height = bounds.height -| first_height -| divider_size;

                return .{
                    .first = Rect.init(bounds.x, bounds.y, bounds.width, first_height),
                    .second = Rect.init(bounds.x, second_y, bounds.width, second_height),
                    .divider = if (self.show_divider)
                        Rect.init(bounds.x, bounds.y + first_height, bounds.width, 1)
                    else
                        null,
                };
            }
        }

        /// Render the split view
        pub fn render(self: *Self, ctx: *RenderContext) void {
            const panes = self.getPaneRects(ctx.bounds);

            // Render first pane
            if (@hasDecl(FirstType, "render")) {
                var first_ctx = ctx.child(panes.first);
                @constCast(&self.first).render(&first_ctx);
            }

            // Render divider
            if (panes.divider) |div_rect| {
                ctx.screen.setStyle(self.divider_style orelse ctx.theme.border);

                if (self.orientation == .horizontal) {
                    for (0..div_rect.height) |y| {
                        ctx.screen.putStringAt(div_rect.x, div_rect.y + @as(u16, @intCast(y)), self.divider_char);
                    }
                } else {
                    for (0..div_rect.width) |x| {
                        ctx.screen.putStringAt(div_rect.x + @as(u16, @intCast(x)), div_rect.y, self.horizontal_divider_char);
                    }
                }
            }

            // Render second pane
            if (@hasDecl(SecondType, "render")) {
                var second_ctx = ctx.child(panes.second);
                @constCast(&self.second).render(&second_ctx);
            }
        }

        /// Handle events
        pub fn handleEvent(self: *Self, event: Event) EventResult {
            if (self.base.state.disabled) return .ignored;

            switch (event) {
                .key => |key_event| {
                    // Switch panes with Tab
                    if (key_event.key == .tab and !key_event.modifiers.ctrl) {
                        self.focused_pane = if (self.focused_pane == 0) 1 else 0;
                        self.base.markDirty();
                        return .consumed;
                    }
                },
                .mouse => |mouse_event| {
                    const panes = self.getPaneRects(self.base.bounds);

                    // Check for divider drag
                    if (panes.divider) |div_rect| {
                        if (mouse_event.kind == .press and div_rect.contains(mouse_event.x, mouse_event.y)) {
                            self.dragging = true;
                            return .consumed;
                        }

                        if (mouse_event.kind == .release) {
                            self.dragging = false;
                        }

                        if (self.dragging and mouse_event.kind == .drag) {
                            self.updateRatioFromMouse(mouse_event.x, mouse_event.y);
                            return .consumed;
                        }
                    }

                    // Check which pane was clicked
                    if (mouse_event.kind == .press) {
                        if (panes.first.contains(mouse_event.x, mouse_event.y)) {
                            self.focused_pane = 0;
                        } else if (panes.second.contains(mouse_event.x, mouse_event.y)) {
                            self.focused_pane = 1;
                        }
                    }
                },
                else => {},
            }

            // Pass to focused pane
            if (self.focused_pane == 0) {
                if (@hasDecl(FirstType, "handleEvent")) {
                    return @constCast(&self.first).handleEvent(event);
                }
            } else {
                if (@hasDecl(SecondType, "handleEvent")) {
                    return @constCast(&self.second).handleEvent(event);
                }
            }

            return .ignored;
        }

        fn updateRatioFromMouse(self: *Self, x: u16, y: u16) void {
            const bounds = self.base.bounds;

            if (self.orientation == .horizontal) {
                const relative_x = x -| bounds.x;
                self.ratio = @as(f32, @floatFromInt(relative_x)) / @as(f32, @floatFromInt(bounds.width));
            } else {
                const relative_y = y -| bounds.y;
                self.ratio = @as(f32, @floatFromInt(relative_y)) / @as(f32, @floatFromInt(bounds.height));
            }

            self.ratio = std.math.clamp(self.ratio, 0.1, 0.9);
            self.base.markDirty();
        }

        /// Check if focusable
        pub fn isFocusable(self: *Self) bool {
            _ = self;
            return true;
        }

        /// Get size hint
        pub fn sizeHint(self: *Self) SizeHint {
            _ = self;
            return .{
                .expand_x = true,
                .expand_y = true,
            };
        }
    };
}

test "split view creation" {
    const DummyContent = struct {};
    const sv = SplitView(DummyContent, DummyContent).horizontal(DummyContent{}, DummyContent{});

    try std.testing.expect(sv.ratio == 0.5);
    try std.testing.expect(sv.orientation == .horizontal);
}

test "split view ratio" {
    const DummyContent = struct {};
    const sv = SplitView(DummyContent, DummyContent).horizontal(DummyContent{}, DummyContent{})
        .withRatio(0.3);

    try std.testing.expect(sv.ratio == 0.3);
}
