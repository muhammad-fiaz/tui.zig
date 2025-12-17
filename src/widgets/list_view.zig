//! List view widget

const std = @import("std");
const widget = @import("widget.zig");
const layout = @import("../layout/layout.zig");
const style_mod = @import("../style/style.zig");
const events = @import("../event/events.zig");
const unicode = @import("../unicode/unicode.zig");

pub const RenderContext = widget.RenderContext;
pub const StatefulWidget = widget.StatefulWidget;
pub const SizeHint = widget.SizeHint;
pub const EventResult = widget.EventResult;
pub const Style = style_mod.Style;
pub const Event = events.Event;
pub const Rect = layout.Rect;

/// List view widget for displaying a scrollable list of items
pub fn ListView(comptime T: type) type {
    return struct {
        /// Items in the list
        items: []const T,

        /// Item renderer function
        render_item: *const fn (item: T, index: usize, selected: bool, buf: []u8) []const u8,

        /// Selected index
        selected: usize = 0,

        /// Scroll offset
        scroll_offset: usize = 0,

        /// Selection callback
        on_select: ?*const fn (item: T, index: usize) void = null,

        /// Activate callback (e.g., Enter pressed)
        on_activate: ?*const fn (item: T, index: usize) void = null,

        /// Show selection indicator
        show_indicator: bool = true,

        /// Selection indicator
        indicator: []const u8 = "▶ ",

        /// No indicator spacing
        no_indicator: []const u8 = "  ",

        /// Style
        style: Style = .{},

        /// Selected style
        selected_style: ?Style = null,

        /// Base widget state
        base: StatefulWidget = .{},

        const Self = @This();

        /// Create a list view
        pub fn init(
            items: []const T,
            render_item: *const fn (T, usize, bool, []u8) []const u8,
        ) Self {
            return .{
                .items = items,
                .render_item = render_item,
            };
        }

        /// Set selection callback
        pub fn onSelect(self: Self, callback: *const fn (T, usize) void) Self {
            var result = self;
            result.on_select = callback;
            return result;
        }

        /// Set activation callback
        pub fn onActivate(self: Self, callback: *const fn (T, usize) void) Self {
            var result = self;
            result.on_activate = callback;
            return result;
        }

        /// Select an item by index
        pub fn selectIndex(self: *Self, index: usize) void {
            if (index >= self.items.len) return;

            self.selected = index;
            self.ensureVisible();
            self.base.markDirty();

            if (self.on_select) |callback| {
                callback(self.items[index], index);
            }
        }

        /// Select next item
        pub fn selectNext(self: *Self) void {
            if (self.selected + 1 < self.items.len) {
                self.selectIndex(self.selected + 1);
            }
        }

        /// Select previous item
        pub fn selectPrevious(self: *Self) void {
            if (self.selected > 0) {
                self.selectIndex(self.selected - 1);
            }
        }

        /// Ensure selected item is visible
        fn ensureVisible(self: *Self) void {
            const visible_count = self.getVisibleCount();

            if (self.selected < self.scroll_offset) {
                self.scroll_offset = self.selected;
            } else if (self.selected >= self.scroll_offset + visible_count) {
                self.scroll_offset = self.selected - visible_count + 1;
            }
        }

        fn getVisibleCount(self: *Self) usize {
            return @min(self.items.len, self.base.bounds.height);
        }

        /// Render the list view
        pub fn render(self: *Self, ctx: *RenderContext) void {
            var sub = ctx.getSubScreen();

            const visible_count = @min(self.items.len - self.scroll_offset, sub.height);
            var render_buf: [256]u8 = undefined;

            for (0..visible_count) |i| {
                const idx = self.scroll_offset + i;
                const is_selected = idx == self.selected;

                sub.moveCursor(0, @intCast(i));

                // Set style
                if (is_selected) {
                    sub.setStyle(self.selected_style orelse ctx.theme.list_item_selected);
                } else {
                    sub.setStyle(self.style.merge(ctx.theme.list_item));
                }

                // Draw indicator
                if (self.show_indicator) {
                    sub.putString(if (is_selected) self.indicator else self.no_indicator);
                }

                // Render item
                const item_text = self.render_item(self.items[idx], idx, is_selected, &render_buf);
                sub.putString(item_text);

                // Fill rest of line
                const used_width = unicode.stringWidth(item_text) + (if (self.show_indicator) 2 else 0);
                for (used_width..sub.width) |_| {
                    sub.putString(" ");
                }
            }
        }

        /// Handle events
        pub fn handleEvent(self: *Self, event: Event) EventResult {
            if (self.base.state.disabled or self.items.len == 0) return .ignored;

            switch (event) {
                .key => |key_event| {
                    switch (key_event.key) {
                        .up => {
                            self.selectPrevious();
                            return .consumed;
                        },
                        .down => {
                            self.selectNext();
                            return .consumed;
                        },
                        .home => {
                            self.selectIndex(0);
                            return .consumed;
                        },
                        .end => {
                            self.selectIndex(self.items.len - 1);
                            return .consumed;
                        },
                        .page_up => {
                            const jump = self.getVisibleCount();
                            self.selectIndex(if (self.selected >= jump) self.selected - jump else 0);
                            return .consumed;
                        },
                        .page_down => {
                            const jump = self.getVisibleCount();
                            const new_idx = @min(self.selected + jump, self.items.len - 1);
                            self.selectIndex(new_idx);
                            return .consumed;
                        },
                        .enter => {
                            if (self.on_activate) |callback| {
                                callback(self.items[self.selected], self.selected);
                            }
                            return .consumed;
                        },
                        else => {},
                    }
                },
                .mouse => |mouse_event| {
                    if (mouse_event.kind == .press and mouse_event.button == .left) {
                        const clicked_idx = self.scroll_offset + mouse_event.y;
                        if (clicked_idx < self.items.len) {
                            self.selectIndex(clicked_idx);
                            return .consumed;
                        }
                    }
                },
                else => {},
            }

            return .ignored;
        }

        /// Check if focusable
        pub fn isFocusable(self: *Self) bool {
            return !self.base.state.disabled and self.items.len > 0;
        }

        /// Set focus
        pub fn setFocus(self: *Self, focused: bool) void {
            self.base.state.focused = focused;
            self.base.markDirty();
        }

        /// Get size hint
        pub fn sizeHint(self: *Self) SizeHint {
            return .{
                .min_width = 10,
                .preferred_width = 40,
                .min_height = @intCast(@min(self.items.len, 10)),
                .preferred_height = @intCast(self.items.len),
                .expand_y = true,
            };
        }
    };
}

/// Simple string list view
pub const StringListView = ListView([]const u8);

/// Create a simple string list
pub fn stringList(items: []const []const u8) StringListView {
    return StringListView.init(items, struct {
        fn render(item: []const u8, _: usize, _: bool, buf: []u8) []const u8 {
            _ = buf;
            return item;
        }
    }.render);
}

test "list view creation" {
    const items = [_][]const u8{ "Item 1", "Item 2", "Item 3" };
    const list = stringList(&items);

    try std.testing.expectEqual(@as(usize, 0), list.selected);
    try std.testing.expectEqual(@as(usize, 3), list.items.len);
}

test "list view navigation" {
    const items = [_][]const u8{ "Item 1", "Item 2", "Item 3" };
    var list = stringList(&items);
    list.base.bounds = Rect.init(0, 0, 40, 10);

    list.selectNext();
    try std.testing.expectEqual(@as(usize, 1), list.selected);

    list.selectNext();
    try std.testing.expectEqual(@as(usize, 2), list.selected);

    list.selectNext(); // Should stay at 2
    try std.testing.expectEqual(@as(usize, 2), list.selected);

    list.selectPrevious();
    try std.testing.expectEqual(@as(usize, 1), list.selected);
}
