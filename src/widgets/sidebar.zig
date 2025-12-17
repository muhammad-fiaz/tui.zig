// Sidebar widget for side navigation panels.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;
const Event = @import("../event/events.zig").Event;

pub const SidebarPosition = enum { left, right };

pub const SidebarItem = struct {
    label: []const u8,
    icon: ?[]const u8 = null,
    on_click: ?*const fn () void = null,
};

pub const Sidebar = struct {
    items: []const SidebarItem,
    selected: usize = 0,
    position: SidebarPosition = .left,
    width: u16 = 20,
    collapsed: bool = false,
    base: widget.StatefulWidget = .{},
    style: Style = Style.default,

    pub fn init(items: []const SidebarItem) Sidebar {
        return .{ .items = items };
    }

    pub fn withPosition(self: Sidebar, position: SidebarPosition) Sidebar {
        var result = self;
        result.position = position;
        return result;
    }

    pub fn withWidth(self: Sidebar, width: u16) Sidebar {
        var result = self;
        result.width = width;
        return result;
    }

    pub fn toggle(self: *Sidebar) void {
        self.collapsed = !self.collapsed;
    }

    pub fn render(self: *Sidebar, ctx: *widget.RenderContext) void {
        var sub = ctx.getSubScreen();
        const display_width = if (self.collapsed) 3 else self.width;

        sub.setStyle(self.style.setBg(Color.fromRGB(30, 32, 40)));
        for (0..sub.height) |y| {
            for (0..display_width) |x| {
                sub.moveCursor(@intCast(x), @intCast(y));
                sub.putChar(' ');
            }
        }

        if (self.collapsed) {
            for (self.items, 0..) |item, i| {
                if (i >= sub.height) break;
                sub.moveCursor(1, @intCast(i * 2));
                if (item.icon) |icon| {
                    if (i == self.selected) {
                        sub.setStyle(self.style.setBg(Color.cyan).setFg(Color.black));
                    } else {
                        sub.setStyle(self.style.setBg(Color.fromRGB(30, 32, 40)).setFg(Color.white));
                    }
                    sub.putString(icon);
                }
            }
        } else {
            for (self.items, 0..) |item, i| {
                const y = @as(u16, @intCast(i * 2 + 1));
                if (y >= sub.height) break;

                sub.moveCursor(2, y);
                if (i == self.selected) {
                    sub.setStyle(self.style.setBg(Color.cyan).setFg(Color.black).bold());
                } else {
                    sub.setStyle(self.style.setBg(Color.fromRGB(30, 32, 40)).setFg(Color.white));
                }

                if (item.icon) |icon| {
                    sub.putString(icon);
                    sub.putString(" ");
                }
                sub.putString(item.label);
            }
        }
    }

    pub fn handleEvent(self: *Sidebar, event: Event) widget.EventResult {
        if (event == .key) {
            switch (event.key.key) {
                .up => {
                    if (self.selected > 0) {
                        self.selected -= 1;
                        return .needs_redraw;
                    }
                },
                .down => {
                    if (self.selected + 1 < self.items.len) {
                        self.selected += 1;
                        return .needs_redraw;
                    }
                },
                .enter => {
                    if (self.selected < self.items.len) {
                        if (self.items[self.selected].on_click) |cb| cb();
                    }
                    return .needs_redraw;
                },
                else => {},
            }
        }
        return .ignored;
    }
};

test "Sidebar creation" {
    const items = [_]SidebarItem{.{ .label = "Dashboard" }};
    const sidebar = Sidebar.init(&items);
    try std.testing.expectEqual(@as(u16, 20), sidebar.width);
}
