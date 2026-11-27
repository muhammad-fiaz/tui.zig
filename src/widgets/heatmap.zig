//! 2D intensity matrix `Heatmap` visualization widget with multi-stop color gradients and labels.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Ui = core_root.Ui;
pub const Color = style_root.Color;
pub const Block = block_mod.Block;

/// 2D intensity matrix / heatmap with multi-stop color interpolation and row/column axis labels.
pub const Heatmap = struct {
    rows: usize = 0,
    cols: usize = 0,
    values: []const f64 = &.{},
    row_labels: []const []const u8 = &.{},
    col_labels: []const []const u8 = &.{},
    min: ?f64 = null,
    max: ?f64 = null,
    low_color: Color = style_root.palette.slate.c800,
    mid_color: ?Color = style_root.palette.amber.c500,
    high_color: Color = style_root.palette.emerald.c400,
    cell_width: u16 = 3,
    show_values: bool = false,
    show_scale: bool = true,
    block: ?Block = null,

    fn sampleColor(self: Heatmap, t_in: f64) Color {
        const t = std.math.clamp(t_in, 0.0, 1.0);
        if (self.mid_color) |mid| {
            if (t < 0.5) return self.low_color.mix(mid, t * 2.0);
            return mid.mix(self.high_color, (t - 0.5) * 2.0);
        }
        return self.low_color.mix(self.high_color, t);
    }

    pub fn render(self: Heatmap, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty() or self.rows == 0 or self.cols == 0) return;

        var min_v: f64 = self.min orelse std.math.floatMax(f64);
        var max_v: f64 = self.max orelse -std.math.floatMax(f64);
        if (self.min == null or self.max == null) {
            for (self.values) |v| {
                if (std.math.isNan(v)) continue;
                if (self.min == null and v < min_v) min_v = v;
                if (self.max == null and v > max_v) max_v = v;
            }
            if (min_v > max_v) {
                min_v = 0.0;
                max_v = 1.0;
            }
        }
        const span = if (max_v > min_v) max_v - min_v else 1.0;

        var row_lbl_w: u16 = 0;
        for (self.row_labels) |rl| row_lbl_w = @max(row_lbl_w, text_root.displayWidth(rl));
        if (row_lbl_w > 0) row_lbl_w = @min(row_lbl_w + 1, inner.width / 3);

        const has_col_hdr = self.col_labels.len > 0 and inner.height >= 2;
        const header_h: u16 = if (has_col_hdr) 1 else 0;
        const scale_h: u16 = if (self.show_scale and inner.height > header_h + 1) 1 else 0;
        const grid_h = inner.height -| header_h -| scale_h;
        const cw = @max(@as(u16, 1), self.cell_width);

        if (has_col_hdr) {
            for (0..self.cols) |c| {
                const cx = inner.left() + row_lbl_w + @as(u16, @intCast(c)) * cw;
                if (cx >= inner.right()) break;
                if (c < self.col_labels.len) {
                    _ = ui.buffer.setStringClipped(cx, inner.top(), self.col_labels[c], @min(cw, inner.right() - cx), ui.theme.muted, inner);
                }
            }
        }

        var val_buf: [16]u8 = undefined;
        var r: usize = 0;
        while (r < self.rows and r < grid_h) : (r += 1) {
            const gy = inner.top() + header_h + @as(u16, @intCast(r));
            if (row_lbl_w > 0 and r < self.row_labels.len) {
                _ = ui.buffer.setStringClipped(inner.left(), gy, self.row_labels[r], row_lbl_w - 1, ui.theme.muted, inner);
            }
            var c: usize = 0;
            while (c < self.cols) : (c += 1) {
                const cx = inner.left() + row_lbl_w + @as(u16, @intCast(c)) * cw;
                if (cx >= inner.right()) break;
                const idx = r * self.cols + c;
                const val = if (idx < self.values.len) self.values[idx] else min_v;
                const norm = if (std.math.isNan(val)) 0.0 else (val - min_v) / span;
                const bg = self.sampleColor(norm);
                const fg: Color = if (norm > 0.65) .black else .white;
                const w = @min(cw, inner.right() - cx);
                ui.buffer.fill(Rect.init(cx, gy, w, 1), " ", .{ .foreground = fg, .background = bg });
                if (self.show_values and w >= 2) {
                    const vs = std.fmt.bufPrint(&val_buf, "{d:.0}", .{val}) catch "";
                    _ = ui.buffer.setStringClipped(cx, gy, vs, w, .{ .foreground = fg, .background = bg, .bold = true }, inner);
                }
            }
        }

        if (scale_h > 0) {
            const sy = inner.bottom() - 1;
            var pos = ui.buffer.setStringClipped(inner.left(), sy, "Low ", inner.width, ui.theme.muted, inner);
            const steps: u16 = @min(@as(u16, 10), inner.right() -| pos.x -| 5);
            var s: u16 = 0;
            while (s < steps) : (s += 1) {
                const t = if (steps <= 1) 1.0 else @as(f64, @floatFromInt(s)) / @as(f64, @floatFromInt(steps - 1));
                pos = ui.buffer.setStringClipped(pos.x, sy, " ", 1, .{ .background = self.sampleColor(t) }, inner);
            }
            _ = ui.buffer.setStringClipped(pos.x, sy, " High", inner.right() -| pos.x, ui.theme.muted, inner);
        }
    }
};

test "heatmap renders gradient cells and headers inside bounds" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 22, 8));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    try ui.renderWidget(Heatmap{
        .rows = 2,
        .cols = 3,
        .values = &.{ 10, 50, 90, 25, 70, 99 },
        .row_labels = &.{ "US", "EU" },
        .col_labels = &.{ "00", "08", "16" },
        .show_values = true,
        .block = .{ .title = "Latency" },
    }, buf.area);

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Latency") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "99") != null);
}
