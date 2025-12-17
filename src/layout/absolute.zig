// Absolute positioning layout for precise widget placement.

const std = @import("std");
const layout = @import("layout.zig");

pub const AbsolutePosition = struct {
    x: u16,
    y: u16,
    width: u16,
    height: u16,
};

pub const Absolute = struct {
    positions: []const AbsolutePosition,

    pub fn init(positions: []const AbsolutePosition) Absolute {
        return .{ .positions = positions };
    }

    pub fn getPosition(self: *Absolute, index: usize) ?layout.Rect {
        if (index >= self.positions.len) return null;
        const pos = self.positions[index];
        return .{ .x = pos.x, .y = pos.y, .width = pos.width, .height = pos.height };
    }
};

test "Absolute positioning" {
    const positions = [_]AbsolutePosition{.{ .x = 10, .y = 20, .width = 30, .height = 40 }};
    var absolute = Absolute.init(&positions);
    const rect = absolute.getPosition(0).?;
    try std.testing.expectEqual(@as(u16, 10), rect.x);
}
