//! Tabs widget

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

/// Tab definition
pub const Tab = struct {
    /// Tab label
    label: []const u8,

    /// Optional icon
    icon: ?[]const u8 = null,

    /// Closeable
    closeable: bool = false,
};

/// Tabs widget
pub fn Tabs(comptime ContentType: type) type {
    return struct {
        /// Tab definitions
        tabs: []const Tab,

        /// Tab content (indexed by tab index)
        content: []const ContentType,

        /// Active tab index
        active: usize = 0,

        /// Tab position
        position: TabPosition = .top,

        /// Tab change callback
        on_change: ?*const fn (usize) void = null,

        /// Tab close callback
        on_close: ?*const fn (usize) void = null,

        /// Tab style
        tab_style: ?Style = null,
        active_tab_style: ?Style = null,

        /// Tab bar height (for top/bottom)
        tab_bar_height: u16 = 1,

        /// Separator between tabs
        separator: []const u8 = " │ ",

        /// Base widget state
        base: StatefulWidget = .{},

        const Self = @This();

        /// Tab position
        pub const TabPosition = enum {
            top,
            bottom,
            left,
            right,
        };

        /// Create tabs
        pub fn init(tabs: []const Tab, content: []const ContentType) Self {
            return .{
                .tabs = tabs,
                .content = content,
            };
        }

        /// Set active tab
        pub fn setActive(self: *Self, index: usize) void {
            if (index >= self.tabs.len) return;

            if (self.active != index) {
                self.active = index;
                self.base.markDirty();
                if (self.on_change) |callback| {
                    callback(index);
                }
            }
        }

        /// Select next tab
        pub fn nextTab(self: *Self) void {
            if (self.active + 1 < self.tabs.len) {
                self.setActive(self.active + 1);
            } else {
                self.setActive(0); // Wrap around
            }
        }

        /// Select previous tab
        pub fn previousTab(self: *Self) void {
            if (self.active > 0) {
                self.setActive(self.active - 1);
            } else {
                self.setActive(self.tabs.len - 1); // Wrap around
            }
        }

        /// Get the active content
        pub fn getActiveContent(self: *Self) ?*ContentType {
            if (self.active < self.content.len) {
                return @constCast(&self.content[self.active]);
            }
            return null;
        }

        /// Render the tabs
        pub fn render(self: *Self, ctx: *RenderContext) void {
            switch (self.position) {
                .top => self.renderTopTabs(ctx),
                .bottom => self.renderBottomTabs(ctx),
                else => self.renderTopTabs(ctx), // TODO: Implement left/right
            }
        }

        fn renderTopTabs(self: *Self, ctx: *RenderContext) void {
            var sub = ctx.getSubScreen();

            // Draw tab bar
            sub.moveCursor(0, 0);
            var x: u16 = 0;

            for (self.tabs, 0..) |tab, i| {
                const is_active = i == self.active;

                sub.setStyle(if (is_active)
                    self.active_tab_style orelse ctx.theme.tab_active
                else
                    self.tab_style orelse ctx.theme.tab_inactive);

                // Draw icon if present
                if (tab.icon) |icon| {
                    sub.putString(icon);
                    sub.putString(" ");
                    x += @intCast(unicode.stringWidth(icon) + 1);
                }

                // Draw label
                sub.putString(tab.label);
                x += @intCast(unicode.stringWidth(tab.label));

                // Draw close button if closeable
                if (tab.closeable) {
                    sub.putString(" ×");
                    x += 2;
                }

                // Draw separator
                if (i + 1 < self.tabs.len) {
                    sub.setStyle(ctx.theme.text);
                    sub.putString(self.separator);
                    x += @intCast(unicode.stringWidth(self.separator));
                }
            }

            // Draw content area separator
            if (sub.height > 1) {
                sub.setStyle(ctx.theme.border);
                sub.moveCursor(0, 1);
                for (0..sub.width) |_| {
                    sub.putString("─");
                }
            }

            // Render active content
            if (sub.height > 2 and self.active < self.content.len) {
                const content_rect = Rect.init(
                    ctx.bounds.x,
                    ctx.bounds.y + 2,
                    ctx.bounds.width,
                    ctx.bounds.height -| 2,
                );
                var content_ctx = ctx.child(content_rect);

                if (@hasDecl(ContentType, "render")) {
                    @constCast(&self.content[self.active]).render(&content_ctx);
                }
            }
        }

        fn renderBottomTabs(self: *Self, ctx: *RenderContext) void {
            var sub = ctx.getSubScreen();
            const tab_bar_y = sub.height -| 1;

            // Render content first
            if (sub.height > 2 and self.active < self.content.len) {
                const content_rect = Rect.init(
                    ctx.bounds.x,
                    ctx.bounds.y,
                    ctx.bounds.width,
                    ctx.bounds.height -| 2,
                );
                var content_ctx = ctx.child(content_rect);

                if (@hasDecl(ContentType, "render")) {
                    @constCast(&self.content[self.active]).render(&content_ctx);
                }
            }

            // Draw separator
            if (sub.height > 1) {
                sub.setStyle(ctx.theme.border);
                sub.moveCursor(0, tab_bar_y -| 1);
                for (0..sub.width) |_| {
                    sub.putString("─");
                }
            }

            // Draw tab bar
            sub.moveCursor(0, tab_bar_y);

            for (self.tabs, 0..) |tab, i| {
                const is_active = i == self.active;

                sub.setStyle(if (is_active)
                    self.active_tab_style orelse ctx.theme.tab_active
                else
                    self.tab_style orelse ctx.theme.tab_inactive);

                sub.putString(tab.label);

                if (i + 1 < self.tabs.len) {
                    sub.setStyle(ctx.theme.text);
                    sub.putString(self.separator);
                }
            }
        }

        /// Handle events
        pub fn handleEvent(self: *Self, event: Event) EventResult {
            if (self.base.state.disabled or self.tabs.len == 0) return .ignored;

            switch (event) {
                .key => |key_event| {
                    // Ctrl+Tab for next tab, Ctrl+Shift+Tab for previous
                    if (key_event.key == .tab and key_event.modifiers.ctrl) {
                        if (key_event.modifiers.shift) {
                            self.previousTab();
                        } else {
                            self.nextTab();
                        }
                        return .consumed;
                    }

                    // Number keys for direct tab selection
                    if (key_event.key == .char) {
                        const c = key_event.key.char;
                        if (c >= '1' and c <= '9') {
                            const tab_idx = c - '1';
                            if (tab_idx < self.tabs.len) {
                                self.setActive(tab_idx);
                                return .consumed;
                            }
                        }
                    }
                },
                .mouse => |mouse_event| {
                    if (mouse_event.kind == .press and mouse_event.button == .left) {
                        // Check if in tab bar
                        if (self.position == .top and mouse_event.y == 0) {
                            // TODO: Determine which tab was clicked
                            return .consumed;
                        }
                    }
                },
                else => {},
            }

            // Pass to active content
            if (self.active < self.content.len) {
                if (@hasDecl(ContentType, "handleEvent")) {
                    return @constCast(&self.content[self.active]).handleEvent(event);
                }
            }

            return .ignored;
        }

        /// Check if focusable
        pub fn isFocusable(self: *Self) bool {
            return !self.base.state.disabled and self.tabs.len > 0;
        }

        /// Get size hint
        pub fn sizeHint(self: *Self) SizeHint {
            // Calculate tab bar width
            var tab_width: u16 = 0;
            for (self.tabs) |tab| {
                tab_width += @intCast(unicode.stringWidth(tab.label));
                tab_width += @intCast(unicode.stringWidth(self.separator));
            }

            return .{
                .min_width = tab_width,
                .preferred_width = @max(tab_width, 40),
                .min_height = 3,
                .preferred_height = 10,
                .expand_x = true,
                .expand_y = true,
            };
        }
    };
}

test "tabs creation" {
    const DummyContent = struct {};
    const tabs = [_]Tab{
        .{ .label = "Tab 1" },
        .{ .label = "Tab 2" },
        .{ .label = "Tab 3" },
    };
    const content = [_]DummyContent{ DummyContent{}, DummyContent{}, DummyContent{} };

    const tabs_widget = Tabs(DummyContent).init(&tabs, &content);

    try std.testing.expectEqual(@as(usize, 0), tabs_widget.active);
    try std.testing.expectEqual(@as(usize, 3), tabs_widget.tabs.len);
}

test "tabs navigation" {
    const DummyContent = struct {};
    const tabs = [_]Tab{
        .{ .label = "Tab 1" },
        .{ .label = "Tab 2" },
        .{ .label = "Tab 3" },
    };
    const content = [_]DummyContent{ DummyContent{}, DummyContent{}, DummyContent{} };

    var tabs_widget = Tabs(DummyContent).init(&tabs, &content);

    tabs_widget.nextTab();
    try std.testing.expectEqual(@as(usize, 1), tabs_widget.active);

    tabs_widget.nextTab();
    try std.testing.expectEqual(@as(usize, 2), tabs_widget.active);

    tabs_widget.nextTab(); // Wraps
    try std.testing.expectEqual(@as(usize, 0), tabs_widget.active);

    tabs_widget.previousTab(); // Wraps backward
    try std.testing.expectEqual(@as(usize, 2), tabs_widget.active);
}
