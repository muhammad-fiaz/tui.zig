//! Layout direction, constraints, flex distribution, and segment spacing.

const std = @import("std");
const testing = std.testing;

/// Primary axis along which a layout divides space.
pub const Direction = enum {
    horizontal,
    vertical,
};

/// Space distribution strategy when segments do not consume all available space.
pub const Flex = enum {
    /// Aligns segments to the start of the container.
    start,
    /// Aligns segments to the end of the container.
    end,
    /// Centers segments within the container.
    center,
    /// Places equal gaps between segments, with none at the outer edges.
    space_between,
    /// Places equal gaps around each segment (outer edges receive half-gaps).
    space_around,
    /// Places equal gaps before, between, and after every segment.
    space_evenly,
    /// Expands the lowest-priority flexible/last segment to fill all remaining space.
    legacy,
};

/// Spacing between adjacent layout segments (positive gap or negative overlap).
pub const Spacing = union(enum) {
    space: u16,
    overlap: u16,

    pub const none: Spacing = .{ .space = 0 };

    pub fn gap(cells: u16) Spacing {
        return .{ .space = cells };
    }

    pub fn overlapCells(cells: u16) Spacing {
        return .{ .overlap = cells };
    }

    pub fn fromInt(value: i32) Spacing {
        if (value < 0) {
            const abs_val: u32 = @intCast(-@max(value, -std.math.maxInt(i16)));
            return .{ .overlap = @intCast(@min(abs_val, std.math.maxInt(u16))) };
        }
        return .{ .space = @intCast(@min(@as(u32, @intCast(value)), std.math.maxInt(u16))) };
    }
};

/// Size constraint for a single layout segment.
pub const Constraint = union(enum) {
    /// Exact preferred cell length.
    length: u16,
    /// Minimum cell size (highest priority).
    min: u16,
    /// Maximum cell size.
    max: u16,
    /// Percentage of the available container span (`0..100`).
    percentage: u16,
    /// Fractional ratio (`numerator / denominator`) of the available span.
    ratio: struct {
        numerator: u32,
        denominator: u32,
    },
    /// Proportional weight sharing remaining space after fixed/bounded constraints.
    fill: u16,

    /// Convenience constructor for `.ratio`.
    pub fn ratioOf(numerator: u32, denominator: u32) Constraint {
        return .{ .ratio = .{ .numerator = numerator, .denominator = denominator } };
    }

    /// Evaluates the ideal target span before cross-segment balancing.
    pub fn targetSpan(self: Constraint, total_span: u16) u16 {
        return switch (self) {
            .length => |n| n,
            .min => |m| m,
            .max => |m| m,
            .percentage => |p| blk: {
                const clamped = @min(p, 100);
                break :blk @intCast((@as(u32, total_span) * clamped + 50) / 100);
            },
            .ratio => |r| blk: {
                if (r.denominator == 0) break :blk 0;
                const prod = @as(u64, total_span) * @as(u64, r.numerator);
                const rounded = (prod + r.denominator / 2) / r.denominator;
                break :blk @intCast(@min(rounded, std.math.maxInt(u16)));
            },
            .fill => 0,
        };
    }

    /// Relative constraint priority (`0` highest -> `5` lowest).
    pub fn priority(self: Constraint) u8 {
        return switch (self) {
            .min => 0,
            .max => 1,
            .length => 2,
            .percentage => 3,
            .ratio => 4,
            .fill => 5,
        };
    }
};

test "constraint targetSpan computes expected dimensions" {
    try testing.expectEqual(@as(u16, 12), (Constraint{ .length = 12 }).targetSpan(100));
    try testing.expectEqual(@as(u16, 25), (Constraint{ .percentage = 25 }).targetSpan(100));
    try testing.expectEqual(@as(u16, 33), Constraint.ratioOf(1, 3).targetSpan(100));
    try testing.expectEqual(@as(u16, 0), Constraint.ratioOf(1, 0).targetSpan(100));
    try testing.expectEqual(@as(u16, 0), (Constraint{ .fill = 1 }).targetSpan(100));
}
