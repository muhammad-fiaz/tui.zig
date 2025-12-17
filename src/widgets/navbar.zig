// Navigation bar widget for top-level application navigation.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;
const Event = @import("../event/events.zig").Event;

pub const NavItem = struct {
    label: []const u8,
    icon: ?[]const u8 = null,
    on_click: ?*const fn () void = null,
};

pub const Navbar = struct {
    items: []const NavItem,
    selected: usize = 0,
    title: ?[]const u8 = null,
    base: widget.StatefulWidget = .{},
    style: Style = Style.default,

    pub fn init(items: []const NavItem) Navbar {
        return .{ .items = items };
    }

    pub fn withTitle(self: Navbar, title: []const u8) Navbar {
        var result = self;
        result.title = title;
        return result;
    }

    pub fn render(self: *Navbar, ctx: *widget.RenderContext) void {
        var sub = ctx.getSubScreen();
        
        sub.setStyle(self.style.setBg(Color.fromRGB(40, 42, 54)));
        for (0..sub.width) |x| {
            sub.moveCursor(@intCast(x), 0);
            sub.putChar(' ');
        }

        var x: u16 = 2;
        if (self.title) |title| {
            sub.setStyle(self.style.setBg(Color.fromRGB(40, 42, 54)).setFg(Color.cyan).bold());
            sub.moveCursor(x, 0);
            sub.putString(title);
            x += @as(u16, @intCast(title.len)) + 4;
        }

        for (self.items, 0..) |item, i| {
            if (x >= sub.width) break;
            
            sub.moveCursor(x, 0);
            if (i == self.selected) {
                sub.setStyle(self.style.setBg(Color.cyan).setFg(Color.black).bold());
            } else {
                sub.setStyle(self.style.setBg(Color.fromRGB(40, 42, 54)).setFg(Color.white));
            }
            
            sub.putString(" ");
            if (item.icon) |icon| {
                sub.putString(icon);
                sub.putString(" ");
            }
            sub.putString(item.label);
            sub.putString(" ");
            
            x += @as(u16, @intCast(item.label.len)) + (if (item.icon != null) 4 else 2);
        }
    }

    pub fn handleEvent(self: *Navbar, event: Event) widget.EventResult {
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

test "Navbar creation" {
    const items = [_]NavItem{.{ .label = "Home" }};
    const navbar = Navbar.init(&items);
    try std.testing.expectEqual(@as(usize, 1), navbar.items.len);
}
