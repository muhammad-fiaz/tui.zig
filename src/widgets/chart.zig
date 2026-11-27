//! Multi-series `Chart`, `Dataset`, `Axis`, and `LegendPosition` widget.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const block_mod = @import("block.zig");
const canvas_mod = @import("canvas.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Alignment = core_root.Alignment;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const Color = style_root.Color;
pub const Marker = style_root.Marker;
pub const symbols = style_root.symbols;
pub const Block = block_mod.Block;
pub const Bounds = canvas_mod.Bounds;
pub const Point = canvas_mod.Point;
pub const PixelGrid = canvas_mod.PixelGrid;
pub const Painter = canvas_mod.Painter;

/// Visualization style of an individual `Dataset`.
pub const GraphType = enum {
    scatter,
    line,
    area,
    step,
    bar,
};

/// Single plotted `(x, y)` series inside a `Chart`.
pub const Dataset = struct {
    name: ?[]const u8 = null,
    data: []const Point = &.{},
    marker: Marker = .braille,
    graph_type: GraphType = .line,
    style: ?Style = null,
};

/// X or Y axis configuration for `Chart`.
pub const Axis = struct {
    title: ?[]const u8 = null,
    bounds: Bounds = .{ .min = 0.0, .max = 100.0 },
    labels: []const []const u8 = &.{},
    labels_alignment: Alignment = .left,
    style: ?Style = null,
};

/// Placement of the automatic series legend box inside a `Chart`.
pub const LegendPosition = enum {
    top_right,
    top_left,
    bottom_right,
    bottom_left,
    none,
};

/// XY coordinate chart rendering multiple datasets with axes, labels, and optional legend.
pub const Chart = struct {
    datasets: []const Dataset = &.{},
    x_axis: Axis = .{},
    y_axis: Axis = .{},
    block: ?Block = null,
    style: ?Style = null,
    legend_position: LegendPosition = .top_right,
    show_grid_axes: bool = true,
    show_grid_lines: bool = false,
    grid_line_style: ?Style = null,

    /// Renders axes, plotted series, tick labels, and legend into `ui` within `area`.
    pub fn render(self: Chart, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.width < 6 or inner.height < 4) return;

        // Calculate space needed by Y labels and X labels.
        var y_label_w: u16 = 0;
        for (self.y_axis.labels) |lbl| {
            y_label_w = @max(y_label_w, text_root.displayWidth(lbl));
        }
        if (y_label_w > inner.width / 2) y_label_w = inner.width / 2;

        const has_x_labels = self.x_axis.labels.len > 0 or self.x_axis.title != null;
        const x_margin_h: u16 = if (has_x_labels) 2 else 1;
        const y_margin_w: u16 = if (y_label_w > 0) y_label_w + 1 else 1;

        const plot = Rect.init(
            inner.left() + y_margin_w,
            inner.top(),
            inner.width -| y_margin_w,
            inner.height -| x_margin_h,
        );
        if (plot.isEmpty()) return;

        // Draw axis lines.
        if (self.show_grid_axes) {
            const axis_style = self.y_axis.style orelse ui.theme.border;
            const x_axis_style = self.x_axis.style orelse ui.theme.border;
            const axis_x = plot.left() -| 1;
            const axis_y = plot.bottom();

            var y: u16 = plot.top();
            while (y < axis_y) : (y += 1) {
                _ = ui.buffer.setStringClipped(axis_x, y, symbols.line.normal.vertical, 1, axis_style, inner);
            }
            var x: u16 = plot.left();
            while (x < plot.right()) : (x += 1) {
                _ = ui.buffer.setStringClipped(x, axis_y, symbols.line.normal.horizontal, 1, x_axis_style, inner);
            }
            if (axis_y < inner.bottom()) {
                _ = ui.buffer.setStringClipped(axis_x, axis_y, symbols.line.normal.bottom_left, 1, axis_style, inner);
            }
        }

        // Draw Y tick labels.
        if (self.y_axis.labels.len > 0 and y_label_w > 0) {
            const ys = self.y_axis.style orelse ui.theme.muted;
            const n = self.y_axis.labels.len;
            for (self.y_axis.labels, 0..) |lbl, i| {
                const row_off: u16 = if (n == 1) 0 else @intCast(((n - 1 - i) * (plot.height -| 1)) / (n - 1));
                _ = ui.buffer.setStringClipped(inner.left(), plot.top() + row_off, lbl, y_label_w, ys, inner);
            }
        }
        if (self.y_axis.title) |yt| {
            _ = ui.buffer.setStringClipped(plot.left(), plot.top(), yt, plot.width / 2, self.y_axis.style orelse ui.theme.title, inner);
        }

        // Draw X tick labels & title along bottom row.
        if (self.x_axis.labels.len > 0 and plot.bottom() + 1 < inner.bottom()) {
            const xs = self.x_axis.style orelse ui.theme.muted;
            const lbl_y = plot.bottom() + 1;
            const n = self.x_axis.labels.len;
            for (self.x_axis.labels, 0..) |lbl, i| {
                const w = text_root.displayWidth(lbl);
                const px: u16 = if (n == 1)
                    plot.left()
                else
                    plot.left() + @as(u16, @intCast((i * (plot.width -| w)) / (n - 1)));
                _ = ui.buffer.setStringClipped(px, lbl_y, lbl, inner.right() -| px, xs, inner);
            }
        }
        if (self.x_axis.title) |xt| {
            const tw = text_root.displayWidth(xt);
            if (tw < plot.width and plot.bottom() < inner.bottom()) {
                _ = ui.buffer.setStringClipped(plot.right() - tw, plot.bottom(), xt, tw, self.x_axis.style orelse ui.theme.title, inner);
            }
        }

        // Optional background grid lines at major tick intervals.
        if (self.show_grid_lines) {
            const gs = self.grid_line_style orelse ui.theme.muted.patch(.{ .dim = true });
            const h_steps: u16 = 4;
            var s: u16 = 1;
            while (s < h_steps) : (s += 1) {
                const gy = plot.top() + (plot.height * s) / h_steps;
                if (gy < plot.bottom()) {
                    var gx = plot.left();
                    while (gx < plot.right()) : (gx += 2) {
                        _ = ui.buffer.setStringClipped(gx, gy, "·", 1, gs, plot);
                    }
                }
            }
        }

        // Rasterize each dataset onto `plot` via PixelGrid (handles mixed markers cleanly).
        for (self.datasets) |ds| {
            var grid = try PixelGrid.init(ui.scratchAllocator(), plot.width, plot.height, ds.marker);
            var painter = Painter{
                .grid = &grid,
                .x_bounds = self.x_axis.bounds,
                .y_bounds = self.y_axis.bounds,
                .ui = ui,
                .inner = plot,
            };
            const c = if (ds.style) |s| s.foreground else ui.theme.accent.foreground;
            switch (ds.graph_type) {
                .scatter => {
                    for (ds.data) |pt| painter.point(pt.x, pt.y, c);
                },
                .line => {
                    painter.polyline(ds.data, c);
                },
                .area => {
                    // Fill area beneath polyline segments down to baseline (0 when bounds span negative..positive).
                    if (ds.data.len >= 2) {
                        const pw = @as(f64, @floatFromInt(@max(1, painter.grid.pixelWidth() -| 1)));
                        const ph = @as(f64, @floatFromInt(@max(1, painter.grid.pixelHeight() -| 1)));
                        const base_c = c.mix(ui.theme.surface.background, 0.55);
                        const base_y_val = if (self.y_axis.bounds.min < 0.0 and self.y_axis.bounds.max > 0.0) 0.0 else self.y_axis.bounds.min;
                        const y0_px = std.math.clamp(
                            @as(isize, @intFromFloat(@round(((self.y_axis.bounds.max - base_y_val) / self.y_axis.bounds.span()) * ph))),
                            0,
                            @as(isize, @intCast(painter.grid.pixelHeight() -| 1)),
                        );
                        for (0..ds.data.len - 1) |i| {
                            const p0 = ds.data[i];
                            const p1 = ds.data[i + 1];
                            const x0_px: isize = @intFromFloat(@round(((p0.x - self.x_axis.bounds.min) / self.x_axis.bounds.span()) * pw));
                            const x1_px: isize = @intFromFloat(@round(((p1.x - self.x_axis.bounds.min) / self.x_axis.bounds.span()) * pw));
                            const span_x = @max(@as(isize, 1), @as(isize, @intCast(@abs(x1_px - x0_px))));
                            const x_lo = @max(@as(isize, 0), @min(x0_px, x1_px));
                            const x_hi = @min(@as(isize, @intCast(painter.grid.pixelWidth() -| 1)), @max(x0_px, x1_px));
                            var px = x_lo;
                            while (px <= x_hi) : (px += 1) {
                                const frac = if (x0_px == x1_px) 0.0 else @as(f64, @floatFromInt(px - x0_px)) / @as(f64, @floatFromInt(x1_px - x0_px));
                                const interp_y = p0.y + (p1.y - p0.y) * std.math.clamp(frac, 0.0, 1.0);
                                _ = span_x;
                                const y_val_px = std.math.clamp(
                                    @as(isize, @intFromFloat(@round(((self.y_axis.bounds.max - interp_y) / self.y_axis.bounds.span()) * ph))),
                                    0,
                                    @as(isize, @intCast(painter.grid.pixelHeight() -| 1)),
                                );
                                var py = @min(y_val_px, y0_px);
                                while (py <= @max(y_val_px, y0_px)) : (py += 1) {
                                    painter.grid.paintPixel(@intCast(px), @intCast(py), base_c);
                                }
                            }
                        }
                    }
                    painter.polyline(ds.data, c);
                },
                .step => {
                    if (ds.data.len == 1) {
                        painter.point(ds.data[0].x, ds.data[0].y, c);
                    } else if (ds.data.len >= 2) {
                        for (0..ds.data.len - 1) |i| {
                            const p0 = ds.data[i];
                            const p1 = ds.data[i + 1];
                            painter.line(p0.x, p0.y, p1.x, p0.y, c);
                            painter.line(p1.x, p0.y, p1.x, p1.y, c);
                        }
                    }
                },
                .bar => {
                    const bar_w = self.x_axis.bounds.span() / @as(f64, @floatFromInt(@max(@as(usize, 6), ds.data.len * 2)));
                    for (ds.data) |pt| {
                        const base_y = self.y_axis.bounds.min;
                        const top_y = pt.y;
                        const lo = @min(base_y, top_y);
                        const hi = @max(base_y, top_y);
                        painter.rectangle(pt.x - bar_w * 0.5, lo, bar_w, hi - lo, c, true);
                    }
                },
            }
            try grid.flush(ui, plot);
        }

        // Legend box overlay.
        if (self.legend_position != .none) {
            try self.renderLegend(ui, plot);
        }
    }

    fn renderLegend(self: Chart, ui: *Ui, plot: Rect) !void {
        var count: u16 = 0;
        var max_name_w: u16 = 0;
        for (self.datasets) |ds| {
            if (ds.name) |n| {
                count += 1;
                max_name_w = @max(max_name_w, text_root.displayWidth(n));
            }
        }
        if (count == 0) return;

        const box_w = @min(plot.width, max_name_w + 6);
        const box_h = @min(plot.height, count + 2);
        if (box_w < 6 or box_h < 3) return;

        const lx: u16 = switch (self.legend_position) {
            .top_right, .bottom_right => plot.right() - box_w,
            .top_left, .bottom_left => plot.left(),
            .none => return,
        };
        const ly: u16 = switch (self.legend_position) {
            .top_right, .top_left => plot.top(),
            .bottom_right, .bottom_left => plot.bottom() - box_h,
            .none => return,
        };
        const leg_rect = Rect.init(lx, ly, box_w, box_h);
        const blk = Block{ .border_type = .plain, .style = ui.theme.surface, .fill_background = true };
        try blk.render(ui, leg_rect);
        const leg_inner = blk.inner(leg_rect);

        var row: u16 = 0;
        for (self.datasets) |ds| {
            const name = ds.name orelse continue;
            if (row >= leg_inner.height) break;
            const c = if (ds.style) |s| s.foreground else ui.theme.accent.foreground;
            const gy = leg_inner.top() + row;
            const pos = ui.buffer.setStringClipped(leg_inner.left(), gy, "■ ", leg_inner.width, .{ .foreground = c }, leg_inner);
            _ = ui.buffer.setStringClipped(pos.x, gy, name, leg_inner.right() -| pos.x, ui.theme.text, leg_inner);
            row += 1;
        }
    }
};

test "chart plots line dataset with axes and legend" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 32, 10));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    const pts = [_]Point{ .{ .x = 0, .y = 10 }, .{ .x = 50, .y = 80 }, .{ .x = 100, .y = 40 } };
    const datasets = [_]Dataset{
        .{ .name = "CPU", .data = &pts, .style = .{ .foreground = .green } },
    };
    const chart = Chart{
        .datasets = &datasets,
        .x_axis = .{ .labels = &.{ "0s", "50s", "100s" } },
        .y_axis = .{ .labels = &.{ "0", "50", "100" } },
        .block = .{ .title = "Load", .border_type = .plain },
    };
    try ui.renderWidget(chart, buf.area);

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "CPU") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "100") != null);

    // Area and Step graph types render cleanly alongside markers.
    buf.clear();
    try ui.renderWidget(Chart{
        .datasets = &.{
            .{ .name = "Mem", .data = &pts, .graph_type = .area, .style = .{ .foreground = .cyan } },
            .{ .name = "Net", .data = &pts, .graph_type = .step, .style = .{ .foreground = .yellow } },
        },
    }, buf.area);
}
