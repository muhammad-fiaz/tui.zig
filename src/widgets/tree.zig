// Tree view widget for hierarchical data display.
// Supports expand/collapse and keyboard navigation.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;
const Event = @import("../event/events.zig").Event;

pub const TreeNode = struct {
    label: []const u8,
    expanded: bool = false,
    children: []TreeNode = &[_]TreeNode{},
    level: usize = 0,
};

pub const TreeView = struct {
    root: []TreeNode,
    selected: usize = 0,
    base: widget.StatefulWidget = .{},
    style: Style = Style.default,
    on_select: ?*const fn (usize) void = null,

    pub fn init(root: []TreeNode) TreeView {
        return .{ .root = root };
    }

    pub fn render(self: *TreeView, ctx: *widget.RenderContext) void {
        var sub = ctx.getSubScreen();
        var y: u16 = 0;
        var index: usize = 0;

        for (self.root) |*node| {
            self.renderNode(node, &sub, &y, &index);
        }
    }

    fn renderNode(self: *TreeView, node: *TreeNode, sub: *@import("../core/screen.zig").SubScreen, y: *u16, index: *usize) void {
        if (y.* >= sub.height) return;

        const is_selected = index.* == self.selected;
        
        // Indentation
        sub.moveCursor(0, y.*);
        for (0..node.level) |_| {
            sub.putString("  ");
        }

        // Expand/collapse indicator
        if (node.children.len > 0) {
            if (node.expanded) {
                sub.setStyle(self.style.setFg(Color.yellow));
                sub.putString("▼ ");
            } else {
                sub.setStyle(self.style.setFg(Color.yellow));
                sub.putString("▶ ");
            }
        } else {
            sub.putString("  ");
        }

        // Label
        if (is_selected) {
            sub.setStyle(self.style.bold().reverse());
        } else {
            sub.setStyle(self.style);
        }
        sub.putString(node.label);

        y.* += 1;
        index.* += 1;

        // Render children if expanded
        if (node.expanded) {
            for (node.children) |*child| {
                self.renderNode(child, sub, y, index);
            }
        }
    }

    pub fn handleEvent(self: *TreeView, event: Event) widget.EventResult {
        switch (event) {
            .key => |k| {
                switch (k.key) {
                    .up => {
                        if (self.selected > 0) {
                            self.selected -= 1;
                            if (self.on_select) |cb| cb(self.selected);
                            return .needs_redraw;
                        }
                    },
                    .down => {
                        const total = self.countVisibleNodes();
                        if (self.selected + 1 < total) {
                            self.selected += 1;
                            if (self.on_select) |cb| cb(self.selected);
                            return .needs_redraw;
                        }
                    },
                    .right => {
                        if (self.getNodeAtIndex(self.selected)) |node| {
                            if (node.children.len > 0 and !node.expanded) {
                                node.expanded = true;
                                return .needs_redraw;
                            }
                        }
                    },
                    .left => {
                        if (self.getNodeAtIndex(self.selected)) |node| {
                            if (node.expanded) {
                                node.expanded = false;
                                return .needs_redraw;
                            }
                        }
                    },
                    .space, .enter => {
                        if (self.getNodeAtIndex(self.selected)) |node| {
                            if (node.children.len > 0) {
                                node.expanded = !node.expanded;
                                return .needs_redraw;
                            }
                        }
                    },
                    else => {},
                }
            },
            else => {},
        }
        return .ignored;
    }

    fn countVisibleNodes(self: *TreeView) usize {
        var count: usize = 0;
        for (self.root) |*node| {
            count += self.countNodeAndChildren(node);
        }
        return count;
    }

    fn countNodeAndChildren(self: *TreeView, node: *TreeNode) usize {
        var count: usize = 1;
        if (node.expanded) {
            for (node.children) |*child| {
                count += self.countNodeAndChildren(child);
            }
        }
        return count;
    }

    fn getNodeAtIndex(self: *TreeView, target: usize) ?*TreeNode {
        var index: usize = 0;
        for (self.root) |*node| {
            if (self.findNodeAtIndex(node, target, &index)) |found| {
                return found;
            }
        }
        return null;
    }

    fn findNodeAtIndex(self: *TreeView, node: *TreeNode, target: usize, current: *usize) ?*TreeNode {
        if (current.* == target) return node;
        current.* += 1;

        if (node.expanded) {
            for (node.children) |*child| {
                if (self.findNodeAtIndex(child, target, current)) |found| {
                    return found;
                }
            }
        }
        return null;
    }
};
