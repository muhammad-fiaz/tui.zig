//! Scroll view widget

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

/// Scroll view wrapper for scrollable content
pub fn ScrollView(comptime ContentType: type) type {
    return struct {
        /// The content to scroll
        content: ContentType,

        /// Content size
        content_width: u16 = 0,
        content_height: u16 = 0,

        /// Scroll offset
        scroll_x: u16 = 0,
        scroll_y: u16 = 0,

        /// Show scrollbars
        show_vertical_scrollbar: bool = true,
        show_horizontal_scrollbar: bool = false,

        /// Scrollbar style
        scrollbar_track: []const u8 = "│",
        scrollbar_thumb: []const u8 = "█",

        /// Scrollbar style
        scrollbar_style: ?Style = null,

        /// Base widget state
        base: StatefulWidget = .{},

        const Self = @This();

        /// Create a scroll view
        pub fn init(content: ContentType) Self {
            return .{
                .content = content,
            };
        }

        /// Set content size
        pub fn withContentSize(self: Self, width: u16, height: u16) Self {
            var result = self;
            result.content_width = width;
            result.content_height = height;
            return result;
        }

        /// Enable horizontal scrollbar
        pub fn withHorizontalScrollbar(self: Self) Self {
            var result = self;
            result.show_horizontal_scrollbar = true;
            return result;
        }

        /// Hide vertical scrollbar
        pub fn hideVerticalScrollbar(self: Self) Self {
            var result = self;
            result.show_vertical_scrollbar = false;
            return result;
        }

        /// Scroll by amount
        pub fn scrollBy(self: *Self, dx: i16, dy: i16) void {
            const max_x = self.content_width -| self.getViewportWidth();
            const max_y = self.content_height -| self.getViewportHeight();

            if (dx > 0) {
                self.scroll_x = @min(self.scroll_x + @as(u16, @intCast(dx)), max_x);
            } else if (dx < 0) {
                self.scroll_x = self.scroll_x -| @as(u16, @intCast(-dx));
            }

            if (dy > 0) {
                self.scroll_y = @min(self.scroll_y + @as(u16, @intCast(dy)), max_y);
            } else if (dy < 0) {
                self.scroll_y = self.scroll_y -| @as(u16, @intCast(-dy));
            }

            self.base.markDirty();
        }

        /// Scroll to position
        pub fn scrollTo(self: *Self, x: u16, y: u16) void {
            const max_x = self.content_width -| self.getViewportWidth();
            const max_y = self.content_height -| self.getViewportHeight();

            self.scroll_x = @min(x, max_x);
            self.scroll_y = @min(y, max_y);
            self.base.markDirty();
        }

        /// Scroll to top
        pub fn scrollToTop(self: *Self) void {
            self.scroll_y = 0;
            self.base.markDirty();
        }

        /// Scroll to bottom
        pub fn scrollToBottom(self: *Self) void {
            self.scroll_y = self.content_height -| self.getViewportHeight();
            self.base.markDirty();
        }

        /// Get viewport dimensions
        pub fn getViewportWidth(self: *Self) u16 {
            return self.base.bounds.width -| (if (self.show_vertical_scrollbar) 1 else 0);
        }

        pub fn getViewportHeight(self: *Self) u16 {
            return self.base.bounds.height -| (if (self.show_horizontal_scrollbar) 1 else 0);
        }

        /// Render the scroll view
        pub fn render(self: *Self, ctx: *RenderContext) void {
            const viewport_width = self.getViewportWidth();
            const viewport_height = self.getViewportHeight();

            // Render content in viewport area
            const content_rect = Rect.init(
                ctx.bounds.x,
                ctx.bounds.y,
                viewport_width,
                viewport_height,
            );
            var content_ctx = ctx.child(content_rect);

            // TODO: Set scroll offset in context for content rendering
            if (@hasDecl(ContentType, "render")) {
                self.content.render(&content_ctx);
            }

            // Render vertical scrollbar
            if (self.show_vertical_scrollbar and self.content_height > viewport_height) {
                self.renderVerticalScrollbar(ctx, viewport_width, viewport_height);
            }

            // Render horizontal scrollbar
            if (self.show_horizontal_scrollbar and self.content_width > viewport_width) {
                self.renderHorizontalScrollbar(ctx, viewport_width, viewport_height);
            }
        }

        fn renderVerticalScrollbar(self: *Self, ctx: *RenderContext, x_offset: u16, height: u16) void {
            var sub = ctx.getSubScreen();
            sub.setStyle(self.scrollbar_style orelse ctx.theme.scrollbar_track);

            const bar_x = x_offset;

            // Draw track
            for (0..height) |y| {
                sub.moveCursor(bar_x, @intCast(y));
                sub.putString(self.scrollbar_track);
            }

            // Calculate thumb position and size
            const thumb_size = @max(1, @as(u16, @intCast((@as(u32, height) * height) / self.content_height)));
            const scrollable = self.content_height - height;
            const thumb_pos = if (scrollable > 0)
                @as(u16, @intCast((@as(u32, self.scroll_y) * (height - thumb_size)) / scrollable))
            else
                0;

            // Draw thumb
            sub.setStyle(self.scrollbar_style orelse ctx.theme.scrollbar_thumb);
            for (0..thumb_size) |i| {
                const y = thumb_pos + @as(u16, @intCast(i));
                if (y < height) {
                    sub.moveCursor(bar_x, y);
                    sub.putString(self.scrollbar_thumb);
                }
            }
        }

        fn renderHorizontalScrollbar(self: *Self, ctx: *RenderContext, width: u16, y_offset: u16) void {
            var sub = ctx.getSubScreen();
            sub.setStyle(self.scrollbar_style orelse ctx.theme.scrollbar_track);

            // Draw track
            sub.moveCursor(0, y_offset);
            for (0..width) |_| {
                sub.putString("─");
            }

            // Calculate thumb position and size
            const thumb_size = @max(1, @as(u16, @intCast((@as(u32, width) * width) / self.content_width)));
            const scrollable = self.content_width - width;
            const thumb_pos = if (scrollable > 0)
                @as(u16, @intCast((@as(u32, self.scroll_x) * (width - thumb_size)) / scrollable))
            else
                0;

            // Draw thumb
            sub.setStyle(self.scrollbar_style orelse ctx.theme.scrollbar_thumb);
            sub.moveCursor(thumb_pos, y_offset);
            for (0..thumb_size) |_| {
                sub.putString("█");
            }
        }

        /// Handle events
        pub fn handleEvent(self: *Self, event: Event) EventResult {
            if (self.base.state.disabled) return .ignored;

            switch (event) {
                .key => |key_event| {
                    switch (key_event.key) {
                        .up => {
                            self.scrollBy(0, -1);
                            return .consumed;
                        },
                        .down => {
                            self.scrollBy(0, 1);
                            return .consumed;
                        },
                        .left => {
                            self.scrollBy(-1, 0);
                            return .consumed;
                        },
                        .right => {
                            self.scrollBy(1, 0);
                            return .consumed;
                        },
                        .page_up => {
                            self.scrollBy(0, -@as(i16, @intCast(self.getViewportHeight())));
                            return .consumed;
                        },
                        .page_down => {
                            self.scrollBy(0, @intCast(self.getViewportHeight()));
                            return .consumed;
                        },
                        .home => {
                            self.scrollToTop();
                            return .consumed;
                        },
                        .end => {
                            self.scrollToBottom();
                            return .consumed;
                        },
                        else => {},
                    }
                },
                .mouse => |mouse_event| {
                    switch (mouse_event.kind) {
                        .scroll_up => {
                            self.scrollBy(0, -3);
                            return .consumed;
                        },
                        .scroll_down => {
                            self.scrollBy(0, 3);
                            return .consumed;
                        },
                        else => {},
                    }
                },
                else => {},
            }

            // Pass to content if not consumed
            if (@hasDecl(ContentType, "handleEvent")) {
                return self.content.handleEvent(event);
            }

            return .ignored;
        }

        /// Check if focusable
        pub fn isFocusable(self: *Self) bool {
            _ = self;
            return true;
        }

        /// Get size hint
        pub fn sizeHint(self: *Self) SizeHint {
            if (@hasDecl(ContentType, "sizeHint")) {
                return self.content.sizeHint();
            }
            return .{
                .expand_x = true,
                .expand_y = true,
            };
        }
    };
}

/// Scrollbar-only widget for use in custom layouts
pub const Scrollbar = struct {
    /// Orientation
    vertical: bool = true,

    /// Total content size
    content_size: u16 = 100,

    /// Viewport size
    viewport_size: u16 = 10,

    /// Current position
    position: u16 = 0,

    /// Track character
    track_char: []const u8 = "│",

    /// Thumb character
    thumb_char: []const u8 = "█",

    /// Style
    style: ?Style = null,
    thumb_style: ?Style = null,

    /// Base widget state
    base: StatefulWidget = .{},

    pub fn init() Scrollbar {
        return .{};
    }

    pub fn horizontal() Scrollbar {
        return .{ .vertical = false, .track_char = "─" };
    }

    pub fn setRange(self: *Scrollbar, content: u16, viewport: u16) void {
        self.content_size = content;
        self.viewport_size = viewport;
        self.position = @min(self.position, content -| viewport);
    }

    pub fn setPosition(self: *Scrollbar, pos: u16) void {
        self.position = @min(pos, self.content_size -| self.viewport_size);
    }

    pub fn render(self: *Scrollbar, ctx: *RenderContext) void {
        var sub = ctx.getSubScreen();
        const size = if (self.vertical) sub.height else sub.width;

        // Draw track
        sub.setStyle(self.style orelse ctx.theme.scrollbar_track);
        if (self.vertical) {
            for (0..size) |y| {
                sub.moveCursor(0, @intCast(y));
                sub.putString(self.track_char);
            }
        } else {
            sub.moveCursor(0, 0);
            for (0..size) |_| {
                sub.putString(self.track_char);
            }
        }

        // Draw thumb
        if (self.content_size > self.viewport_size) {
            const thumb_size = @max(1, @as(u16, @intCast((@as(u32, size) * self.viewport_size) / self.content_size)));
            const scrollable = self.content_size - self.viewport_size;
            const thumb_pos = @as(u16, @intCast((@as(u32, self.position) * (size - thumb_size)) / scrollable));

            sub.setStyle(self.thumb_style orelse ctx.theme.scrollbar_thumb);

            for (0..thumb_size) |i| {
                const pos = thumb_pos + @as(u16, @intCast(i));
                if (pos < size) {
                    if (self.vertical) {
                        sub.moveCursor(0, pos);
                    } else {
                        sub.moveCursor(pos, 0);
                    }
                    sub.putString(self.thumb_char);
                }
            }
        }
    }
};

test "scroll view" {
    const DummyContent = struct {
        pub fn render(_: *@This(), _: *RenderContext) void {}
    };

    var sv = ScrollView(DummyContent).init(DummyContent{});
    sv = sv.withContentSize(100, 200);

    try std.testing.expectEqual(@as(u16, 100), sv.content_width);
    try std.testing.expectEqual(@as(u16, 200), sv.content_height);
}

test "scrollbar" {
    var sb = Scrollbar.init();
    sb.setRange(100, 20);
    sb.setPosition(50);

    try std.testing.expectEqual(@as(u16, 50), sb.position);
}
