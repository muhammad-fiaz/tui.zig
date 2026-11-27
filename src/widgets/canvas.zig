//! High-resolution vector & pixel `Canvas` widget supporting Braille (2x4),
//! Quadrant (2x2), HalfBlock (1x2), Dot, and Block markers.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Ui = core_root.Ui;
pub const Color = style_root.Color;
pub const Style = style_root.Style;
pub const Marker = style_root.Marker;
pub const symbols = style_root.symbols;
pub const Block = block_mod.Block;

/// Axis bounds for mapping floating-point world coordinates onto grid pixels.
pub const Bounds = struct {
    min: f64,
    max: f64,

    pub fn span(self: Bounds) f64 {
        const s = self.max - self.min;
        return if (s <= 0.0) 1.0 else s;
    }
};

/// Floating-point world coordinate `(x, y)` passed to `Painter` and shape primitives.
pub const Point = struct {
    x: f64,
    y: f64,
};

/// Sub-cell pixel grid backed by the per-frame `scratch` arena (zero steady-state allocations).
pub const PixelGrid = struct {
    cell_width: u16,
    cell_height: u16,
    sub_x: u16,
    sub_y: u16,
    marker: Marker,
    /// Flat per-cell pixel bitmask (for Braille / Quadrant / HalfBlock) or 0/1 dot presence.
    masks: []u8,
    /// Per-cell primary foreground color (`inherit` = not painted).
    colors: []Color,
    /// Secondary bottom-half color for `.half_block` mode (allows dual vertical colors per cell!).
    secondary_colors: []Color,

    pub fn init(alloc: std.mem.Allocator, cell_w: u16, cell_h: u16, marker: Marker) !PixelGrid {
        const count = @as(usize, cell_w) * @as(usize, cell_h);
        const sub: struct { u16, u16 } = switch (marker) {
            .braille => .{ 2, 4 },
            .quadrant => .{ 2, 2 },
            .half_block => .{ 1, 2 },
            .dot, .block, .bar => .{ 1, 1 },
        };
        const masks = try alloc.alloc(u8, count);
        @memset(masks, 0);
        const colors = try alloc.alloc(Color, count);
        @memset(colors, .inherit);
        const sec = try alloc.alloc(Color, count);
        @memset(sec, .inherit);

        return .{
            .cell_width = cell_w,
            .cell_height = cell_h,
            .sub_x = sub[0],
            .sub_y = sub[1],
            .marker = marker,
            .masks = masks,
            .colors = colors,
            .secondary_colors = sec,
        };
    }

    pub fn pixelWidth(self: *const PixelGrid) usize {
        return @as(usize, self.cell_width) * self.sub_x;
    }

    pub fn pixelHeight(self: *const PixelGrid) usize {
        return @as(usize, self.cell_height) * self.sub_y;
    }

    /// Lights sub-pixel `(px, py)` (where `py = 0` is top pixel row) with `color`.
    pub fn paintPixel(self: *PixelGrid, px: usize, py: usize, color: Color) void {
        if (px >= self.pixelWidth() or py >= self.pixelHeight()) return;
        const cx = px / self.sub_x;
        const cy = py / self.sub_y;
        const sx = px % self.sub_x;
        const sy = py % self.sub_y;
        const idx = cy * @as(usize, self.cell_width) + cx;

        switch (self.marker) {
            .braille => {
                self.masks[idx] |= symbols.braille_dot_bits[sy][sx];
                self.colors[idx] = color;
            },
            .quadrant => {
                const bit: u8 = @as(u8, 1) << @intCast(3 - (sy * 2 + sx));
                self.masks[idx] |= bit;
                self.colors[idx] = color;
            },
            .half_block => {
                if (sy == 0) {
                    self.masks[idx] |= 0b01;
                    self.colors[idx] = color;
                } else {
                    self.masks[idx] |= 0b10;
                    self.secondary_colors[idx] = color;
                }
            },
            .dot, .block, .bar => {
                self.masks[idx] = 1;
                self.colors[idx] = color;
            },
        }
    }

    /// Flushes non-empty pixels into `ui.buffer` starting at `(inner.left(), inner.top())`.
    pub fn flush(self: *const PixelGrid, ui: *Ui, inner: Rect) !void {
        var braille_tmp: [3]u8 = undefined;
        var cy: u16 = 0;
        while (cy < self.cell_height) : (cy += 1) {
            var cx: u16 = 0;
            while (cx < self.cell_width) : (cx += 1) {
                const idx = @as(usize, cy) * @as(usize, self.cell_width) + cx;
                const mask = self.masks[idx];
                if (mask == 0) continue;

                const cell = ui.buffer.getMut(inner.left() + cx, inner.top() + cy) orelse continue;
                switch (self.marker) {
                    .braille => {
                        const sym = symbols.encodeBrailleMask(mask, &braille_tmp);
                        try ui.buffer.setCellSymbol(cell, sym);
                        cell.setStyle(.{ .foreground = self.colors[idx] });
                    },
                    .quadrant => {
                        try ui.buffer.setCellSymbol(cell, symbols.quadrants[mask & 0x0F]);
                        cell.setStyle(.{ .foreground = self.colors[idx] });
                    },
                    .half_block => {
                        if (mask == 0b11) {
                            try ui.buffer.setCellSymbol(cell, "▀");
                            cell.setStyle(.{
                                .foreground = self.colors[idx],
                                .background = self.secondary_colors[idx],
                            });
                        } else if (mask == 0b01) {
                            try ui.buffer.setCellSymbol(cell, "▀");
                            cell.setStyle(.{ .foreground = self.colors[idx] });
                        } else {
                            try ui.buffer.setCellSymbol(cell, "▄");
                            cell.setStyle(.{ .foreground = self.secondary_colors[idx] });
                        }
                    },
                    .dot => {
                        try ui.buffer.setCellSymbol(cell, "•");
                        cell.setStyle(.{ .foreground = self.colors[idx] });
                    },
                    .block => {
                        try ui.buffer.setCellSymbol(cell, symbols.block.full);
                        cell.setStyle(.{ .foreground = self.colors[idx] });
                    },
                    .bar => {
                        try ui.buffer.setCellSymbol(cell, symbols.block.half);
                        cell.setStyle(.{ .foreground = self.colors[idx] });
                    },
                }
                cell.diff_option = .none;
            }
        }
    }
};

/// Floating-point coordinate painter passed to `Canvas` callbacks.
pub const Painter = struct {
    grid: *PixelGrid,
    x_bounds: Bounds,
    y_bounds: Bounds,
    ui: *Ui,
    inner: Rect,

    /// Converts world `(x, y)` (Cartesian: `+y` is up!) to sub-pixel coordinates, returning `null` if out of bounds.
    pub fn toPixel(self: *const Painter, x: f64, y: f64) ?struct { usize, usize } {
        if (x < self.x_bounds.min or x > self.x_bounds.max or y < self.y_bounds.min or y > self.y_bounds.max) {
            return null;
        }
        const pw = self.grid.pixelWidth();
        const ph = self.grid.pixelHeight();
        if (pw == 0 or ph == 0) return null;

        const nx = (x - self.x_bounds.min) / self.x_bounds.span();
        const ny = (self.y_bounds.max - y) / self.y_bounds.span();
        const px: usize = @min(pw - 1, @as(usize, @intFromFloat(@round(nx * @as(f64, @floatFromInt(pw - 1))))));
        const py: usize = @min(ph - 1, @as(usize, @intFromFloat(@round(ny * @as(f64, @floatFromInt(ph - 1))))));
        return .{ px, py };
    }

    /// Plots a single point in world coordinates.
    pub fn point(self: *Painter, x: f64, y: f64, color: Color) void {
        if (self.toPixel(x, y)) |p| {
            self.grid.paintPixel(p[0], p[1], color);
        }
    }

    /// Draws an integer Bresenham line between two world points.
    pub fn line(self: *Painter, x1: f64, y1: f64, x2: f64, y2: f64, color: Color) void {
        const pw = @as(f64, @floatFromInt(@max(1, self.grid.pixelWidth() -| 1)));
        const ph = @as(f64, @floatFromInt(@max(1, self.grid.pixelHeight() -| 1)));

        const px1: isize = @intFromFloat(@round(((x1 - self.x_bounds.min) / self.x_bounds.span()) * pw));
        const py1: isize = @intFromFloat(@round(((self.y_bounds.max - y1) / self.y_bounds.span()) * ph));
        const px2: isize = @intFromFloat(@round(((x2 - self.x_bounds.min) / self.x_bounds.span()) * pw));
        const py2: isize = @intFromFloat(@round(((self.y_bounds.max - y2) / self.y_bounds.span()) * ph));

        self.drawPixelLine(px1, py1, px2, py2, color);
    }

    /// Draws an axis-aligned rectangle outline (or filled box when `filled = true`).
    pub fn rectangle(self: *Painter, x: f64, y: f64, width: f64, height: f64, color: Color, filled: bool) void {
        if (!filled) {
            self.line(x, y, x + width, y, color);
            self.line(x + width, y, x + width, y + height, color);
            self.line(x + width, y + height, x, y + height, color);
            self.line(x, y + height, x, y, color);
            return;
        }
        const pw = @as(f64, @floatFromInt(@max(1, self.grid.pixelWidth() -| 1)));
        const ph = @as(f64, @floatFromInt(@max(1, self.grid.pixelHeight() -| 1)));
        const x0: isize = @intFromFloat(@round(((x - self.x_bounds.min) / self.x_bounds.span()) * pw));
        const x1: isize = @intFromFloat(@round(((x + width - self.x_bounds.min) / self.x_bounds.span()) * pw));
        const y_top: isize = @intFromFloat(@round(((self.y_bounds.max - (y + height)) / self.y_bounds.span()) * ph));
        const y_bot: isize = @intFromFloat(@round(((self.y_bounds.max - y) / self.y_bounds.span()) * ph));

        var py = @max(@as(isize, 0), y_top);
        while (py <= @min(@as(isize, @intCast(self.grid.pixelHeight() -| 1)), y_bot)) : (py += 1) {
            var px = @max(@as(isize, 0), x0);
            while (px <= @min(@as(isize, @intCast(self.grid.pixelWidth() -| 1)), x1)) : (px += 1) {
                self.grid.paintPixel(@intCast(px), @intCast(py), color);
            }
        }
    }

    /// Draws a circle outline centered at `(cx, cy)` with world `radius`.
    pub fn circle(self: *Painter, cx: f64, cy: f64, radius: f64, color: Color) void {
        const steps: usize = 64;
        var prev_x = cx + radius;
        var prev_y = cy;
        for (1..steps + 1) |i| {
            const angle = (@as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(steps))) * std.math.tau;
            const nx = cx + radius * @cos(angle);
            const ny = cy + radius * @sin(angle);
            self.line(prev_x, prev_y, nx, ny, color);
            prev_x = nx;
            prev_y = ny;
        }
    }

    /// Draws connected line segments through `pts`.
    pub fn polyline(self: *Painter, pts: []const Point, color: Color) void {
        if (pts.len == 0) return;
        if (pts.len == 1) {
            self.point(pts[0].x, pts[0].y, color);
            return;
        }
        for (0..pts.len - 1) |i| {
            self.line(pts[i].x, pts[i].y, pts[i + 1].x, pts[i + 1].y, color);
        }
    }

    /// Draws a closed polygon connecting `pts[0..n-1]` and closing back to `pts[0]`.
    pub fn polygon(self: *Painter, pts: []const Point, color: Color) void {
        if (pts.len == 0) return;
        self.polyline(pts, color);
        if (pts.len >= 3) {
            self.line(pts[pts.len - 1].x, pts[pts.len - 1].y, pts[0].x, pts[0].y, color);
        }
    }

    /// Draws a dotted/dashed segment between two world coordinates.
    pub fn dashedLine(self: *Painter, x1: f64, y1: f64, x2: f64, y2: f64, segments: usize, color: Color) void {
        const segs = @max(@as(usize, 1), segments);
        var i: usize = 0;
        while (i < segs) : (i += 2) {
            const t0 = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(segs));
            const t1 = @min(1.0, @as(f64, @floatFromInt(i + 1)) / @as(f64, @floatFromInt(segs)));
            self.line(
                x1 + (x2 - x1) * t0,
                y1 + (y2 - y1) * t0,
                x1 + (x2 - x1) * t1,
                y1 + (y2 - y1) * t1,
                color,
            );
        }
    }

    /// Draws an ASCII/UTF-8 text label overlaid directly in cell coordinates matching `(x, y)`.
    pub fn text(self: *Painter, x: f64, y: f64, label: []const u8, style: Style) void {
        const pw = self.grid.pixelWidth();
        const ph = self.grid.pixelHeight();
        if (pw == 0 or ph == 0) return;
        const p = self.toPixel(x, y) orelse return;
        const cell_x = self.inner.left() + @as(u16, @intCast(p[0] / self.grid.sub_x));
        const cell_y = self.inner.top() + @as(u16, @intCast(p[1] / self.grid.sub_y));
        _ = self.ui.buffer.setStringClipped(cell_x, cell_y, label, self.inner.right() -| cell_x, style, self.inner);
    }

    fn drawPixelLine(self: *Painter, x0_in: isize, y0_in: isize, x1_in: isize, y1_in: isize, color: Color) void {
        var x0 = x0_in;
        var y0 = y0_in;
        const dx: isize = @intCast(@abs(x1_in - x0_in));
        const sx: isize = if (x0_in < x1_in) 1 else -1;
        const dy: isize = -@as(isize, @intCast(@abs(y1_in - y0_in)));
        const sy: isize = if (y0_in < y1_in) 1 else -1;
        var err = dx + dy;

        while (true) {
            if (x0 >= 0 and y0 >= 0) {
                self.grid.paintPixel(@intCast(x0), @intCast(y0), color);
            }
            if (x0 == x1_in and y0 == y1_in) break;
            const e2 = 2 * err;
            if (e2 >= dy) {
                err += dy;
                x0 += sx;
            }
            if (e2 <= dx) {
                err += dx;
                y0 += sy;
            }
        }
    }
};

/// Tagged shape primitive usable directly in `Canvas` without writing a custom callback.
pub const Shape = union(enum) {
    line: struct { x1: f64, y1: f64, x2: f64, y2: f64, color: Color },
    rect: struct { x: f64, y: f64, width: f64, height: f64, color: Color, filled: bool = false },
    circle: struct { x: f64, y: f64, radius: f64, color: Color },
    points: struct { coords: []const Point, color: Color },
    polyline: struct { coords: []const Point, color: Color },
};

/// Declarative or callback-driven high-resolution vector canvas widget.
pub const Canvas = struct {
    x_bounds: Bounds = .{ .min = 0.0, .max = 100.0 },
    y_bounds: Bounds = .{ .min = 0.0, .max = 100.0 },
    marker: Marker = .braille,
    block: ?Block = null,
    background_color: Color = .inherit,
    shapes: []const Shape = &.{},

    /// Renders `self.shapes` into `ui` within `area`.
    pub fn render(self: Canvas, ui: *Ui, area: Rect) !void {
        try self.paintWith(ui, area, {}, struct {
            fn noop(_: void, _: *Painter) void {}
        }.noop);
    }

    /// Renders `self.shapes` followed by caller `draw_fn(ctx, *Painter)` for custom procedural drawing.
    pub fn paintWith(self: Canvas, ui: *Ui, area: Rect, ctx: anytype, comptime draw_fn: anytype) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        if (!self.background_color.isInherit()) {
            ui.buffer.fill(inner, " ", .{ .background = self.background_color });
        }

        var grid = try PixelGrid.init(ui.scratchAllocator(), inner.width, inner.height, self.marker);
        var painter = Painter{
            .grid = &grid,
            .x_bounds = self.x_bounds,
            .y_bounds = self.y_bounds,
            .ui = ui,
            .inner = inner,
        };

        for (self.shapes) |sh| {
            switch (sh) {
                .line => |l| painter.line(l.x1, l.y1, l.x2, l.y2, l.color),
                .rect => |r| painter.rectangle(r.x, r.y, r.width, r.height, r.color, r.filled),
                .circle => |c| painter.circle(c.x, c.y, c.radius, c.color),
                .points => |ps| {
                    for (ps.coords) |pt| painter.point(pt.x, pt.y, ps.color);
                },
                .polyline => |pl| painter.polyline(pl.coords, pl.color),
            }
        }

        // Flush pixels before text overlays so text labels stay crisp on top of shapes.
        draw_fn(ctx, &painter);
        try grid.flush(ui, inner);
    }
};

test "canvas renders braille lines and shapes cleanly inside bounds" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 20, 10));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    const shapes = [_]Shape{
        .{ .line = .{ .x1 = 0, .y1 = 0, .x2 = 100, .y2 = 100, .color = .cyan } },
        .{ .circle = .{ .x = 50, .y = 50, .radius = 30, .color = .yellow } },
    };
    const c = Canvas{ .shapes = &shapes, .marker = .braille, .block = .{ .title = "Draw" } };
    try ui.renderWidget(c, buf.area);

    // At least one Braille character U+28xx should have been drawn inside plot area.
    var found_braille = false;
    for (1..9) |y| {
        for (1..19) |x| {
            const sym = buf.get(@intCast(x), @intCast(y)).?.symbol();
            if (sym.len == 3 and sym[0] == 0xE2 and sym[1] == 0xA0) found_braille = true;
        }
    }
    try testing.expect(found_braille);
}
