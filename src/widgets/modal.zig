//! Modal and overlay widgets

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
pub const BorderStyle = style_mod.BorderStyle;

/// Modal dialog widget
pub fn Modal(comptime ContentType: type) type {
    return struct {
        /// Modal content
        content: ContentType,

        /// Modal title
        title: ?[]const u8 = null,

        /// Modal width (0 = auto)
        width: u16 = 0,

        /// Modal height (0 = auto)
        height: u16 = 0,

        /// Border style
        border: BorderStyle = .rounded,

        /// Background style (for overlay)
        overlay_style: ?Style = null,

        /// Modal background style
        background_style: ?Style = null,

        /// Title style
        title_style: ?Style = null,

        /// Close on Escape
        close_on_escape: bool = true,

        /// Close on outside click
        close_on_outside_click: bool = false,

        /// Close callback
        on_close: ?*const fn () void = null,

        /// Is visible
        visible: bool = true,

        /// Base widget state
        base: StatefulWidget = .{},

        const Self = @This();

        /// Create a modal
        pub fn init(content: ContentType) Self {
            return .{
                .content = content,
            };
        }

        /// Set title
        pub fn withTitle(self: Self, t: []const u8) Self {
            var result = self;
            result.title = t;
            return result;
        }

        /// Set size
        pub fn withSize(self: Self, w: u16, h: u16) Self {
            var result = self;
            result.width = w;
            result.height = h;
            return result;
        }

        /// Set border style
        pub fn withBorder(self: Self, b: BorderStyle) Self {
            var result = self;
            result.border = b;
            return result;
        }

        /// Set close callback
        pub fn onClose(self: Self, callback: *const fn () void) Self {
            var result = self;
            result.on_close = callback;
            return result;
        }

        /// Show the modal
        pub fn show(self: *Self) void {
            self.visible = true;
            self.base.markDirty();
        }

        /// Hide the modal
        pub fn hide(self: *Self) void {
            self.visible = false;
            self.base.markDirty();
            if (self.on_close) |callback| {
                callback();
            }
        }

        /// Toggle visibility
        pub fn toggle(self: *Self) void {
            if (self.visible) {
                self.hide();
            } else {
                self.show();
            }
        }

        /// Calculate modal rect centered in parent
        fn getModalRect(self: *Self, parent: Rect) Rect {
            // Determine size
            var modal_width = self.width;
            var modal_height = self.height;

            if (modal_width == 0) {
                // Auto width - use 80% of parent or content hint
                if (@hasDecl(ContentType, "sizeHint")) {
                    const hint = self.content.sizeHint();
                    modal_width = @max(hint.preferred_width + 4, hint.min_width + 4);
                } else {
                    modal_width = parent.width * 80 / 100;
                }
            }

            if (modal_height == 0) {
                // Auto height
                if (@hasDecl(ContentType, "sizeHint")) {
                    const hint = self.content.sizeHint();
                    modal_height = @max(hint.preferred_height + 4, hint.min_height + 4);
                } else {
                    modal_height = parent.height * 60 / 100;
                }
            }

            // Center in parent
            const x = parent.x + (parent.width -| modal_width) / 2;
            const y = parent.y + (parent.height -| modal_height) / 2;

            return Rect.init(x, y, modal_width, modal_height);
        }

        /// Render the modal
        pub fn render(self: *Self, ctx: *RenderContext) void {
            if (!self.visible) return;

            var sub = ctx.getSubScreen();
            const modal_rect = self.getModalRect(ctx.bounds);

            // Draw overlay
            sub.setStyle(self.overlay_style orelse ctx.theme.modal_overlay);
            sub.clear();

            // Draw modal background
            ctx.screen.setStyle(self.background_style orelse ctx.theme.text);
            ctx.screen.fill(
                modal_rect.x,
                modal_rect.y,
                modal_rect.width,
                modal_rect.height,
                ' ',
            );

            // Draw border
            ctx.screen.setStyle(ctx.theme.border);
            ctx.screen.drawBox(
                modal_rect.x,
                modal_rect.y,
                modal_rect.width,
                modal_rect.height,
                self.border,
            );

            // Draw title
            if (self.title) |t| {
                const title_x = modal_rect.x + (modal_rect.width -| @as(u16, @intCast(unicode.stringWidth(t)))) / 2;
                ctx.screen.setStyle(self.title_style orelse ctx.theme.title);
                ctx.screen.putStringAt(title_x, modal_rect.y, t);
            }

            // Render content
            if (@hasDecl(ContentType, "render")) {
                const content_rect = Rect.init(
                    modal_rect.x + 2,
                    modal_rect.y + 1,
                    modal_rect.width -| 4,
                    modal_rect.height -| 2,
                );
                var content_ctx = ctx.child(content_rect);
                self.content.render(&content_ctx);
            }
        }

        /// Handle events
        pub fn handleEvent(self: *Self, event: Event) EventResult {
            if (!self.visible) return .ignored;

            switch (event) {
                .key => |key_event| {
                    if (self.close_on_escape and key_event.key == .escape) {
                        self.hide();
                        return .consumed;
                    }
                },
                .mouse => |mouse_event| {
                    if (self.close_on_outside_click and mouse_event.kind == .press) {
                        const modal_rect = self.getModalRect(self.base.bounds);
                        if (!modal_rect.contains(mouse_event.x, mouse_event.y)) {
                            self.hide();
                            return .consumed;
                        }
                    }
                },
                else => {},
            }

            // Pass to content
            if (@hasDecl(ContentType, "handleEvent")) {
                return self.content.handleEvent(event);
            }

            return .ignored;
        }

        /// Check if focusable
        pub fn isFocusable(self: *Self) bool {
            return self.visible;
        }
    };
}

/// Simple overlay wrapper
pub fn Overlay(comptime ContentType: type) type {
    return struct {
        content: ContentType,
        visible: bool = false,
        base: StatefulWidget = .{},

        const Self = @This();

        pub fn init(content: ContentType) Self {
            return .{ .content = content };
        }

        pub fn show(self: *Self) void {
            self.visible = true;
            self.base.markDirty();
        }

        pub fn hide(self: *Self) void {
            self.visible = false;
            self.base.markDirty();
        }

        pub fn render(self: *Self, ctx: *RenderContext) void {
            if (!self.visible) return;

            if (@hasDecl(ContentType, "render")) {
                self.content.render(ctx);
            }
        }

        pub fn handleEvent(self: *Self, event: Event) EventResult {
            if (!self.visible) return .ignored;

            if (@hasDecl(ContentType, "handleEvent")) {
                return self.content.handleEvent(event);
            }
            return .ignored;
        }
    };
}

test "modal creation" {
    const DummyContent = struct {};
    var modal = Modal(DummyContent).init(DummyContent{});
    modal = modal.withTitle("Test Modal").withSize(40, 20);

    try std.testing.expectEqualStrings("Test Modal", modal.title.?);
    try std.testing.expectEqual(@as(u16, 40), modal.width);
    try std.testing.expectEqual(@as(u16, 20), modal.height);
}

test "modal visibility" {
    const DummyContent = struct {};
    var modal = Modal(DummyContent).init(DummyContent{});

    try std.testing.expect(modal.visible);

    modal.hide();
    try std.testing.expect(!modal.visible);

    modal.show();
    try std.testing.expect(modal.visible);
}
