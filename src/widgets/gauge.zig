//! Progress and activity indicators: `Gauge`, `LineGauge`, `ProgressBar`, and `Spinner`.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Buffer = core_root.Buffer;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const LineSet = style_root.LineSet;
pub const Block = block_mod.Block;
pub const symbols = style_root.symbols;

/// Horizontal smooth progress bar using 1/8th Unicode blocks and contrast-aware centered label.
pub const Gauge = struct {
    /// Progress fraction in `[0.0, 1.0]`. Ignored when `percent != null`.
    ratio: f64 = 0.0,
    /// Optional integer percentage `[0..100]` overriding `ratio`.
    percent: ?u8 = null,
    /// Optional custom label overriding automatic `"XX%"` label.
    label: ?[]const u8 = null,
    /// Optional surrounding `Block`.
    block: ?Block = null,
    /// Unfilled track style.
    style: ?Style = null,
    /// Filled bar style (`theme.accent` foreground/background inverted cleanly).
    gauge_style: ?Style = null,
    /// Use 1/8th horizontal fractional blocks for sub-cell precision.
    use_unicode: bool = true,

    /// Returns clamped `[0.0, 1.0]` completion fraction.
    pub fn normalizedRatio(self: Gauge) f64 {
        const raw = if (self.percent) |p| @as(f64, @floatFromInt(@min(p, 100))) / 100.0 else self.ratio;
        if (std.math.isNan(raw)) return 0.0;
        return std.math.clamp(raw, 0.0, 1.0);
    }

    /// Renders this gauge onto `ui` within `area`.
    pub fn render(self: Gauge, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        const r = self.normalizedRatio();
        const track_style = self.style orelse ui.theme.surface;
        const fill_fg = if (self.gauge_style) |gs|
            if (!gs.foreground.isInherit()) gs.foreground else if (!gs.background.isInherit()) gs.background else ui.theme.accent.foreground
        else
            ui.theme.accent.foreground;
        const fill_bar_style = Style{ .foreground = fill_fg, .background = track_style.background };
        const filled_label_style = Style{
            .foreground = if (!ui.theme.surface.background.isInherit()) ui.theme.surface.background else .black,
            .background = fill_fg,
            .bold = true,
        };
        const unfilled_label_style = Style{
            .foreground = if (!track_style.foreground.isInherit()) track_style.foreground else ui.theme.text.foreground,
            .background = track_style.background,
            .bold = true,
        };

        var label_buf: [32]u8 = undefined;
        const text = self.label orelse std.fmt.bufPrint(&label_buf, "{d}%", .{@as(u16, @intFromFloat(@round(r * 100.0)))}) catch "0%";

        const total_eighths: usize = @intFromFloat(@round(r * @as(f64, @floatFromInt(inner.width)) * 8.0));
        const full_cols: u16 = @intCast(total_eighths / 8);
        const rem_eighths: usize = total_eighths % 8;

        const label_y = inner.top() + inner.height / 2;
        const label_w = text_root.displayWidth(text);
        const label_x = inner.left() + (inner.width -| label_w) / 2;

        var row: u16 = inner.top();
        while (row < inner.bottom()) : (row += 1) {
            var col_idx: u16 = 0;
            while (col_idx < inner.width) : (col_idx += 1) {
                const gx = inner.left() + col_idx;
                if (ui.buffer.getMut(gx, row)) |cell| {
                    if (col_idx < full_cols) {
                        try ui.buffer.setCellSymbol(cell, symbols.block.full);
                        cell.setStyle(fill_bar_style);
                    } else if (col_idx == full_cols and rem_eighths > 0 and self.use_unicode) {
                        try ui.buffer.setCellSymbol(cell, symbols.block.horizontal_eighths[rem_eighths]);
                        cell.setStyle(fill_bar_style);
                    } else {
                        try ui.buffer.setCellSymbol(cell, " ");
                        cell.setStyle(track_style);
                    }
                    cell.diff_option = .none;
                }
            }
        }

        // Overlay label centered horizontally while preserving legible contrast over filled/unfilled halves.
        if (label_w > 0) {
            var git = text_root.GraphemeIterator.init(text);
            var lx = label_x;
            while (git.next()) |g| {
                if (g.width == 0) continue;
                if (lx >= inner.right()) break;
                const rel_col = lx - inner.left();
                const in_filled = rel_col < full_cols or (rel_col == full_cols and rem_eighths >= 4);
                const ch_style = if (in_filled) filled_label_style else unfilled_label_style;
                lx = ui.buffer.setStringClipped(lx, label_y, g.slice, g.width, ch_style, inner).x;
            }
        }
    }
};

/// Compact single-line horizontal progress meter.
pub const LineGauge = struct {
    ratio: f64 = 0.0,
    label: ?[]const u8 = null,
    block: ?Block = null,
    style: ?Style = null,
    filled_style: ?Style = null,
    unfilled_style: ?Style = null,
    line_set: LineSet = symbols.line.thick,

    /// Renders the line gauge into `ui.buffer` within `area`.
    pub fn render(self: LineGauge, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        const r = if (std.math.isNan(self.ratio)) 0.0 else std.math.clamp(self.ratio, 0.0, 1.0);
        const y = inner.top() + inner.height / 2;
        const filled_s = self.filled_style orelse ui.theme.accent;
        const unfilled_s = self.unfilled_style orelse ui.theme.muted;

        var label_buf: [32]u8 = undefined;
        const lbl = self.label orelse std.fmt.bufPrint(&label_buf, "{d}% ", .{@as(u16, @intFromFloat(@round(r * 100.0)))}) catch "";
        const lbl_w = @min(text_root.displayWidth(lbl), inner.width);

        var start_x = inner.left();
        if (lbl_w > 0) {
            const lbl_s = self.style orelse ui.theme.text;
            start_x = ui.buffer.setStringClipped(start_x, y, lbl, lbl_w, lbl_s, inner).x;
        }
        const bar_w = inner.right() -| start_x;
        const filled_cols: u16 = @intFromFloat(@round(r * @as(f64, @floatFromInt(bar_w))));

        var i: u16 = 0;
        while (i < bar_w) : (i += 1) {
            if (ui.buffer.getMut(start_x + i, y)) |cell| {
                try ui.buffer.setCellSymbol(cell, self.line_set.horizontal);
                cell.diff_option = .none;
                cell.setStyle(if (i < filled_cols) filled_s else unfilled_s);
            }
        }
    }
};

/// Ergonomic progress indicator supporting both determinate percentages and animated indeterminate mode.
pub const ProgressBar = struct {
    ratio: f64 = 0.0,
    label: ?[]const u8 = null,
    indeterminate: bool = false,
    tick: u64 = 0,
    show_percentage: bool = true,
    block: ?Block = null,
    filled_style: ?Style = null,
    track_style: ?Style = null,

    /// Renders either determinate sub-cell bar or bouncing indeterminate pulse.
    pub fn render(self: ProgressBar, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        if (!self.indeterminate) {
            var pct_buf: [16]u8 = undefined;
            const pct_text: []const u8 = if (self.show_percentage)
                std.fmt.bufPrint(&pct_buf, " {d}%", .{@as(u16, @intFromFloat(@round(std.math.clamp(self.ratio, 0.0, 1.0) * 100.0)))}) catch ""
            else
                "";

            const y = inner.top();
            const label_prefix = self.label orelse "";
            const prefix_w = @min(text_root.displayWidth(label_prefix), inner.width / 2);
            var bar_start = inner.left();
            if (prefix_w > 0) {
                bar_start = ui.buffer.setStringClipped(bar_start, y, label_prefix, prefix_w, ui.theme.text, inner).x;
                if (bar_start < inner.right()) {
                    _ = ui.buffer.setStringClipped(bar_start, y, " ", 1, ui.theme.text, inner);
                    bar_start += 1;
                }
            }
            const pct_w = text_root.displayWidth(pct_text);
            const bar_end = inner.right() -| pct_w;
            if (bar_end > bar_start) {
                const sub_g = Gauge{
                    .ratio = self.ratio,
                    .label = "",
                    .gauge_style = self.filled_style orelse ui.theme.accent,
                    .style = self.track_style orelse ui.theme.muted,
                };
                try sub_g.render(ui, Rect.init(bar_start, y, bar_end - bar_start, 1));
            }
            if (pct_w > 0 and bar_end < inner.right()) {
                _ = ui.buffer.setStringClipped(bar_end, y, pct_text, pct_w, ui.theme.text, inner);
            }
            return;
        }

        // Indeterminate ping-pong window.
        const y = inner.top();
        const w = inner.width;
        const pulse_w: u16 = @max(1, @min(6, w / 4));
        const travel = @max(1, w -| pulse_w);
        const phase = self.tick % (@as(u64, travel) * 2);
        const pulse_start: u16 = @intCast(if (phase <= travel) phase else (@as(u64, travel) * 2 - phase));

        const fill_s = self.filled_style orelse ui.theme.accent;
        const track_s = self.track_style orelse ui.theme.muted;
        var col: u16 = 0;
        while (col < w) : (col += 1) {
            if (ui.buffer.getMut(inner.left() + col, y)) |cell| {
                const active = col >= pulse_start and col < pulse_start + pulse_w;
                try ui.buffer.setCellSymbol(cell, if (active) symbols.block.full else symbols.line.normal.horizontal);
                cell.diff_option = .none;
                cell.setStyle(if (active) fill_s else track_s);
            }
        }
    }
};

/// Tick-driven terminal spinner with optional status label.
pub const Spinner = struct {
    tick: u64 = 0,
    label: ?[]const u8 = null,
    frames: []const []const u8 = &symbols.spinner.dots,
    style: ?Style = null,
    label_style: ?Style = null,

    /// Renders the active frame glyph and optional label at row 0 of `area`.
    pub fn render(self: Spinner, ui: *Ui, area: Rect) void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty() or self.frames.len == 0) return;

        const frame_idx: usize = @intCast(self.tick % self.frames.len);
        const frame_sym = self.frames[frame_idx];
        const sp_style = self.style orelse ui.theme.accent;
        var pos = ui.buffer.setStringClipped(bounds.x, bounds.y, frame_sym, bounds.width, sp_style, bounds);

        if (self.label) |lbl| {
            if (lbl.len > 0 and pos.x + 1 < bounds.right()) {
                pos = ui.buffer.setStringClipped(pos.x, bounds.y, " ", 1, sp_style, bounds);
                const lbl_s = self.label_style orelse ui.theme.text;
                _ = ui.buffer.setStringClipped(pos.x, bounds.y, lbl, bounds.right() - pos.x, lbl_s, bounds);
            }
        }
    }
};

test "gauge, line gauge, progress bar, and spinner render accurately" {
    const alloc = testing.allocator;
    var buf = try Buffer.init(alloc, Rect.init(0, 0, 24, 5));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    try ui.renderWidget(Gauge{ .ratio = 0.5 }, Rect.init(0, 0, 20, 1));
    try ui.renderWidget(LineGauge{ .ratio = 0.75, .label = "DL " }, Rect.init(0, 1, 20, 1));
    try ui.renderWidget(ProgressBar{ .indeterminate = true, .tick = 3 }, Rect.init(0, 2, 16, 1));
    try ui.renderWidget(Spinner{ .tick = 1, .label = "Loading" }, Rect.init(0, 3, 20, 1));

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "50%") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "DL ") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "Loading") != null);
}
