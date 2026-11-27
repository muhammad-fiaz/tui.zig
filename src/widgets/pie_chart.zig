//! Customizable `PieChart` widget supporting solid pies, donuts, segmented rings,
//! HUD dials, Nightingale rose charts, flexible legend positioning, and true 1:2 aspect math.

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
pub const Color = style_root.Color;
pub const Style = style_root.Style;
pub const Marker = style_root.Marker;
pub const Block = block_mod.Block;
pub const PixelGrid = canvas_mod.PixelGrid;

/// Visual geometry preset for `PieChart`.
pub const PieStyle = enum {
    /// Continuous circular wedges (supports `donut_ratio`, `gap`, and `explode`).
    solid,
    /// Ring composed of separated radial blocks around the circumference.
    segmented,
    /// Outer dial tick scale surrounding a compact band and dashed inner ring.
    hud,
    /// Equal-angle Nightingale polar-area wedges scaled radially by `sqrt(value / max)`.
    rose,
};

/// Placement of the slice legend relative to the pie circle.
pub const PieLegendPosition = enum {
    right,
    left,
    top,
    bottom,
    none,
};

/// Arrangement of items inside the `PieChart` legend box.
pub const PieLegendLayout = enum {
    vertical,
    horizontal,
};

/// Single categorical segment in a `PieChart`.
pub const PieSlice = struct {
    label: []const u8,
    value: f64,
    color: ?Color = null,
};

const default_slice_colors = [_]Color{
    style_root.palette.sky.c400,
    style_root.palette.emerald.c400,
    style_root.palette.amber.c400,
    style_root.palette.rose.c400,
    style_root.palette.violet.c400,
    style_root.palette.cyan.c400,
    style_root.palette.orange.c400,
    style_root.palette.lime.c400,
};

const ArcInfo = struct {
    start_turn: f64,
    len_turns: f64,
    value: f64,
    max_rad: f64,
    color: Color,
};

/// Sub-cell or symbol-based Pie, Donut, Segmented, HUD, and Rose chart with customizable legends.
pub const PieChart = struct {
    slices: []const PieSlice = &.{},
    block: ?Block = null,
    /// Sub-cell resolution grid (`half_block` recommended; `.braille` / `.quadrant` / `.block` also supported).
    marker: Marker = .half_block,
    /// Geometric style (`solid`, `segmented`, `hud`, `rose`).
    pie_style: PieStyle = .solid,
    /// Inner hollow radius fraction (`0.0` = solid pie, `0.45..0.65` = donut ring).
    donut_ratio: f64 = 0.0,
    /// Starting angle in degrees clockwise from 12 o'clock (`0.0` = top).
    start_angle_deg: f64 = 0.0,
    /// Arc gap width between adjacent slices (in physical cell-width units, `0.0` = flush).
    gap: f64 = 0.0,
    /// Outward radial offset for slices (in physical cell-width units, `0.0` = centered).
    explode: f64 = 0.0,
    /// Optional concise text centered inside a donut / segmented / HUD hollow core.
    center_label: ?[]const u8 = null,
    /// Optional explicit symbol used in single-cell resolution (overrides sub-cell blocks when set).
    pie_char: ?[]const u8 = null,
    /// Legend toggle (`false` hides legend even if `legend_position != .none`).
    show_legend: bool = true,
    legend_position: PieLegendPosition = .right,
    legend_layout: PieLegendLayout = .vertical,
    legend_alignment: Alignment = .left,
    legend_marker: []const u8 = "■",
    show_percentages: bool = true,
    /// Color for `.hud` tick marks / dashed guides and `.rose` concentric rings.
    guide_color: ?Color = null,
    style: ?Style = null,

    fn resolvedLegendPos(self: PieChart) PieLegendPosition {
        if (!self.show_legend or self.slices.len == 0) return .none;
        return self.legend_position;
    }

    fn formatEntry(self: PieChart, sl: PieSlice, total: f64, buf: []u8) []const u8 {
        if (self.show_percentages and total > 0.0) {
            const pct = @max(0.0, sl.value) * 100.0 / total;
            return std.fmt.bufPrint(buf, "{s} {s} {d:.0}%", .{ self.legend_marker, sl.label, pct }) catch sl.label;
        }
        return std.fmt.bufPrint(buf, "{s} {s}", .{ self.legend_marker, sl.label }) catch sl.label;
    }

    fn computeLayout(self: PieChart, inner: Rect, total: f64) struct { chart: Rect, legend: Rect } {
        const pos = self.resolvedLegendPos();
        if (pos == .none) return .{ .chart = inner, .legend = Rect.zero };

        var max_entry_w: u16 = 0;
        var horiz_w: u16 = 0;
        var entry_buf: [96]u8 = undefined;
        var active_count: u16 = 0;

        for (self.slices) |sl| {
            const txt = self.formatEntry(sl, total, &entry_buf);
            const w = text_root.displayWidth(txt);
            max_entry_w = @max(max_entry_w, w);
            if (active_count > 0) horiz_w +|= 2;
            horiz_w +|= w;
            active_count += 1;
        }
        if (active_count == 0) return .{ .chart = inner, .legend = Rect.zero };

        switch (pos) {
            .none => return .{ .chart = inner, .legend = Rect.zero },
            .right, .left => {
                if (inner.width < 14) return .{ .chart = inner, .legend = Rect.zero };
                // Ensure the pie receives at least 8 columns (minimum circle footprint) whenever possible.
                const max_leg = inner.width -| 8;
                const wanted = @min(max_entry_w, @max(@as(u16, 4), (inner.width * 3) / 5));
                const leg_w = @min(wanted, max_leg);
                if (leg_w < 5) return .{ .chart = inner, .legend = Rect.zero };
                const gap_cols: u16 = if (inner.width - leg_w >= 10) 1 else 0;
                const chart_w = inner.width - leg_w - gap_cols;
                if (pos == .right) {
                    return .{
                        .chart = Rect.init(inner.left(), inner.top(), chart_w, inner.height),
                        .legend = Rect.init(inner.left() + chart_w + gap_cols, inner.top(), leg_w, inner.height),
                    };
                }
                return .{
                    .legend = Rect.init(inner.left(), inner.top(), leg_w, inner.height),
                    .chart = Rect.init(inner.left() + leg_w + gap_cols, inner.top(), chart_w, inner.height),
                };
            },
            .top, .bottom => {
                if (inner.height < 4) return .{ .chart = inner, .legend = Rect.zero };
                const leg_h: u16 = switch (self.legend_layout) {
                    .horizontal => 1,
                    .vertical => @min(active_count, @max(@as(u16, 1), inner.height / 3)),
                };
                if (inner.height -| leg_h < 3) return .{ .chart = inner, .legend = Rect.zero };
                const chart_h = inner.height - leg_h;
                if (pos == .top) {
                    return .{
                        .legend = Rect.init(inner.left(), inner.top(), inner.width, leg_h),
                        .chart = Rect.init(inner.left(), inner.top() + leg_h, inner.width, chart_h),
                    };
                }
                return .{
                    .chart = Rect.init(inner.left(), inner.top(), inner.width, chart_h),
                    .legend = Rect.init(inner.left(), inner.top() + chart_h, inner.width, leg_h),
                };
            },
        }
    }

    /// Renders this PieChart (and optional legend / center label) into `ui` within `area`.
    pub fn render(self: PieChart, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.width < 4 or inner.height < 2) return;

        var total: f64 = 0.0;
        var positive_count: usize = 0;
        var max_val: f64 = 0.0;
        for (self.slices) |s| {
            if (s.value > 0.0 and !std.math.isNan(s.value)) {
                total += s.value;
                positive_count += 1;
                if (s.value > max_val) max_val = s.value;
            }
        }
        if (total <= 0.0 or positive_count == 0) return;

        const regions = self.computeLayout(inner, total);
        const chart_rect = regions.chart;
        if (chart_rect.width < 2 or chart_rect.height < 2) return;

        // Build normalized arc table (clockwise from `start_angle_deg`, 0° = 12 o'clock).
        const start_turn = @mod(self.start_angle_deg / 360.0, 1.0);
        const arcs = try ui.scratchAllocator().alloc(ArcInfo, positive_count);
        var ai: usize = 0;
        var cur_turn = start_turn;
        const rose_step = 1.0 / @as(f64, @floatFromInt(positive_count));
        for (self.slices, 0..) |sl, idx| {
            if (sl.value <= 0.0 or std.math.isNan(sl.value)) continue;
            const len_t = if (self.pie_style == .rose) rose_step else sl.value / total;
            const c = sl.color orelse default_slice_colors[idx % default_slice_colors.len];
            arcs[ai] = .{
                .start_turn = cur_turn,
                .len_turns = len_t,
                .value = sl.value,
                .max_rad = if (self.pie_style == .rose and max_val > 0.0) @sqrt(sl.value / max_val) else 1.0,
                .color = c,
            };
            cur_turn += len_t;
            ai += 1;
        }

        // Physical geometry in cell-width units (`1 col = 1.0`, `1 row = 2.0`).
        const phys_w = @as(f64, @floatFromInt(chart_rect.width));
        const phys_h = @as(f64, @floatFromInt(chart_rect.height)) * 2.0;
        const explode_pad = std.math.clamp(self.explode, 0.0, @min(phys_w, phys_h) * 0.15);
        const radius = @max(1.0, @min(phys_w, phys_h) * 0.47 - explode_pad);
        const donut_frac = std.math.clamp(self.donut_ratio, 0.0, 0.85);
        const guide_c = self.guide_color orelse ui.theme.muted.foreground;

        if (self.pie_char != null or self.marker == .block or self.marker == .dot or self.marker == .bar) {
            try self.renderSymbolMode(ui, chart_rect, arcs, radius, donut_frac, explode_pad, guide_c);
        } else {
            try self.renderPixelGridMode(ui, chart_rect, arcs, radius, donut_frac, explode_pad, guide_c);
        }

        // Draw optional donut / core center label when hollow diameter is sufficient.
        if (self.center_label) |lbl| {
            const has_hole = donut_frac >= 0.25 or self.pie_style == .segmented or self.pie_style == .hud;
            const hole_r = switch (self.pie_style) {
                .segmented => radius * @max(donut_frac, 0.55),
                .hud => @max(0.0, radius - 4.0),
                else => radius * donut_frac,
            };
            const lbl_w = text_root.displayWidth(lbl);
            if (has_hole and lbl_w > 0 and lbl_w <= chart_rect.width and @as(f64, @floatFromInt(lbl_w)) <= hole_r * 2.2) {
                const lx = chart_rect.left() + (chart_rect.width - lbl_w) / 2;
                const ly = chart_rect.top() + chart_rect.height / 2;
                if (ly < chart_rect.bottom()) {
                    const cs = (self.style orelse ui.theme.text).patch(.{ .bold = true });
                    _ = ui.buffer.setStringClipped(lx, ly, lbl, chart_rect.right() -| lx, cs, chart_rect);
                }
            }
        }

        if (!regions.legend.isEmpty()) {
            self.renderLegend(ui, regions.legend, total);
        }
    }

    fn evalPoint(
        self: PieChart,
        dx_in: f64,
        dy_in: f64,
        arcs: []const ArcInfo,
        radius: f64,
        donut_frac: f64,
        explode_pad: f64,
        guide_c: Color,
    ) ?Color {
        switch (self.pie_style) {
            .hud => {
                const dist = @sqrt(dx_in * dx_in + dy_in * dy_in);
                const turn = @mod(std.math.atan2(dx_in, -dy_in) / std.math.tau, 1.0);
                // Outer dial ticks (24 ticks around circumference).
                if (dist <= radius and dist >= radius - 1.1) {
                    const tick_phase = @mod(turn * 24.0, 1.0);
                    if (tick_phase < 0.25) return guide_c;
                    return null;
                }
                const band_out = @max(1.2, radius - 1.5);
                const band_in = @max(0.4, band_out - @max(1.1, radius * 0.28));
                if (dist >= band_in and dist <= band_out) {
                    if (matchSlice(turn, dist, arcs, self.gap)) |c| return c;
                }
                const guide_r = band_in - 1.1;
                if (guide_r >= 1.5 and dist <= guide_r and dist >= guide_r - 0.55) {
                    if (@mod(turn * 18.0, 1.0) < 0.5) return guide_c;
                }
                return null;
            },
            .segmented => {
                const dist = @sqrt(dx_in * dx_in + dy_in * dy_in);
                const inner_r = radius * @max(donut_frac, 0.55);
                if (dist < inner_r or dist > radius) return null;
                const turn = @mod(std.math.atan2(dx_in, -dy_in) / std.math.tau, 1.0);
                const seg_count: f64 = std.math.clamp(@floor(radius * 2.4), 16.0, 48.0);
                if (@mod(turn * seg_count, 1.0) > 0.72) return null;
                return matchSlice(turn, dist, arcs, self.gap);
            },
            .solid, .rose => {
                // Evaluate per-slice so `explode` shifts wedges radially along their center vector cleanly.
                for (arcs) |arc| {
                    var dx = dx_in;
                    var dy = dy_in;
                    if (explode_pad > 0.0 and arc.len_turns < 0.999) {
                        const mid_a = (arc.start_turn + arc.len_turns * 0.5) * std.math.tau;
                        dx -= explode_pad * @sin(mid_a);
                        dy += explode_pad * @cos(mid_a);
                    }
                    const dist = @sqrt(dx * dx + dy * dy);
                    const max_r = if (self.pie_style == .rose) radius * arc.max_rad else radius;
                    const min_r = max_r * donut_frac;
                    if (dist <= max_r and dist >= min_r) {
                        const turn = @mod(std.math.atan2(dx, -dy) / std.math.tau, 1.0);
                        const rel = @mod(turn - arc.start_turn, 1.0);
                        if (rel <= arc.len_turns + 1e-6) {
                            if (inSliceGap(rel, arc.len_turns, dist, self.gap)) continue;
                            return arc.color;
                        }
                    }
                }
                // Faint concentric guide rings for `.rose` polar chart.
                if (self.pie_style == .rose and radius >= 3.0) {
                    const dist = @sqrt(dx_in * dx_in + dy_in * dy_in);
                    const turn = @mod(std.math.atan2(dx_in, -dy_in) / std.math.tau, 1.0);
                    if (@mod(turn * 36.0, 1.0) < 0.35) {
                        for ([_]f64{ 0.333, 0.667, 1.0 }) |ring_f| {
                            const rr = radius * ring_f;
                            if (@abs(dist - rr) <= 0.32) return guide_c;
                        }
                    }
                }
                return null;
            },
        }
    }

    fn renderPixelGridMode(
        self: PieChart,
        ui: *Ui,
        chart_rect: Rect,
        arcs: []const ArcInfo,
        radius: f64,
        donut_frac: f64,
        explode_pad: f64,
        guide_c: Color,
    ) !void {
        var grid = try PixelGrid.init(ui.scratchAllocator(), chart_rect.width, chart_rect.height, self.marker);
        const pw = grid.pixelWidth();
        const ph = grid.pixelHeight();
        if (pw == 0 or ph == 0) return;

        const cx = @as(f64, @floatFromInt(pw)) * 0.5;
        const cy = @as(f64, @floatFromInt(ph)) * 0.5;
        const sx_f: f64 = @floatFromInt(grid.sub_x);
        const sy_f: f64 = @floatFromInt(grid.sub_y);

        var py: usize = 0;
        while (py < ph) : (py += 1) {
            const dy = (((@as(f64, @floatFromInt(py)) + 0.5) - cy) / sy_f) * 2.0;
            var px: usize = 0;
            while (px < pw) : (px += 1) {
                const dx = ((@as(f64, @floatFromInt(px)) + 0.5) - cx) / sx_f;
                if (self.evalPoint(dx, dy, arcs, radius, donut_frac, explode_pad, guide_c)) |c| {
                    grid.paintPixel(px, py, c);
                }
            }
        }
        try grid.flush(ui, chart_rect);
    }

    fn renderSymbolMode(
        self: PieChart,
        ui: *Ui,
        chart_rect: Rect,
        arcs: []const ArcInfo,
        radius: f64,
        donut_frac: f64,
        explode_pad: f64,
        guide_c: Color,
    ) !void {
        const sym = self.pie_char orelse if (self.marker == .dot) "●" else style_root.symbols.block.full;
        const cx = @as(f64, @floatFromInt(chart_rect.width)) * 0.5;
        const cy = @as(f64, @floatFromInt(chart_rect.height)) * 0.5;

        var row: u16 = 0;
        while (row < chart_rect.height) : (row += 1) {
            const dy = (@as(f64, @floatFromInt(row)) + 0.5 - cy) * 2.0;
            var col: u16 = 0;
            while (col < chart_rect.width) : (col += 1) {
                const dx = @as(f64, @floatFromInt(col)) + 0.5 - cx;
                if (self.evalPoint(dx, dy, arcs, radius, donut_frac, explode_pad, guide_c)) |c| {
                    _ = ui.buffer.setStringClipped(
                        chart_rect.left() + col,
                        chart_rect.top() + row,
                        sym,
                        1,
                        .{ .foreground = c },
                        chart_rect,
                    );
                }
            }
        }
    }

    fn renderLegend(self: PieChart, ui: *Ui, legend_area: Rect, total: f64) void {
        var entry_buf: [96]u8 = undefined;
        const base_style = self.style orelse ui.theme.text;

        switch (self.legend_layout) {
            .vertical => {
                var row: u16 = 0;
                for (self.slices, 0..) |sl, idx| {
                    if (row >= legend_area.height) break;
                    const c = sl.color orelse default_slice_colors[idx % default_slice_colors.len];
                    const txt = self.formatEntry(sl, total, &entry_buf);
                    const w = @min(legend_area.width, text_root.displayWidth(txt));
                    const lx = alignedX(legend_area, w, self.legend_alignment);
                    const gy = legend_area.top() + row;
                    const marker_w = text_root.displayWidth(self.legend_marker);
                    const pos = ui.buffer.setStringClipped(lx, gy, self.legend_marker, marker_w, .{ .foreground = c }, legend_area);
                    const rest = if (txt.len > self.legend_marker.len) txt[self.legend_marker.len..] else "";
                    _ = ui.buffer.setStringClipped(pos.x, gy, rest, legend_area.right() -| pos.x, base_style, legend_area);
                    row += 1;
                }
            },
            .horizontal => {
                var total_w: u16 = 0;
                for (self.slices, 0..) |sl, idx| {
                    const txt = self.formatEntry(sl, total, &entry_buf);
                    if (idx > 0) total_w +|= 2;
                    total_w +|= text_root.displayWidth(txt);
                }
                var cx = alignedX(legend_area, @min(legend_area.width, total_w), self.legend_alignment);
                const gy = legend_area.top();
                const marker_w = text_root.displayWidth(self.legend_marker);
                for (self.slices, 0..) |sl, idx| {
                    if (idx > 0) cx +|= 2;
                    if (cx >= legend_area.right()) break;
                    const c = sl.color orelse default_slice_colors[idx % default_slice_colors.len];
                    const txt = self.formatEntry(sl, total, &entry_buf);
                    const pos = ui.buffer.setStringClipped(cx, gy, self.legend_marker, marker_w, .{ .foreground = c }, legend_area);
                    const rest = if (txt.len > self.legend_marker.len) txt[self.legend_marker.len..] else "";
                    const end_pos = ui.buffer.setStringClipped(pos.x, gy, rest, legend_area.right() -| pos.x, base_style, legend_area);
                    cx = end_pos.x;
                }
            },
        }
    }
};

fn alignedX(area: Rect, content_w: u16, alignment: Alignment) u16 {
    return switch (alignment) {
        .left => area.left(),
        .center => area.left() + (area.width -| content_w) / 2,
        .right => area.left() + (area.width -| content_w),
    };
}

fn inSliceGap(rel_turn: f64, len_turns: f64, dist: f64, gap: f64) bool {
    if (gap <= 0.0 or len_turns >= 0.999 or dist <= 0.01) return false;
    const half = gap * 0.5;
    const arc_len = len_turns * std.math.tau * dist;
    const along = (rel_turn / len_turns) * arc_len;
    return along < half or (arc_len - along) < half;
}

fn matchSlice(turn: f64, dist: f64, arcs: []const ArcInfo, gap: f64) ?Color {
    for (arcs) |arc| {
        const rel = @mod(turn - arc.start_turn, 1.0);
        if (rel <= arc.len_turns + 1e-6) {
            if (inSliceGap(rel, arc.len_turns, dist, gap)) return null;
            return arc.color;
        }
    }
    return null;
}

test "pie and donut chart render cleanly inside compact and wide bounds" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 26, 9));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    try ui.renderWidget(PieChart{
        .slices = &.{
            .{ .label = "API", .value = 50 },
            .{ .label = "DB", .value = 30 },
            .{ .label = "Cache", .value = 20 },
        },
        .donut_ratio = 0.5,
        .center_label = "100%",
        .block = .{ .title = "Traffic Share" },
    }, buf.area);

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Traffic Share") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "API") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "50%") != null);

    // Ensure segmented, HUD, rose, and bottom horizontal legend render cleanly.
    for ([_]PieStyle{ .segmented, .hud, .rose }) |ps| {
        buf.clear();
        try ui.renderWidget(PieChart{
            .slices = &.{
                .{ .label = "A", .value = 60 },
                .{ .label = "B", .value = 40 },
            },
            .pie_style = ps,
            .legend_position = .bottom,
            .legend_layout = .horizontal,
            .legend_alignment = .center,
            .marker = .braille,
        }, buf.area);
    }
}
