// Stack layout for overlaying widgets on top of each other.

const std = @import("std");
const layout = @import("layout.zig");

pub const StackAlignment = enum {
    top_left,
    top_center,
    top_right,
    center_left,
    center,
    center_right,
    bottom_left,
    bottom_center,
    bottom_right,
};

pub const Stack = struct {
    alignment: StackAlignment = .center,

    pub fn init() Stack {
        return .{};
    }

    pub fn withAlignment(self: Stack, alignment: StackAlignment) Stack {
        var result = self;
        result.alignment = alignment;
        return result;
    }

    pub fn alignChild(self: *Stack, child_width: u16, child_height: u16, container_width: u16, container_height: u16) layout.Rect {
        return switch (self.alignment) {
            .top_left => .{ .x = 0, .y = 0, .width = child_width, .height = child_height },
            .top_center => .{ .x = (container_width -| child_width) / 2, .y = 0, .width = child_width, .height = child_height },
            .top_right => .{ .x = container_width -| child_width, .y = 0, .width = child_width, .height = child_height },
            .center_left => .{ .x = 0, .y = (container_height -| child_height) / 2, .width = child_width, .height = child_height },
            .center => .{ .x = (container_width -| child_width) / 2, .y = (container_height -| child_height) / 2, .width = child_width, .height = child_height },
            .center_right => .{ .x = container_width -| child_width, .y = (container_height -| child_height) / 2, .width = child_width, .height = child_height },
            .bottom_left => .{ .x = 0, .y = container_height -| child_height, .width = child_width, .height = child_height },
            .bottom_center => .{ .x = (container_width -| child_width) / 2, .y = container_height -| child_height, .width = child_width, .height = child_height },
            .bottom_right => .{ .x = container_width -| child_width, .y = container_height -| child_height, .width = child_width, .height = child_height },
        };
    }
};

test "Stack alignment" {
    var stack = Stack.init();
    const rect = stack.alignChild(10, 10, 100, 100);
    try std.testing.expectEqual(@as(u16, 45), rect.x);
    try std.testing.expectEqual(@as(u16, 45), rect.y);
}
