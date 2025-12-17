//! Layout engine for TUI.zig
//!
//! Provides constraints-based layout with support for:
//! - Flex layouts (row/column)
//! - Center, padding, margin
//! - Fixed and flexible sizing

const std = @import("std");
const style = @import("../style/style.zig");

/// Size constraint
pub const Constraint = struct {
    min: u16 = 0,
    max: u16 = std.math.maxInt(u16),

    /// Unbounded constraint
    pub const unbounded = Constraint{};

    /// Fixed size constraint
    pub fn fixed(size: u16) Constraint {
        return .{ .min = size, .max = size };
    }

    /// At least constraint
    pub fn atLeast(min: u16) Constraint {
        return .{ .min = min };
    }

    /// At most constraint
    pub fn atMost(max: u16) Constraint {
        return .{ .max = max };
    }

    /// Between constraint
    pub fn between(min: u16, max: u16) Constraint {
        return .{ .min = min, .max = max };
    }

    /// Clamp a value to this constraint
    pub fn clamp(self: Constraint, value: u16) u16 {
        return @max(self.min, @min(self.max, value));
    }

    /// Check if a value satisfies this constraint
    pub fn satisfies(self: Constraint, value: u16) bool {
        return value >= self.min and value <= self.max;
    }

    /// Intersect two constraints
    pub fn intersect(self: Constraint, other: Constraint) Constraint {
        return .{
            .min = @max(self.min, other.min),
            .max = @min(self.max, other.max),
        };
    }

    /// Check if constraint is bounded
    pub fn isBounded(self: Constraint) bool {
        return self.max != std.math.maxInt(u16);
    }
};

/// 2D constraints
pub const Constraints = struct {
    width: Constraint = .{},
    height: Constraint = .{},

    pub const unbounded = Constraints{};

    pub fn fixed(width: u16, height: u16) Constraints {
        return .{
            .width = Constraint.fixed(width),
            .height = Constraint.fixed(height),
        };
    }
};

/// Rectangle representing a layout region
pub const Rect = struct {
    x: u16 = 0,
    y: u16 = 0,
    width: u16 = 0,
    height: u16 = 0,

    /// Create a rect from position and size
    pub fn init(x: u16, y: u16, width: u16, height: u16) Rect {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    /// Get the right edge
    pub fn right(self: Rect) u16 {
        return self.x +| self.width;
    }

    /// Get the bottom edge
    pub fn bottom(self: Rect) u16 {
        return self.y +| self.height;
    }

    /// Get the center X
    pub fn centerX(self: Rect) u16 {
        return self.x +| (self.width / 2);
    }

    /// Get the center Y
    pub fn centerY(self: Rect) u16 {
        return self.y +| (self.height / 2);
    }

    /// Check if a point is inside this rect
    pub fn contains(self: Rect, px: u16, py: u16) bool {
        return px >= self.x and px < self.right() and
            py >= self.y and py < self.bottom();
    }

    /// Get the area
    pub fn area(self: Rect) u32 {
        return @as(u32, self.width) * @as(u32, self.height);
    }

    /// Inset by padding
    pub fn inset(self: Rect, top: u16, right_pad: u16, bottom_pad: u16, left_pad: u16) Rect {
        const new_x = self.x +| left_pad;
        const new_y = self.y +| top;
        const new_w = self.width -| left_pad -| right_pad;
        const new_h = self.height -| top -| bottom_pad;
        return .{
            .x = new_x,
            .y = new_y,
            .width = new_w,
            .height = new_h,
        };
    }

    /// Intersect with another rect
    pub fn intersection(self: Rect, other: Rect) Rect {
        const x1 = @max(self.x, other.x);
        const y1 = @max(self.y, other.y);
        const x2 = @min(self.right(), other.right());
        const y2 = @min(self.bottom(), other.bottom());

        if (x2 <= x1 or y2 <= y1) {
            return .{};
        }

        return .{
            .x = x1,
            .y = y1,
            .width = x2 - x1,
            .height = y2 - y1,
        };
    }

    /// Check if empty
    pub fn isEmpty(self: Rect) bool {
        return self.width == 0 or self.height == 0;
    }
};

/// Size specification for layout items
pub const Size = union(enum) {
    /// Fixed size in cells
    fixed: u16,

    /// Percentage of parent (0-100)
    percent: u8,

    /// Flexible - takes remaining space with given weight
    flex: u16,

    /// Fill all available space
    fill,

    /// Fit to content
    fit,

    /// Default size
    pub const default = Size.fit;

    /// Convert to absolute size given available space
    pub fn resolve(self: Size, available: u16, content_size: u16) u16 {
        return switch (self) {
            .fixed => |f| f,
            .percent => |p| @intCast((@as(u32, available) * @as(u32, p)) / 100),
            .flex => available,
            .fill => available,
            .fit => @min(content_size, available),
        };
    }
};

/// Edge values (padding, margin, border)
pub const Edges = struct {
    top: u16 = 0,
    right: u16 = 0,
    bottom: u16 = 0,
    left: u16 = 0,

    pub const zero = Edges{};

    /// All edges same value
    pub fn all(value: u16) Edges {
        return .{ .top = value, .right = value, .bottom = value, .left = value };
    }

    /// Horizontal and vertical
    pub fn symmetric(horiz: u16, vert: u16) Edges {
        return .{ .top = vert, .right = horiz, .bottom = vert, .left = horiz };
    }

    /// Total horizontal space
    pub fn horizontal(self: Edges) u16 {
        return self.left +| self.right;
    }

    /// Total vertical space
    pub fn vertical(self: Edges) u16 {
        return self.top +| self.bottom;
    }
};

/// Layout direction
pub const Direction = enum {
    horizontal,
    vertical,

    /// Get the main axis extent
    pub fn main(self: Direction, width: u16, height: u16) u16 {
        return switch (self) {
            .horizontal => width,
            .vertical => height,
        };
    }

    /// Get the cross axis extent
    pub fn cross(self: Direction, width: u16, height: u16) u16 {
        return switch (self) {
            .horizontal => height,
            .vertical => width,
        };
    }
};

/// Alignment modes
pub const Alignment = style.Alignment;
pub const VerticalAlignment = style.VerticalAlignment;

/// Main axis alignment for flex containers
pub const MainAxisAlignment = enum {
    start,
    end,
    center,
    space_between,
    space_around,
    space_evenly,
};

/// Cross axis alignment for flex containers
pub const CrossAxisAlignment = enum {
    start,
    end,
    center,
    stretch,
};

/// Padding layout wrapper
pub fn Padding(comptime ChildType: type) type {
    return struct {
        child: ChildType,
        edges: Edges,

        const Self = @This();

        pub fn init(child: ChildType, edges: Edges) Self {
            return .{
                .child = child,
                .edges = edges,
            };
        }

        pub fn uniform(child: ChildType, amount: u16) Self {
            return init(child, Edges.all(amount));
        }
    };
}

/// Center layout wrapper
pub fn Center(comptime ChildType: type) type {
    return struct {
        child: ChildType,
        horizontal: bool = true,
        vertical: bool = true,

        const Self = @This();

        pub fn init(child: ChildType) Self {
            return .{ .child = child };
        }

        pub fn horizontalOnly(child: ChildType) Self {
            return .{ .child = child, .vertical = false };
        }

        pub fn verticalOnly(child: ChildType) Self {
            return .{ .child = child, .horizontal = false };
        }
    };
}

/// Sized box layout wrapper
pub fn SizedBox(comptime ChildType: type) type {
    return struct {
        child: ?ChildType = null,
        width: ?u16 = null,
        height: ?u16 = null,

        const Self = @This();

        pub fn init(width: ?u16, height: ?u16) Self {
            return .{ .width = width, .height = height };
        }

        pub fn withChild(self: Self, child: ChildType) Self {
            var result = self;
            result.child = child;
            return result;
        }

        pub fn square(size: u16) Self {
            return .{ .width = size, .height = size };
        }
    };
}

/// Margin layout wrapper
pub fn Margin(comptime ChildType: type) type {
    return struct {
        child: ChildType,
        edges: Edges,

        const Self = @This();

        pub fn init(child: ChildType, edges: Edges) Self {
            return .{
                .child = child,
                .edges = edges,
            };
        }
    };
}

/// Layout item for flex containers
pub const FlexItem = struct {
    /// Size specification
    size: Size = .fit,

    /// Flex grow factor
    grow: u16 = 0,

    /// Flex shrink factor
    shrink: u16 = 1,

    /// Alignment override
    align_self: ?CrossAxisAlignment = null,
};

/// Calculate flex layout
pub fn calculateFlexLayout(
    items: []const FlexItem,
    sizes: []const u16,
    available: u16,
    direction: Direction,
    main_align: MainAxisAlignment,
) FlexResult {
    _ = direction;

    var total_fixed: u32 = 0;
    var total_flex: u32 = 0;

    // First pass: calculate totals
    for (items, sizes) |item, size| {
        switch (item.size) {
            .fixed => |f| total_fixed += f,
            .flex => |f| total_flex += f,
            .fit => total_fixed += size,
            .fill => total_flex += 1,
            .percent => |p| total_fixed += (@as(u32, available) * @as(u32, p)) / 100,
        }
    }

    const remaining = @as(u32, available) -| total_fixed;
    const flex_unit = if (total_flex > 0) remaining / total_flex else 0;

    // Calculate positions based on alignment
    var start_offset: u16 = 0;
    var gap: u16 = 0;

    const item_count = items.len;
    if (item_count > 0) {
        const total_content = total_fixed + (flex_unit * total_flex);
        const extra_space = @as(u32, available) -| total_content;

        switch (main_align) {
            .start => {},
            .end => start_offset = @intCast(extra_space),
            .center => start_offset = @intCast(extra_space / 2),
            .space_between => {
                if (item_count > 1) {
                    gap = @intCast(extra_space / (item_count - 1));
                }
            },
            .space_around => {
                gap = @intCast(extra_space / item_count);
                start_offset = gap / 2;
            },
            .space_evenly => {
                gap = @intCast(extra_space / (item_count + 1));
                start_offset = gap;
            },
        }
    }

    return .{
        .flex_unit = @intCast(flex_unit),
        .start_offset = start_offset,
        .gap = gap,
    };
}

pub const FlexResult = struct {
    flex_unit: u16,
    start_offset: u16,
    gap: u16,
};

test "constraint operations" {
    const c1 = Constraint.between(10, 50);
    try std.testing.expectEqual(@as(u16, 25), c1.clamp(25));
    try std.testing.expectEqual(@as(u16, 10), c1.clamp(5));
    try std.testing.expectEqual(@as(u16, 50), c1.clamp(100));
}

test "rect operations" {
    const rect = Rect.init(10, 20, 30, 40);
    try std.testing.expectEqual(@as(u16, 40), rect.right());
    try std.testing.expectEqual(@as(u16, 60), rect.bottom());
    try std.testing.expect(rect.contains(15, 25));
    try std.testing.expect(!rect.contains(5, 25));
}

test "rect inset" {
    const rect = Rect.init(10, 10, 100, 100);
    const inset = rect.inset(5, 10, 5, 10);
    try std.testing.expectEqual(@as(u16, 20), inset.x);
    try std.testing.expectEqual(@as(u16, 15), inset.y);
    try std.testing.expectEqual(@as(u16, 80), inset.width);
    try std.testing.expectEqual(@as(u16, 90), inset.height);
}

test "edges" {
    const edges = Edges.symmetric(10, 5);
    try std.testing.expectEqual(@as(u16, 20), edges.horizontal());
    try std.testing.expectEqual(@as(u16, 10), edges.vertical());
}
