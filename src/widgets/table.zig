//! Multi-column `Table`, `TableRow`, `TableCell`, and `TableState` with headers,
//! footers, arbitrary `Constraint` column widths, row/column/cell selection, and zebra striping.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const event_root = @import("../event/root.zig");
const block_mod = @import("block.zig");
const list_mod = @import("list.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Alignment = core_root.Alignment;
pub const Constraint = core_root.Constraint;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const Block = block_mod.Block;
pub const HighlightSpacing = list_mod.HighlightSpacing;
pub const Text = text_root.Text;
pub const Line = text_root.Line;
pub const Event = event_root.Event;

/// Single cell inside a `TableRow`.
pub const TableCell = struct {
    raw: ?[]const u8 = null,
    line: ?Line = null,
    text: ?Text = null,
    alignment: Alignment = .left,
    style: ?Style = null,

    pub fn init(raw: []const u8) TableCell {
        return .{ .raw = raw };
    }

    pub fn fromLine(ln: Line) TableCell {
        return .{ .line = ln };
    }

    pub fn fromText(t: Text) TableCell {
        return .{ .text = t };
    }

    pub fn aligned(self: TableCell, a: Alignment) TableCell {
        var copy = self;
        copy.alignment = a;
        return copy;
    }

    pub fn styled(self: TableCell, s: Style) TableCell {
        var copy = self;
        copy.style = s;
        return copy;
    }
};

/// Single row inside a `Table` (supports rich `cells` or plain string slices `raw_cells`).
pub const TableRow = struct {
    cells: []const TableCell = &.{},
    raw_cells: []const []const u8 = &.{},
    height: u16 = 1,
    bottom_margin: u16 = 0,
    style: ?Style = null,

    pub fn init(cells: []const TableCell) TableRow {
        return .{ .cells = cells };
    }

    pub fn fromStrings(cols: []const []const u8) TableRow {
        return .{ .raw_cells = cols };
    }

    pub fn colCount(self: TableRow) usize {
        return if (self.cells.len > 0) self.cells.len else self.raw_cells.len;
    }

    pub fn cellAt(self: TableRow, idx: usize) TableCell {
        if (self.cells.len > 0) return self.cells[idx];
        return .{ .raw = self.raw_cells[idx] };
    }

    pub fn totalHeight(self: TableRow) u16 {
        return self.height +| self.bottom_margin;
    }
};

/// Scroll and row/column selection state for `Table`.
pub const TableState = struct {
    selected: ?usize = null,
    selected_column: ?usize = null,
    offset: usize = 0,

    pub fn select(self: *TableState, row: ?usize) void {
        self.selected = row;
        if (row == null) self.offset = 0;
    }

    pub fn selectNext(self: *TableState, row_count: usize) void {
        if (row_count == 0) return;
        self.selected = if (self.selected) |s| (if (s + 1 >= row_count) 0 else s + 1) else 0;
    }

    pub fn selectPrevious(self: *TableState, row_count: usize) void {
        if (row_count == 0) return;
        self.selected = if (self.selected) |s| (if (s == 0) row_count - 1 else s - 1) else row_count - 1;
    }

    pub fn selectNextColumn(self: *TableState, col_count: usize) void {
        if (col_count == 0) return;
        self.selected_column = if (self.selected_column) |c| (c + 1) % col_count else 0;
    }

    pub fn selectPrevColumn(self: *TableState, col_count: usize) void {
        if (col_count == 0) return;
        self.selected_column = if (self.selected_column) |c| (if (c == 0) col_count - 1 else c - 1) else col_count - 1;
    }

    /// Processes keyboard/mouse input for row (and optional column) selection.
    pub fn handleEvent(
        self: *TableState,
        event: Event,
        row_count: usize,
        col_count: usize,
        viewport_rows: u16,
        body_bounds: Rect,
        focused: bool,
    ) bool {
        if (row_count == 0) return false;
        switch (event) {
            .mouse => |m| {
                if (!m.isInside(body_bounds)) return false;
                if (m.kind == .down and m.button == .left) {
                    const row = self.offset + (m.y - body_bounds.top());
                    if (row < row_count) {
                        self.selected = row;
                        return true;
                    }
                } else if (m.kind == .scroll_up) {
                    self.selectPrevious(row_count);
                    return true;
                } else if (m.kind == .scroll_down) {
                    self.selectNext(row_count);
                    return true;
                }
                return false;
            },
            .key => |k| {
                if (!focused or k.kind == .release) return false;
                const page = @max(@as(usize, 1), viewport_rows);
                switch (k.code) {
                    .down => {
                        self.selectNext(row_count);
                        return true;
                    },
                    .up => {
                        self.selectPrevious(row_count);
                        return true;
                    },
                    .left => {
                        self.selectPrevColumn(col_count);
                        return true;
                    },
                    .right => {
                        self.selectNextColumn(col_count);
                        return true;
                    },
                    .home => {
                        self.selected = 0;
                        return true;
                    },
                    .end => {
                        self.selected = row_count - 1;
                        return true;
                    },
                    .page_down => {
                        self.selected = @min(row_count - 1, (self.selected orelse 0) + page);
                        return true;
                    },
                    .page_up => {
                        self.selected = (self.selected orelse 0) -| page;
                        return true;
                    },
                    .char => |cp| {
                        if (cp == 'j') {
                            self.selectNext(row_count);
                            return true;
                        }
                        if (cp == 'k') {
                            self.selectPrevious(row_count);
                            return true;
                        }
                        return false;
                    },
                    else => return false,
                }
            },
            else => return false,
        }
    }
};

/// Constraint-driven data table supporting sticky header/footer, column gaps, zebra striping,
/// selection styling, and per-frame scratch layout with zero heap churn.
pub const Table = struct {
    rows: []const TableRow = &.{},
    header: ?TableRow = null,
    footer: ?TableRow = null,
    widths: []const Constraint = &.{},
    column_spacing: u16 = 1,
    block: ?Block = null,
    style: ?Style = null,
    header_style: ?Style = null,
    footer_style: ?Style = null,
    striped_style: ?Style = null,
    row_highlight_style: ?Style = null,
    column_highlight_style: ?Style = null,
    cell_highlight_style: ?Style = null,
    highlight_symbol: ?[]const u8 = "▸ ",
    highlight_spacing: HighlightSpacing = .when_selected,
    show_header_separator: bool = false,
    empty_message: ?[]const u8 = null,
    focused: bool = true,

    /// Computes exact rendered body `Rect` inside `area` (after `block`, sticky `header`, and `footer`).
    pub fn bodyRect(self: Table, area: Rect) Rect {
        var inner = if (self.block) |b| b.inner(area) else area;
        if (inner.isEmpty()) return Rect.zero;
        var cur_y = inner.top();
        var avail_h = inner.height;
        if (self.header) |hdr| {
            if (avail_h >= hdr.height) {
                cur_y += hdr.totalHeight();
                avail_h -|= hdr.totalHeight();
                if (self.show_header_separator and avail_h > 0) {
                    cur_y += 1;
                    avail_h -|= 1;
                }
            }
        }
        const footer_h: u16 = if (self.footer) |ftr| @min(avail_h, ftr.height) else 0;
        return Rect.init(inner.left(), cur_y, inner.width, avail_h -| footer_h);
    }

    /// Handles keyboard, wheel, and left-mouse clicks directly inside `area` (honoring `block`, `header`, `footer`, and variable row heights).
    pub fn handleEvent(self: Table, state: *TableState, event: Event, area: Rect) bool {
        if (self.rows.len == 0) return false;
        const body = self.bodyRect(area);
        if (body.isEmpty()) return false;
        var col_count = self.widths.len;
        if (col_count == 0) {
            if (self.header) |h| col_count = @max(col_count, h.colCount());
            for (self.rows) |r| col_count = @max(col_count, r.colCount());
        }
        if (event == .mouse and event.mouse.isLeftClickInside(body)) {
            const rel_y = event.mouse.y - body.top();
            var used: u16 = 0;
            var ri = state.offset;
            while (ri < self.rows.len and used < body.height) : (ri += 1) {
                const rh = self.rows[ri].totalHeight();
                if (rel_y >= used and rel_y < used +| rh) {
                    state.selected = ri;
                    return true;
                }
                used +|= rh;
            }
            return false;
        }
        return state.handleEvent(event, self.rows.len, col_count, body.height, body, self.focused);
    }

    /// Stateless render.
    pub fn render(self: Table, ui: *Ui, area: Rect) !void {
        var st = TableState{};
        try self.renderStateful(ui, area, &st);
    }

    /// Stateful render synchronized with `state` selection and scroll offset.
    pub fn renderStateful(self: Table, ui: *Ui, area: Rect, state: *TableState) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        const base_style = self.style orelse ui.theme.text;
        if (self.style != null) ui.buffer.setStyle(inner, base_style);

        const sym = self.highlight_symbol orelse "";
        const sym_w = text_root.displayWidth(sym);
        const sel_col_reserve: u16 = switch (self.highlight_spacing) {
            .always => sym_w,
            .when_selected => if (state.selected != null) sym_w else 0,
            .never => 0,
        };
        if (inner.width <= sel_col_reserve) return;

        // Compute column count and column layout rectangles in scratch arena (zero heap churn).
        var col_count = self.widths.len;
        if (col_count == 0) {
            if (self.header) |h| col_count = @max(col_count, h.colCount());
            for (self.rows) |r| col_count = @max(col_count, r.colCount());
        }
        if (col_count == 0) return;

        const scratch = ui.scratchAllocator();
        const col_rects = try scratch.alloc(Rect, col_count);
        var constraints_buf: []Constraint = undefined;
        if (self.widths.len == col_count) {
            constraints_buf = @constCast(self.widths);
        } else {
            constraints_buf = try scratch.alloc(Constraint, col_count);
            for (0..col_count) |c_i| {
                constraints_buf[c_i] = if (c_i < self.widths.len) self.widths[c_i] else .{ .fill = 1 };
            }
        }

        const data_x = inner.left() + sel_col_reserve;
        const data_w = inner.width - sel_col_reserve;
        const cols_strip = Rect.init(data_x, inner.top(), data_w, 1);
        const col_layout = core_root.Layout.horizontal(constraints_buf, .{
            .spacing = .{ .space = self.column_spacing },
        });
        _ = col_layout.splitInto(cols_strip, col_rects);

        var cur_y = inner.top();
        var avail_h = inner.height;

        // Render sticky header.
        if (self.header) |hdr| {
            if (avail_h >= hdr.height) {
                const h_style = self.header_style orelse ui.theme.accent.patch(.{ .bold = true });
                renderTableRow(ui.buffer, inner, cur_y, hdr, col_rects, sel_col_reserve, "", false, h_style, null, null, null);
                cur_y += hdr.totalHeight();
                avail_h -|= hdr.totalHeight();
                if (self.show_header_separator and avail_h > 0) {
                    var x = inner.left();
                    while (x < inner.right()) : (x += 1) {
                        _ = ui.buffer.setStringClipped(x, cur_y, style_root.symbols.line.normal.horizontal, 1, ui.theme.border, inner);
                    }
                    cur_y += 1;
                    avail_h -|= 1;
                }
            }
        }

        // Reserve bottom space for footer.
        const footer_h: u16 = if (self.footer) |ftr| @min(avail_h, ftr.height) else 0;
        const body_h = avail_h -| footer_h;

        // Adjust body scroll offset.
        if (self.rows.len == 0) {
            state.selected = null;
            state.offset = 0;
            if (self.empty_message) |msg| {
                if (body_h > 0) {
                    const mw = text_root.displayWidth(msg);
                    const draw_w = @min(mw, inner.width);
                    const mx = inner.left() + (inner.width - draw_w) / 2;
                    _ = ui.buffer.setStringClipped(mx, cur_y + body_h / 2, msg, draw_w, ui.theme.muted, inner);
                }
            }
        } else {
            if (state.selected) |sel| {
                if (sel >= self.rows.len) state.selected = self.rows.len - 1;
            }
            if (state.offset >= self.rows.len) state.offset = self.rows.len - 1;
            if (state.selected) |sel| {
                if (sel < state.offset) {
                    state.offset = sel;
                } else {
                    while (state.offset < sel) {
                        var h_sum: u32 = 0;
                        var k = state.offset;
                        while (k <= sel) : (k += 1) {
                            h_sum += self.rows[k].totalHeight();
                        }
                        if (h_sum <= body_h) break;
                        state.offset += 1;
                    }
                }
            }
        }

        const row_hl = self.row_highlight_style orelse if (self.focused) ui.theme.selection else ui.theme.muted.patch(.{ .reverse = true });

        var used_body: u16 = 0;
        var row_idx = state.offset;
        while (row_idx < self.rows.len and used_body < body_h) : (row_idx += 1) {
            const row = self.rows[row_idx];
            if (used_body + row.height > body_h and used_body > 0) break;
            const is_row_sel = if (state.selected) |s| s == row_idx else false;

            var row_s = base_style;
            if (self.striped_style) |ss| {
                if (row_idx % 2 == 1) row_s = row_s.patch(ss);
            }
            if (row.style) |rs| row_s = row_s.patch(rs);
            if (is_row_sel) row_s = row_s.patch(row_hl);

            renderTableRow(
                ui.buffer,
                inner,
                cur_y + used_body,
                row,
                col_rects,
                sel_col_reserve,
                sym,
                is_row_sel,
                row_s,
                state.selected_column,
                self.column_highlight_style,
                self.cell_highlight_style,
            );
            used_body += row.totalHeight();
        }

        if (self.footer) |ftr| {
            if (footer_h > 0) {
                const fy = cur_y + body_h;
                const f_style = self.footer_style orelse ui.theme.muted.patch(.{ .bold = true });
                renderTableRow(ui.buffer, inner, fy, ftr, col_rects, sel_col_reserve, "", false, f_style, null, null, null);
            }
        }
    }

    fn renderTableRow(
        buf: *core_root.Buffer,
        inner: Rect,
        y: u16,
        row: TableRow,
        col_rects: []const Rect,
        sel_col_reserve: u16,
        sym: []const u8,
        is_row_sel: bool,
        row_style: Style,
        selected_col: ?usize,
        col_hl: ?Style,
        cell_hl: ?Style,
    ) void {
        const row_rect = Rect.init(inner.left(), y, inner.width, row.height).intersection(inner);
        if (row_rect.isEmpty()) return;
        buf.setStyle(row_rect, row_style);

        if (sel_col_reserve > 0 and is_row_sel) {
            _ = buf.setStringClipped(inner.left(), y, sym, sel_col_reserve, row_style, row_rect);
        }

        const n_cols = @min(row.colCount(), col_rects.len);
        for (0..n_cols) |ci| {
            const c_rect_base = col_rects[ci];
            const cell_rect = Rect.init(c_rect_base.x, y, c_rect_base.width, row.height).intersection(inner);
            if (cell_rect.isEmpty()) continue;

            const is_col_sel = if (selected_col) |sc| sc == ci else false;
            var cs = row_style;
            if (is_col_sel) {
                if (col_hl) |ch| cs = cs.patch(ch);
            }
            if (is_row_sel and is_col_sel) {
                if (cell_hl) |ch| cs = cs.patch(ch);
            }

            const cell = row.cellAt(ci);
            if (cell.style) |cst| cs = cs.patch(cst);
            if (!cs.background.isInherit() or !cs.foreground.isInherit()) {
                buf.setStyle(cell_rect, cs);
            }

            if (cell.text) |tx| {
                tx.render(buf, cell_rect, cell.alignment, cs);
            } else if (cell.line) |ln| {
                ln.render(buf, cell_rect, cell.alignment, cs);
            } else if (cell.raw) |raw_str| {
                const w = text_root.displayWidth(raw_str);
                const x: u16 = switch (cell.alignment) {
                    .left => cell_rect.left(),
                    .center => if (w < cell_rect.width) cell_rect.left() + (cell_rect.width - w) / 2 else cell_rect.left(),
                    .right => if (w < cell_rect.width) cell_rect.right() - w else cell_rect.left(),
                };
                _ = buf.setStringClipped(x, y, raw_str, cell_rect.width, cs, cell_rect);
            }
        }
    }
};

test "table lays out columns, header, selection, and scrolling cleanly" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 32, 6));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    const rows = [_]TableRow{
        TableRow.fromStrings(&.{ "nginx", "2.4%", "running" }),
        TableRow.fromStrings(&.{ "postgres", "8.1%", "running" }),
        TableRow.fromStrings(&.{ "redis", "0.5%", "idle" }),
    };
    const widths = [_]Constraint{ .{ .length = 12 }, .{ .length = 8 }, .{ .fill = 1 } };
    var state = TableState{ .selected = 1 };
    const tbl = Table{
        .header = TableRow.fromStrings(&.{ "Service", "CPU", "State" }),
        .rows = &rows,
        .widths = &widths,
        .block = .{ .title = "Processes", .border_type = .plain },
        .show_header_separator = true,
    };
    try ui.renderStateful(tbl, &state, buf.area);
    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Service") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "postgres") != null);

    // Table.handleEvent click selects row accurately beneath header + border + separator.
    const body = tbl.bodyRect(buf.area);
    try testing.expect(tbl.handleEvent(&state, .{ .mouse = .{ .kind = .down, .button = .left, .x = body.left(), .y = body.top() } }, buf.area));
    try testing.expectEqual(@as(?usize, 0), state.selected);

    buf.clear();
    var empty_st = TableState{};
    try ui.renderStateful(Table{
        .header = TableRow.fromStrings(&.{"Name"}),
        .rows = &.{},
        .empty_message = "Empty",
    }, &empty_st, Rect.init(0, 0, 20, 4));
    const empty_snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(empty_snap);
    try testing.expect(std.mem.indexOf(u8, empty_snap, "Empty") != null);
}
