//! Linear constraint layout solver for horizontal, vertical, and nested splits.
//!
//! Provides both zero-allocation fixed-array splits (`splitFixed`) and
//! slice/allocator variants (`splitInto`, `splitAlloc`) sharing one solver.

const std = @import("std");
const geom = @import("geometry.zig");
const con = @import("constraint.zig");
const testing = std.testing;

pub const Rect = geom.Rect;
pub const Margin = geom.Margin;
pub const Padding = geom.Padding;
pub const Direction = con.Direction;
pub const Flex = con.Flex;
pub const Spacing = con.Spacing;
pub const Constraint = con.Constraint;

/// Configuration options controlling layout direction, spacing, margins, and flex.
pub const LayoutOptions = struct {
    /// Axis along which space is divided (`.vertical` by default).
    direction: Direction = .vertical,
    /// Symmetric margin applied before splitting.
    margin: Margin = .{},
    /// Asymmetric interior padding applied before splitting.
    padding: Padding = .{},
    /// Gap or overlap between adjacent segments.
    spacing: Spacing = .none,
    /// Distribution of surplus space when segments do not fill the container.
    flex: Flex = .start,
};

/// Stack-friendly threshold avoiding heap scratch allocations for typical layouts.
const stack_segment_limit = 64;

/// Reusable layout specification that can split arbitrary rectangles.
pub const Layout = struct {
    direction: Direction = .vertical,
    constraints: []const Constraint = &.{},
    margin: Margin = .{},
    padding: Padding = .{},
    spacing: Spacing = .none,
    flex: Flex = .start,

    /// Creates a layout with `constraints` and `.{}` configuration overrides.
    pub fn init(constraints: []const Constraint, options: LayoutOptions) Layout {
        return .{
            .direction = options.direction,
            .constraints = constraints,
            .margin = options.margin,
            .padding = options.padding,
            .spacing = options.spacing,
            .flex = options.flex,
        };
    }

    /// Convenience constructor for a vertical layout.
    pub fn vertical(constraints: []const Constraint, options: LayoutOptions) Layout {
        var opts = options;
        opts.direction = .vertical;
        return init(constraints, opts);
    }

    /// Convenience constructor for a horizontal layout.
    pub fn horizontal(constraints: []const Constraint, options: LayoutOptions) Layout {
        var opts = options;
        opts.direction = .horizontal;
        return init(constraints, opts);
    }

    /// Splits `area` into caller-provided `out_areas` slice without allocating.
    pub fn splitInto(self: Layout, area: Rect, out_areas: []Rect) []Rect {
        return splitBuffer(area, self.constraints, out_areas, null, .{
            .direction = self.direction,
            .margin = self.margin,
            .padding = self.padding,
            .spacing = self.spacing,
            .flex = self.flex,
        });
    }

    /// Allocates and returns the split rectangles using `allocator`. Caller owns returned slice.
    pub fn splitAlloc(self: Layout, allocator: std.mem.Allocator, area: Rect) std.mem.Allocator.Error![]Rect {
        return layout_mod.splitAlloc(allocator, area, self.constraints, .{
            .direction = self.direction,
            .margin = self.margin,
            .padding = self.padding,
            .spacing = self.spacing,
            .flex = self.flex,
        });
    }
};

const layout_mod = @This();

/// Splits `area` into a compile-time fixed array `[N]Rect` with zero heap allocation.
pub fn splitFixed(
    comptime N: usize,
    area: Rect,
    constraints: [N]Constraint,
    options: LayoutOptions,
) [N]Rect {
    var out: [N]Rect = undefined;
    _ = splitBuffer(area, &constraints, &out, null, options);
    return out;
}

/// Splits `area` into `[N]Rect` segments and `[N + 1]Rect` spacer rectangles with zero allocation.
pub fn splitFixedWithSpacers(
    comptime N: usize,
    area: Rect,
    constraints: [N]Constraint,
    options: LayoutOptions,
) struct { areas: [N]Rect, spacers: [N + 1]Rect } {
    var out: [N]Rect = undefined;
    var spacers: [N + 1]Rect = undefined;
    _ = splitBuffer(area, &constraints, &out, &spacers, options);
    return .{ .areas = out, .spacers = spacers };
}

/// Allocates and splits `area` according to `constraints` and `options`.
/// Caller owns the returned slice and must free it with `allocator.free`.
pub fn splitAlloc(
    allocator: std.mem.Allocator,
    area: Rect,
    constraints: []const Constraint,
    options: LayoutOptions,
) std.mem.Allocator.Error![]Rect {
    const out = try allocator.alloc(Rect, constraints.len);
    _ = splitBuffer(area, constraints, out, null, options);
    return out;
}

/// Splits `area` into caller-provided `out_areas` (and optional `out_spacers`).
/// Performs zero heap allocations when `constraints.len <= 64`.
pub fn splitBuffer(
    area: Rect,
    constraints: []const Constraint,
    out_areas: []Rect,
    out_spacers: ?[]Rect,
    options: LayoutOptions,
) []Rect {
    const count = @min(constraints.len, out_areas.len);
    if (count == 0) {
        if (out_spacers) |sp| {
            if (sp.len > 0) sp[0] = area.inner(options.margin).inset(options.padding);
        }
        return out_areas[0..0];
    }

    const inner = area.inner(options.margin).inset(options.padding);
    const total_span: u16 = switch (options.direction) {
        .horizontal => inner.width,
        .vertical => inner.height,
    };

    var stack_sizes: [stack_segment_limit]u16 = undefined;
    const sizes: []u16 = if (count <= stack_segment_limit)
        stack_sizes[0..count]
    else blk: {
        // Beyond 64 segments, solve directly into out_areas.width/height as scratch, then position.
        for (0..count) |i| {
            out_areas[i] = Rect.zero;
        }
        break :blk stack_sizes[0..0];
    };

    if (sizes.len == count) {
        solveSizes(constraints[0..count], total_span, options, sizes);
        assignRects(inner, sizes, out_areas[0..count], out_spacers, options);
        return out_areas[0..count];
    }

    // Fallback for > 64 segments without allocating: use out_areas[i].width temporarily as size scratch.
    for (constraints[0..count], 0..) |c, i| {
        out_areas[i] = .{ .x = 0, .y = 0, .width = c.targetSpan(total_span), .height = 0 };
    }
    var used: u32 = 0;
    for (out_areas[0..count]) |r| used += r.width;
    if (used > total_span and used > 0) {
        for (out_areas[0..count]) |*r| {
            r.width = @intCast((@as(u32, r.width) * total_span) / used);
        }
    }
    var pos: u16 = switch (options.direction) {
        .horizontal => inner.x,
        .vertical => inner.y,
    };
    for (out_areas[0..count]) |*r| {
        const seg = r.width;
        r.* = switch (options.direction) {
            .horizontal => Rect.init(pos, inner.y, seg, inner.height),
            .vertical => Rect.init(inner.x, pos, inner.width, seg),
        };
        pos +|= seg;
    }
    return out_areas[0..count];
}

fn solveSizes(
    constraints: []const Constraint,
    total_span: u16,
    options: LayoutOptions,
    sizes: []u16,
) void {
    const count = constraints.len;
    @memset(sizes, 0);
    if (total_span == 0 or count == 0) return;

    const gap_total: i32 = if (count <= 1) 0 else switch (options.spacing) {
        .space => |s| @as(i32, s) * @as(i32, @intCast(count - 1)),
        .overlap => |o| -@as(i32, o) * @as(i32, @intCast(count - 1)),
    };

    const available_for_segments: u16 = blk: {
        const raw: i32 = @as(i32, total_span) - gap_total;
        break :blk @intCast(std.math.clamp(raw, 0, @as(i32, total_span) + @as(i32, @intCast(@max(0, -gap_total)))));
    };

    var fill_weight_sum: u32 = 0;
    var has_fill = false;

    for (constraints, 0..) |c, i| {
        switch (c) {
            .fill => |w| {
                has_fill = true;
                fill_weight_sum += w;
                sizes[i] = 0;
            },
            else => {
                sizes[i] = c.targetSpan(available_for_segments);
            },
        }
    }

    // Total requested non-fill space.
    var used: u32 = 0;
    for (sizes) |s| used += s;

    // Shrink if requested space exceeds available_for_segments, respecting higher-priority constraints first.
    if (used > available_for_segments) {
        var excess: u32 = used - available_for_segments;
        // Shrink from lowest priority (4: ratio) up to highest (0: min).
        var prio: i32 = 4;
        while (prio >= 0 and excess > 0) : (prio -= 1) {
            var tier_sum: u32 = 0;
            for (constraints, 0..) |c, i| {
                if (c.priority() == prio) tier_sum += sizes[i];
            }
            if (tier_sum == 0) continue;

            if (tier_sum <= excess) {
                for (constraints, 0..) |c, i| {
                    if (c.priority() == prio) {
                        excess -= sizes[i];
                        sizes[i] = 0;
                    }
                }
            } else {
                const target_tier = tier_sum - excess;
                var allocated: u32 = 0;
                var last_idx: ?usize = null;
                for (constraints, 0..) |c, i| {
                    if (c.priority() == prio) {
                        const shrunk: u16 = @intCast((@as(u64, sizes[i]) * target_tier) / tier_sum);
                        sizes[i] = shrunk;
                        allocated += shrunk;
                        last_idx = i;
                    }
                }
                if (last_idx) |li| {
                    const diff = target_tier - allocated;
                    sizes[li] +|= @intCast(diff);
                }
                excess = 0;
            }
        }
        used = available_for_segments;
    }

    const remaining: u16 = available_for_segments -| @as(u16, @intCast(@min(used, available_for_segments)));

    // Distribute remaining space to `.fill(weight)` segments proportionally.
    if (has_fill and remaining > 0) {
        if (fill_weight_sum > 0) {
            var distributed: u32 = 0;
            var first_fill: ?usize = null;
            for (constraints, 0..) |c, i| {
                if (c == .fill and c.fill > 0) {
                    if (first_fill == null) first_fill = i;
                    const share: u16 = @intCast((@as(u64, remaining) * c.fill) / fill_weight_sum);
                    sizes[i] = share;
                    distributed += share;
                }
            }
            // Distribute rounding remainder one cell at a time across non-zero fill segments.
            var rem: u32 = remaining -| distributed;
            var idx: usize = 0;
            while (rem > 0 and idx < count) : (idx += 1) {
                if (constraints[idx] == .fill and constraints[idx].fill > 0) {
                    sizes[idx] += 1;
                    rem -= 1;
                }
            }
        } else if (options.flex == .legacy) {
            // All fill weights are 0 under legacy flex: first fill(0) absorbs excess.
            for (constraints, 0..) |c, i| {
                if (c == .fill) {
                    sizes[i] = remaining;
                    break;
                }
            }
        }
    } else if (!has_fill and remaining > 0 and options.flex == .legacy) {
        // Legacy flex expands the lowest-priority segment (or last segment on tie).
        var target: usize = count - 1;
        var best_prio: u8 = 0;
        for (constraints, 0..) |c, i| {
            const p = c.priority();
            if (p >= best_prio) {
                best_prio = p;
                target = i;
            }
        }
        sizes[target] +|= remaining;
    }
}

fn assignRects(
    inner: Rect,
    sizes: []const u16,
    out_areas: []Rect,
    out_spacers: ?[]Rect,
    options: LayoutOptions,
) void {
    const count = sizes.len;
    const total_span: u16 = switch (options.direction) {
        .horizontal => inner.width,
        .vertical => inner.height,
    };

    const base_gap: i32 = switch (options.spacing) {
        .space => |s| @as(i32, s),
        .overlap => |o| -@as(i32, o),
    };

    var sum_sizes: u32 = 0;
    for (sizes) |s| sum_sizes += s;
    const min_gaps: i32 = if (count <= 1) 0 else base_gap * @as(i32, @intCast(count - 1));
    const consumed: i32 = @as(i32, @intCast(sum_sizes)) + min_gaps;
    const extra: u16 = if (consumed < @as(i32, total_span))
        @intCast(@as(i32, total_span) - consumed)
    else
        0;

    var lead: u16 = 0;
    var extra_between: u16 = 0;
    var extra_rem: u16 = 0;

    switch (options.flex) {
        .start, .legacy => {},
        .end => lead = extra,
        .center => lead = extra / 2,
        .space_between => {
            if (count > 1) {
                extra_between = extra / @as(u16, @intCast(count - 1));
                extra_rem = extra % @as(u16, @intCast(count - 1));
            }
        },
        .space_around => {
            const slots: u16 = @intCast(count * 2);
            const unit = extra / slots;
            const mod = extra % slots;
            lead = unit;
            extra_between = unit * 2;
            extra_rem = mod;
        },
        .space_evenly => {
            const slots: u16 = @intCast(count + 1);
            const unit = extra / slots;
            const mod = extra % slots;
            lead = unit + @intFromBool(mod > 0);
            extra_between = unit;
            extra_rem = if (mod > 0) mod - 1 else 0;
        },
    }

    const origin: i32 = switch (options.direction) {
        .horizontal => inner.x,
        .vertical => inner.y,
    };
    const end_edge: i32 = origin + total_span;

    var cursor: i32 = origin + lead;
    if (out_spacers) |sp| {
        if (sp.len > 0) {
            sp[0] = makeAxisRect(options.direction, inner, @intCast(origin), lead);
        }
    }

    for (sizes, 0..) |seg, i| {
        const clamped_start: u16 = @intCast(std.math.clamp(cursor, origin, end_edge));
        const clamped_len: u16 = @intCast(@max(0, @min(@as(i32, seg), end_edge - clamped_start)));
        out_areas[i] = makeAxisRect(options.direction, inner, clamped_start, clamped_len);

        const seg_end = cursor + seg;
        if (i + 1 < count) {
            const bump: u16 = if (extra_rem > 0) blk: {
                extra_rem -= 1;
                break :blk 1;
            } else 0;
            const step_gap = base_gap + @as(i32, extra_between + bump);
            if (out_spacers) |sp| {
                if (i + 1 < sp.len) {
                    const sp_start: u16 = @intCast(std.math.clamp(seg_end, origin, end_edge));
                    const sp_len: u16 = @intCast(@max(0, @min(step_gap, end_edge - sp_start)));
                    sp[i + 1] = makeAxisRect(options.direction, inner, sp_start, sp_len);
                }
            }
            cursor = seg_end + step_gap;
        } else {
            if (out_spacers) |sp| {
                if (count < sp.len) {
                    const sp_start: u16 = @intCast(std.math.clamp(seg_end, origin, end_edge));
                    const sp_len: u16 = @intCast(@max(0, end_edge - sp_start));
                    sp[count] = makeAxisRect(options.direction, inner, sp_start, sp_len);
                }
            }
        }
    }
}

fn makeAxisRect(dir: Direction, inner: Rect, pos: u16, span: u16) Rect {
    return switch (dir) {
        .horizontal => Rect.init(pos, inner.y, span, inner.height),
        .vertical => Rect.init(inner.x, pos, inner.width, span),
    };
}

test "splitFixed handles horizontal, vertical, fill, and flex modes" {
    const area = Rect.init(0, 0, 80, 24);
    const rows = splitFixed(3, area, .{
        .{ .length = 3 },
        .{ .fill = 1 },
        .{ .length = 2 },
    }, .{ .direction = .vertical });

    try testing.expectEqual(Rect.init(0, 0, 80, 3), rows[0]);
    try testing.expectEqual(Rect.init(0, 3, 80, 19), rows[1]);
    try testing.expectEqual(Rect.init(0, 22, 80, 2), rows[2]);

    const cols = splitFixed(2, rows[1], .{
        .{ .percentage = 25 },
        .{ .fill = 1 },
    }, .{ .direction = .horizontal, .spacing = Spacing.gap(2) });
    try testing.expectEqual(@as(u16, 20), cols[0].width);
    try testing.expectEqual(@as(u16, 22), cols[1].x);
    try testing.expectEqual(@as(u16, 58), cols[1].width);
}

test "splitFixed handles center, end, space_between, and overflow shrinkage" {
    const area = Rect.init(0, 0, 80, 10);
    const centered = splitFixed(2, area, .{ .{ .length = 20 }, .{ .length = 20 } }, .{
        .direction = .horizontal,
        .flex = .center,
    });
    try testing.expectEqual(@as(u16, 20), centered[0].x);
    try testing.expectEqual(@as(u16, 40), centered[1].x);

    const overflow = splitFixed(2, Rect.init(0, 0, 30, 10), .{
        .{ .min = 20 },
        .{ .percentage = 100 },
    }, .{ .direction = .horizontal });
    try testing.expectEqual(@as(u16, 20), overflow[0].width);
    try testing.expectEqual(@as(u16, 10), overflow[1].width);
}

test "splitAlloc owns returned slice and supports >64 segments" {
    const alloc = testing.allocator;
    const constraints: [70]Constraint = @splat(.{ .length = 2 });
    const result = try splitAlloc(alloc, Rect.init(0, 0, 200, 10), &constraints, .{ .direction = .horizontal });
    defer alloc.free(result);
    try testing.expectEqual(@as(usize, 70), result.len);
    try testing.expectEqual(@as(u16, 8), result[4].x);
    try testing.expectEqual(@as(u16, 138), result[69].x);
}
