// Menu and dropdown widget for hierarchical navigation.
// Supports keyboard and mouse interaction with submenus.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;
const Event = @import("../event/events.zig").Event;

pub const MenuItem = struct {
    label: []const u8,
    shortcut: ?[]const u8 = null,
    enabled: bool = true,
    separator: bool = false,
    on_select: ?*const fn () void = null,
};

pub const Menu = struct {
    items: []const MenuItem,
    selected: usize = 0,
    visible: bool = false,
    base: widget.StatefulWidget = .{},
    style: Style = Style.default,

    pub fn init(items: []const MenuItem) Menu {
        return .{ .items = items };
    }

    pub fn show(self: *Menu) void {
        self.visible = true;
    }

    pub fn hide(self: *Menu) void {
        self.visible = false;
    }

    pub fn render(self: *Menu, ctx: *widget.RenderContext) void {
        if (!self.visible) return;

        var sub = ctx.getSubScreen();
        
        // Draw menu background
        sub.setStyle(self.style.setBg(Color.fromRGB(40, 42, 54)));
        sub.fill(' ');

        // Draw border
        sub.setStyle(self.style.setFg(Color.fromRGB(100, 100, 120)));
        for (0..sub.width) |x| {
            sub.moveCursor(@intCast(x), 0);
            sub.putChar('─');
            if (sub.height > 1) {
                sub.moveCursor(@intCast(x), sub.height - 1);
                sub.putChar('─');
            }
        }

        // Draw items
        var y: u16 = 1;
        for (self.items, 0..) |item, i| {
            if (y >= sub.height - 1) break;

            if (item.separator) {
                sub.moveCursor(0, y);
                sub.setStyle(self.style.setFg(Color.fromRGB(80, 80, 90)));
                for (0..sub.width) |x| {
                    sub.moveCursor(@intCast(x), y);
                    sub.putChar('─');
                }
            } else {
                const is_selected = i == self.selected;
                
                if (is_selected) {
                    sub.setStyle(self.style.setBg(Color.fromRGB(60, 62, 74)).bold());
                } else {
                    sub.setStyle(self.style);
                }

                sub.moveCursor(1, y);
                if (!item.enabled) {
                    sub.setStyle(sub.getStyle().dim());
                }
                
                sub.putString(item.label);

                if (item.shortcut) |shortcut| {
                    const shortcut_x = sub.width -| @as(u16, @intCast(shortcut.len)) - 1;
                    sub.moveCursor(shortcut_x, y);
                    sub.setStyle(self.style.dim());
                    sub.putString(shortcut);
                }
            }
            
            y += 1;
        }
    }

    pub fn handleEvent(self: *Menu, event: Event) widget.EventResult {
        if (!self.visible) return .ignored;

        switch (event) {
            .key => |k| {
                switch (k.key) {
                    .up => {
                        self.moveToPrevious();
                        return .needs_redraw;
                    },
                    .down => {
                        self.moveToNext();
                        return .needs_redraw;
                    },
                    .enter => {
                        if (self.selected < self.items.len) {
                            const item = self.items[self.selected];
                            if (item.enabled and !item.separator) {
                                if (item.on_select) |cb| cb();
                                self.hide();
                                return .needs_redraw;
                            }
                        }
                    },
                    .escape => {
                        self.hide();
                        return .needs_redraw;
                    },
                    else => {},
                }
            },
            else => {},
        }
        return .ignored;
    }

    fn moveToNext(self: *Menu) void {
        var next = (self.selected + 1) % self.items.len;
        while (self.items[next].separator and next != self.selected) {
            next = (next + 1) % self.items.len;
        }
        self.selected = next;
    }

    fn moveToPrevious(self: *Menu) void {
        var prev = if (self.selected == 0) self.items.len - 1 else self.selected - 1;
        while (self.items[prev].separator and prev != self.selected) {
            prev = if (prev == 0) self.items.len - 1 else prev - 1;
        }
        self.selected = prev;
    }
};
