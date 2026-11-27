//! Vertical and horizontal grouped `BarChart` widget (`Bar`, `BarGroup`, `BarChart`).

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Direction = core_root.Direction;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const BarSet = style_root.BarSet;
pub const symbols = style_root.symbols;
pub const Block = block_mod.Block;

/// Single data bar inside a `BarGroup`.
pub const Bar = struct {
    label: ?[]const u8 = null,
    value: u64 = 0,
    text_value: ?[]const u8 = null,
    style: ?Style = null,
    value_style: ?Style = null,

    pub fn init(label: []const u8, value: u64) Bar {
        return .{ .label = label, .value = value };
    }
};

/// Logical cluster of one or more `Bar`s sharing an optional group caption.
pub const BarGroup = struct {
    label: ?[]const u8 = null,
    bars: []const Bar = &.{},
};

/// Categorical vertical or horizontal grouped bar chart widget.
pub const BarChart = struct {
    groups: []const BarGroup = &.{},
    /// Shorthand ungrouped slice of `Bar`s when `groups` is empty.
    bars: []const Bar = &.{},
    block: ?Block = null,
    direction: Direction = .vertical,
    bar_width: u16 = 3,
    bar_gap: u16 = 1,
    group_gap: u16 = 2,
    max: ?u64 = null,
    bar_set: BarSet = symbols.bar.nine_levels,
    bar_style: ?Style = null,
    value_style: ?Style = null,
    label_style: ?Style = null,

    /// Shorthand constructor from flat `Bar` slice.
    pub fn fromBars(bars_slice: []const Bar) BarChart {
        return .{ .bars = bars_slice };
    }

    /// Renders this bar chart into `ui` within `area`.
    pub fn render(self: BarChart, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        var single_group = [_]BarGroup{.{ .bars = self.bars }};
        const active_groups: []const BarGroup = if (self.groups.len > 0) self.groups else &single_group;

        var max_v: u64 = self.max orelse 0;
        if (self.max == null) {
            for (active_groups) |g| {
                for (g.bars) |b| max_v = @max(max_v, b.value);
            }
        }
        if (max_v == 0) max_v = 1;

        switch (self.direction) {
            .vertical => try self.renderVertical(ui, inner, active_groups, max_v),
            .horizontal => try self.renderHorizontal(ui, inner, active_groups, max_v),
        }
    }

    fn renderVertical(self: BarChart, ui: *Ui, inner: Rect, groups: []const BarGroup, max_v: u64) !void {
        const default_bar_s = self.bar_style orelse ui.theme.accent;
        const default_lbl_s = self.label_style orelse ui.theme.muted;
        const default_val_s = self.value_style orelse Style{ .foreground = ui.theme.surface.background, .background = default_bar_s.foreground, .bold = true };

        var has_group_labels = false;
        for (groups) |g| {
            if (g.label != null) {
                has_group_labels = true;
                break;
            }
        }
        const label_rows: u16 = if (has_group_labels and inner.height >= 3) 2 else if (inner.height >= 2) 1 else 0;
        const plot_h = inner.height -| label_rows;
        if (plot_h == 0) return;

        const max_steps: usize = @as(usize, plot_h) * 8;
        var x = inner.left();
        var num_buf: [32]u8 = undefined;

        for (groups, 0..) |grp, gi| {
            if (x >= inner.right()) break;
            if (gi > 0) x +|= self.group_gap;
            const grp_start_x = x;

            for (grp.bars, 0..) |bar, bi| {
                if (x >= inner.right()) break;
                if (bi > 0) x +|= self.bar_gap;
                const w = @min(self.bar_width, inner.right() - x);
                if (w == 0) break;

                const bs = bar.style orelse default_bar_s;
                const clamped = @min(bar.value, max_v);
                var steps: usize = @intCast((@as(u128, clamped) * max_steps) / max_v);
                if (clamped > 0 and steps == 0) steps = 1;
                const orig_steps = steps;

                var row_off: u16 = 0;
                while (row_off < plot_h) : (row_off += 1) {
                    const gy = inner.top() + plot_h - 1 - row_off;
                    const cs: u8 = if (steps >= 8) 8 else @intCast(steps);
                    steps -|= 8;
                    const sym = self.bar_set.level(cs);
                    for (0..w) |dx| {
                        if (ui.buffer.getMut(x + @as(u16, @intCast(dx)), gy)) |cell| {
                            try ui.buffer.setCellSymbol(cell, sym);
                            cell.diff_option = .none;
                            cell.setStyle(bs);
                        }
                    }
                }

                // Numeric value caption near base (avoid bar-colored block on empty 0 bars).
                const val_str = bar.text_value orelse std.fmt.bufPrint(&num_buf, "{d}", .{bar.value}) catch "";
                const vs = bar.value_style orelse if (orig_steps >= 4) default_val_s else default_lbl_s;
                const vy = inner.top() + plot_h - 1;
                if (val_str.len > 0 and text_root.displayWidth(val_str) <= w) {
                    _ = ui.buffer.setStringClipped(x, vy, val_str, w, vs, inner);
                }

                // Per-bar label directly underneath.
                if (label_rows >= 1) {
                    if (bar.label) |bl| {
                        _ = ui.buffer.setStringClipped(x, inner.top() + plot_h, bl, w, default_lbl_s, inner);
                    }
                }
                x +|= w;
            }

            if (has_group_labels and label_rows >= 2) {
                if (grp.label) |gl| {
                    const span_w = x -| grp_start_x;
                    _ = ui.buffer.setStringClipped(grp_start_x, inner.bottom() - 1, gl, span_w, ui.theme.text, inner);
                }
            }
        }
    }

    fn renderHorizontal(self: BarChart, ui: *Ui, inner: Rect, groups: []const BarGroup, max_v: u64) !void {
        const default_bar_s = self.bar_style orelse ui.theme.accent;
        const default_lbl_s = self.label_style orelse ui.theme.text;

        var max_lbl_w: u16 = 0;
        for (groups) |g| {
            for (g.bars) |b| {
                if (b.label) |l| max_lbl_w = @max(max_lbl_w, text_root.displayWidth(l));
            }
        }
        const lbl_col_w: u16 = @min(max_lbl_w +| 1, inner.width / 2);
        const bar_max_w = inner.width -| lbl_col_w;
        if (bar_max_w == 0) return;

        var y = inner.top();
        var num_buf: [32]u8 = undefined;
        for (groups) |grp| {
            for (grp.bars) |bar| {
                if (y >= inner.bottom()) break;
                if (bar.label) |bl| {
                    _ = ui.buffer.setStringClipped(inner.left(), y, bl, lbl_col_w -| 1, default_lbl_s, inner);
                }
                const bar_x = inner.left() + lbl_col_w;
                const val_str = bar.text_value orelse std.fmt.bufPrint(&num_buf, " {d}", .{bar.value}) catch "";
                const val_w = text_root.displayWidth(val_str);
                const draw_area_w = bar_max_w -| val_w;

                const clamped = @min(bar.value, max_v);
                const eighths: usize = @intCast((@as(u128, clamped) * draw_area_w * 8) / max_v);
                const full_cols: u16 = @intCast(eighths / 8);
                const rem: usize = eighths % 8;
                const bs = bar.style orelse default_bar_s;

                var dx: u16 = 0;
                while (dx < full_cols) : (dx += 1) {
                    _ = ui.buffer.setStringClipped(bar_x + dx, y, symbols.block.full, 1, bs, inner);
                }
                if (dx < draw_area_w and rem > 0) {
                    _ = ui.buffer.setStringClipped(bar_x + dx, y, symbols.block.horizontal_eighths[rem], 1, bs, inner);
                    dx += 1;
                }
                if (val_w > 0 and bar_x + dx < inner.right()) {
                    _ = ui.buffer.setStringClipped(bar_x + dx, y, val_str, inner.right() - (bar_x + dx), ui.theme.muted, inner);
                }
                y +|= 1 + self.bar_gap;
            }
        }
    }
};

test "bar chart renders vertical and horizontal labeled bars" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 24, 6));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    const bars = [_]Bar{
        Bar.init("A", 10),
        Bar.init("B", 20),
    };
    try ui.renderWidget(BarChart{ .bars = &bars, .direction = .horizontal }, buf.area);

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "10") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "20") != null);
}
