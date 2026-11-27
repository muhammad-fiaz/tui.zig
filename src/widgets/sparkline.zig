//! Compact time-series `Sparkline` widget using 8-level vertical Unicode blocks.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const BarSet = style_root.BarSet;
pub const symbols = style_root.symbols;
pub const Block = block_mod.Block;

/// Horizontal plotting order for sparkline data points.
pub const RenderDirection = enum {
    left_to_right,
    right_to_left,
};

/// Single- or multi-row vertical bar sparkline chart (`data: []const ?u64` or `values: []const f64`).
pub const Sparkline = struct {
    /// Raw integer samples (supports `null` gaps). Ignored if `values` is non-empty.
    data: []const ?u64 = &.{},
    /// Convenience dense `u64` slice when no missing samples exist.
    raw_data: []const u64 = &.{},
    /// Explicit upper scale bound (`null` auto-scales to maximum observed sample).
    max: ?u64 = null,
    absent_value_symbol: []const u8 = " ",
    direction: RenderDirection = .left_to_right,
    bar_set: BarSet = symbols.bar.nine_levels,
    block: ?Block = null,
    style: ?Style = null,
    absent_style: ?Style = null,

    /// Convenience constructor for a non-null `u64` slice.
    pub fn fromSlice(samples: []const u64) Sparkline {
        return .{ .raw_data = samples };
    }

    fn countSamples(self: Sparkline) usize {
        return if (self.data.len > 0) self.data.len else self.raw_data.len;
    }

    fn sampleAt(self: Sparkline, idx: usize) ?u64 {
        return if (self.data.len > 0) self.data[idx] else self.raw_data[idx];
    }

    /// Renders this sparkline into `ui` within `area`.
    pub fn render(self: Sparkline, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        const bar_s = self.style orelse ui.theme.accent;
        const abs_s = self.absent_style orelse ui.theme.muted;
        const n = self.countSamples();
        if (n == 0) return;

        const visible = @min(n, inner.width);
        var max_val: u64 = self.max orelse 0;
        if (self.max == null) {
            for (0..visible) |i| {
                if (self.sampleAt(i)) |v| max_val = @max(max_val, v);
            }
        }
        if (max_val == 0) max_val = 1;

        const max_steps: usize = @as(usize, inner.height) * 8;
        for (0..visible) |i| {
            const col: u16 = switch (self.direction) {
                .left_to_right => inner.left() + @as(u16, @intCast(i)),
                .right_to_left => inner.right() - 1 - @as(u16, @intCast(i)),
            };
            const maybe_v = self.sampleAt(i);
            if (maybe_v == null) {
                if (ui.buffer.getMut(col, inner.bottom() - 1)) |cell| {
                    try ui.buffer.setCellSymbol(cell, self.absent_value_symbol);
                    cell.diff_option = .none;
                    cell.setStyle(abs_s);
                }
                continue;
            }
            const clamped = @min(maybe_v.?, max_val);
            var remaining_steps: usize = @intCast((@as(u128, clamped) * max_steps) / max_val);
            if (clamped > 0 and remaining_steps == 0) remaining_steps = 1;

            var row_off: u16 = 0;
            while (row_off < inner.height) : (row_off += 1) {
                const gy = inner.bottom() - 1 - row_off;
                const cell_steps: u8 = if (remaining_steps >= 8) 8 else @intCast(remaining_steps);
                remaining_steps -|= 8;
                if (ui.buffer.getMut(col, gy)) |cell| {
                    try ui.buffer.setCellSymbol(cell, self.bar_set.level(cell_steps));
                    cell.diff_option = .none;
                    cell.setStyle(bar_s);
                }
            }
        }
    }
};

test "sparkline auto-scales multi-row vertical block glyphs" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 8, 2));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    try ui.renderWidget(Sparkline.fromSlice(&.{ 0, 4, 8, 16 }), buf.area);

    try testing.expectEqualStrings(" ", buf.get(0, 1).?.symbol());
    try testing.expectEqualStrings("█", buf.get(3, 1).?.symbol());
    try testing.expectEqualStrings("█", buf.get(3, 0).?.symbol());
}
