// Breadcrumb navigation widget for hierarchical path display.
// Shows current location within a navigation hierarchy.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;
const Event = @import("../event/events.zig").Event;

pub const BreadcrumbItem = struct {
    label: []const u8,
    on_click: ?*const fn () void = null,
};

pub const Breadcrumb = struct {
    items: []const BreadcrumbItem,
    separator: []const u8 = " / ",
    selected: usize = 0,
    base: widget.StatefulWidget = .{},
    style: Style = Style.default,

    pub fn init(items: []const BreadcrumbItem) Breadcrumb {
        return .{ .items = items };
    }

    pub fn withSeparator(self: Breadcrumb, separator: []const u8) Breadcrumb {
        var result = self;
        result.separator = separator;
        return result;
    }

    pub fn render(self: *Breadcrumb, ctx: *widget.RenderContext) void {
        var sub = ctx.getSubScreen();
        var x: u16 = 0;

        for (self.items, 0..) |item, i| {
            if (x >= sub.width) break;

            const is_last = i == self.items.len - 1;
            const is_selected = i == self.selected;

            // Item
            sub.moveCursor(x, 0);
            if (is_last) {
                sub.setStyle(self.style.bold().setFg(Color.cyan));
            } else if (is_selected) {
                sub.setStyle(self.style.setFg(Color.yellow));
            } else {
                sub.setStyle(self.style.setFg(Color.fromRGB(150, 150, 170)));
            }
            sub.putString(item.label);
            x += @intCast(item.label.len);

            // Separator
            if (!is_last) {
                sub.setStyle(self.style.dim());
                sub.moveCursor(x, 0);
                sub.putString(self.separator);
                x += @intCast(self.separator.len);
            }
        }
    }

    pub fn handleEvent(self: *Breadcrumb, event: Event) widget.EventResult {
        if (event == .key) {
            switch (event.key.key) {
                .left => {
                    if (self.selected > 0) {
                        self.selected -= 1;
                        return .needs_redraw;
                    }
                },
                .right => {
                    if (self.selected + 1 < self.items.len) {
                        self.selected += 1;
                        return .needs_redraw;
                    }
                },
                .enter => {
                    if (self.selected < self.items.len) {
                        if (self.items[self.selected].on_click) |cb| {
                            cb();
                        }
                        return .needs_redraw;
                    }
                },
                else => {},
            }
        }
        return .ignored;
    }
};

test "Breadcrumb creation" {
    const items = [_]BreadcrumbItem{
        .{ .label = "Home" },
        .{ .label = "Products" },
    };
    const breadcrumb = Breadcrumb.init(&items);
    try std.testing.expectEqual(@as(usize, 2), breadcrumb.items.len);
    try std.testing.expectEqualStrings(" / ", breadcrumb.separator);
}

test "Breadcrumb with custom separator" {
    const items = [_]BreadcrumbItem{.{ .label = "A" }};
    const breadcrumb = Breadcrumb.init(&items).withSeparator(" > ");
    try std.testing.expectEqualStrings(" > ", breadcrumb.separator);
}
