// Accordion widget for collapsible content sections.
// Supports single or multiple expanded panels simultaneously.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;
const Event = @import("../event/events.zig").Event;

pub const AccordionItem = struct {
    title: []const u8,
    content: []const u8,
    expanded: bool = false,
    enabled: bool = true,
};

pub const AccordionMode = enum {
    single,
    multiple,
};

pub const Accordion = struct {
    items: []AccordionItem,
    mode: AccordionMode = .single,
    selected: usize = 0,
    base: widget.StatefulWidget = .{},
    style: Style = Style.default,
    on_change: ?*const fn (usize, bool) void = null,

    pub fn init(items: []AccordionItem) Accordion {
        return .{ .items = items };
    }

    pub fn withMode(self: Accordion, mode: AccordionMode) Accordion {
        var result = self;
        result.mode = mode;
        return result;
    }

    pub fn withOnChange(self: Accordion, callback: *const fn (usize, bool) void) Accordion {
        var result = self;
        result.on_change = callback;
        return result;
    }

    pub fn render(self: *Accordion, ctx: *widget.RenderContext) void {
        var sub = ctx.getSubScreen();
        var y: u16 = 0;

        for (self.items, 0..) |*item, i| {
            if (y >= sub.height) break;

            const is_selected = i == self.selected;
            
            sub.moveCursor(0, y);
            if (is_selected) {
                sub.setStyle(self.style.bold().setFg(Color.cyan));
            } else {
                sub.setStyle(self.style.setFg(Color.fromRGB(150, 150, 170)));
            }

            const icon = if (item.expanded) "▼" else "▶";
            sub.putString(icon);
            sub.putString(" ");
            sub.putString(item.title);
            y += 1;

            if (item.expanded) {
                sub.setStyle(self.style.setFg(Color.fromRGB(200, 200, 220)));
                var lines = std.mem.splitSequence(u8, item.content, "\n");
                while (lines.next()) |line| {
                    if (y >= sub.height) break;
                    sub.moveCursor(2, y);
                    sub.putString(line);
                    y += 1;
                }
                y += 1;
            }
        }
    }

    pub fn handleEvent(self: *Accordion, event: Event) widget.EventResult {
        switch (event) {
            .key => |k| {
                switch (k.key) {
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
                    .space, .enter => {
                        return self.toggle(self.selected);
                    },
                    else => {},
                }
            },
            else => {},
        }
        return .ignored;
    }

    pub fn toggle(self: *Accordion, index: usize) widget.EventResult {
        if (index >= self.items.len) return .ignored;

        if (self.mode == .single) {
            for (self.items, 0..) |*item, i| {
                if (i == index) {
                    item.expanded = !item.expanded;
                    if (self.on_change) |cb| cb(index, item.expanded);
                } else {
                    item.expanded = false;
                }
            }
        } else {
            self.items[index].expanded = !self.items[index].expanded;
            if (self.on_change) |cb| cb(index, self.items[index].expanded);
        }
        return .needs_redraw;
    }

    pub fn expand(self: *Accordion, index: usize) void {
        if (index < self.items.len) {
            if (self.mode == .single) {
                for (self.items, 0..) |*item, i| {
                    item.expanded = (i == index);
                }
            } else {
                self.items[index].expanded = true;
            }
        }
    }

    pub fn collapse(self: *Accordion, index: usize) void {
        if (index < self.items.len) {
            self.items[index].expanded = false;
        }
    }

    pub fn collapseAll(self: *Accordion) void {
        for (self.items) |*item| {
            item.expanded = false;
        }
    }
};

test "Accordion creation" {
    var items = [_]AccordionItem{
        .{ .title = "Section 1", .content = "Content 1" },
        .{ .title = "Section 2", .content = "Content 2" },
    };
    const accordion = Accordion.init(&items);
    try std.testing.expectEqual(@as(usize, 2), accordion.items.len);
    try std.testing.expectEqual(AccordionMode.single, accordion.mode);
}

test "Accordion expand collapse" {
    var items = [_]AccordionItem{
        .{ .title = "Test", .content = "Content" },
    };
    var accordion = Accordion.init(&items);
    
    try std.testing.expect(!items[0].expanded);
    accordion.expand(0);
    try std.testing.expect(items[0].expanded);
    
    accordion.collapse(0);
    try std.testing.expect(!items[0].expanded);
}
