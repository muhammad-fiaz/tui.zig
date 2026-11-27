//! Utility surface widgets: `Clear`, `Fill`, `Spacer`, and `Divider` (`Separator`).

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Alignment = core_root.Alignment;
pub const Direction = core_root.Direction;
pub const Buffer = core_root.Buffer;
pub const Ui = core_root.Ui;
pub const Cell = core_root.Cell;
pub const Style = style_root.Style;
pub const symbols = style_root.symbols;

/// Resets every cell inside its assigned area to `Cell.empty`.
///
/// Useful before rendering floating overlays, dialogs, menus, or popups so
/// underlying text and borders do not bleed through.
pub const Clear = struct {
    /// Optional style applied after clearing (defaults to unstyled blank spaces).
    style: ?Style = null,

    /// Renders the clear operation onto `ui` within `area`.
    pub fn render(self: Clear, ui: *Ui, area: Rect) void {
        self.renderToBuffer(ui.buffer, area);
    }

    /// Renders directly into a raw `Buffer`.
    pub fn renderToBuffer(self: Clear, buf: *Buffer, area: Rect) void {
        const bounds = area.intersection(buf.area);
        if (bounds.isEmpty()) return;

        var y: u16 = bounds.top();
        while (y < bounds.bottom()) : (y += 1) {
            var x: u16 = bounds.left();
            while (x < bounds.right()) : (x += 1) {
                if (buf.getMut(x, y)) |cell| {
                    cell.reset();
                    if (self.style) |s| cell.setStyle(s);
                }
            }
        }
    }
};

/// Fills an area uniformly with a single symbol and optional `Style`.
pub const Fill = struct {
    symbol: []const u8 = " ",
    style: ?Style = null,

    /// Renders the fill into `ui.buffer`.
    pub fn render(self: Fill, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;
        const resolved = self.style orelse ui.theme.surface;
        ui.buffer.fill(bounds, self.symbol, resolved);
    }
};

/// Flow-layout blank spacer widget (reserves vertical rows without mutating cells).
pub const Spacer = struct {
    rows: u16 = 1,

    pub fn render(self: Spacer, ui: *Ui, area: Rect) void {
        _ = self;
        _ = ui;
        _ = area;
    }
};

/// Horizontal or vertical divider line (`Separator` alias), optionally with an inline title.
pub const Divider = struct {
    direction: Direction = .horizontal,
    label: ?[]const u8 = null,
    label_alignment: Alignment = .center,
    symbol: ?[]const u8 = null,
    style: ?Style = null,
    label_style: ?Style = null,

    /// Renders the divider across `area`.
    pub fn render(self: Divider, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        const line_style = self.style orelse ui.theme.border;
        const text_style = self.label_style orelse ui.theme.muted;

        switch (self.direction) {
            .horizontal => {
                const sym = self.symbol orelse symbols.line.normal.horizontal;
                const y = bounds.y;
                var x = bounds.left();
                while (x < bounds.right()) : (x += 1) {
                    if (ui.buffer.getMut(x, y)) |cell| {
                        try ui.buffer.setCellSymbol(cell, sym);
                        cell.diff_option = .none;
                        cell.setStyle(line_style);
                    }
                }

                if (self.label) |lbl| {
                    if (lbl.len > 0 and bounds.width >= 4) {
                        var padded_buf: [256]u8 = undefined;
                        var text_slice = lbl;
                        if (lbl.len + 2 <= padded_buf.len) {
                            padded_buf[0] = ' ';
                            @memcpy(padded_buf[1 .. 1 + lbl.len], lbl);
                            padded_buf[1 + lbl.len] = ' ';
                            text_slice = padded_buf[0 .. lbl.len + 2];
                        }

                        const w = text_root.displayWidth(text_slice);
                        const draw_w = @min(w, bounds.width);
                        const start_x: u16 = switch (self.label_alignment) {
                            .left => bounds.left() +| 1,
                            .center => bounds.left() + (bounds.width - draw_w) / 2,
                            .right => bounds.right() -| draw_w -| 1,
                        };
                        _ = ui.buffer.setStringClipped(start_x, y, text_slice, draw_w, text_style, bounds);
                    }
                }
            },
            .vertical => {
                const sym = self.symbol orelse symbols.line.normal.vertical;
                const x = bounds.x;
                var y = bounds.top();
                while (y < bounds.bottom()) : (y += 1) {
                    if (ui.buffer.getMut(x, y)) |cell| {
                        try ui.buffer.setCellSymbol(cell, sym);
                        cell.diff_option = .none;
                        cell.setStyle(line_style);
                    }
                }
            },
        }
    }
};

test "clear resets styled cells and divider renders label" {
    const alloc = testing.allocator;
    var buf = try Buffer.init(alloc, Rect.init(0, 0, 20, 3));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    buf.fill(buf.area, "X", .{ .bold = true });
    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    try ui.renderWidget(Clear{}, Rect.init(1, 0, 4, 1));
    try testing.expectEqualStrings(" ", buf.get(1, 0).?.symbol());
    try testing.expectEqualStrings("X", buf.get(0, 0).?.symbol());

    try ui.renderWidget(Divider{ .label = "OR", .label_alignment = .center }, Rect.init(0, 1, 10, 1));
    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "OR") != null);
}
