//! Multi-line `TextArea` editor widget with `TextAreaState`, line numbers, and scrolling.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const event_root = @import("../event/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const Block = block_mod.Block;
pub const Event = event_root.Event;

/// Line and visual-column coordinates of the editor cursor (0-based).
pub const CursorLineCol = struct {
    line: usize,
    col_byte: usize,
    col_display: u16,
};

/// Allocator-owned multi-line UTF-8 editing buffer with selection and vertical/horizontal scroll state.
pub const TextAreaState = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayListUnmanaged(u8) = .empty,
    /// Current byte cursor in `buffer.items`.
    cursor: usize = 0,
    /// Topmost visible line index (0-based).
    scroll_y: usize = 0,
    /// Horizontal column scroll offset.
    scroll_x: u16 = 0,
    /// Optional start byte of active selection (`null` = no selection).
    selection_anchor: ?usize = null,

    pub fn init(allocator: std.mem.Allocator) TextAreaState {
        return .{ .allocator = allocator };
    }

    pub fn initWithText(allocator: std.mem.Allocator, initial: []const u8) !TextAreaState {
        var st = init(allocator);
        errdefer st.deinit();
        try st.setText(initial);
        return st;
    }

    pub fn deinit(self: *TextAreaState) void {
        self.buffer.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn text(self: *const TextAreaState) []const u8 {
        return self.buffer.items;
    }

    pub fn setText(self: *TextAreaState, value: []const u8) !void {
        self.buffer.clearRetainingCapacity();
        try self.buffer.appendSlice(self.allocator, value);
        self.cursor = self.buffer.items.len;
        self.scroll_y = 0;
        self.scroll_x = 0;
        self.selection_anchor = null;
    }

    pub fn clear(self: *TextAreaState) void {
        self.buffer.clearRetainingCapacity();
        self.cursor = 0;
        self.scroll_y = 0;
        self.scroll_x = 0;
        self.selection_anchor = null;
    }

    pub fn selectAll(self: *TextAreaState) void {
        self.selection_anchor = 0;
        self.cursor = self.buffer.items.len;
    }

    pub fn selectedRange(self: *const TextAreaState) ?struct { start: usize, end: usize } {
        const anchor = self.selection_anchor orelse return null;
        const start = @min(anchor, self.cursor);
        const end = @max(anchor, self.cursor);
        if (end <= start) return null;
        return .{ .start = start, .end = end };
    }

    pub fn selectedText(self: *const TextAreaState) ?[]const u8 {
        const r = self.selectedRange() orelse return null;
        return self.buffer.items[r.start..r.end];
    }

    pub fn deleteSelection(self: *TextAreaState) bool {
        const anchor = self.selection_anchor orelse return false;
        const start = @min(anchor, self.cursor);
        const end = @max(anchor, self.cursor);
        if (end > start) {
            self.buffer.replaceRangeAssumeCapacity(start, end - start, &.{});
            self.cursor = start;
        }
        self.selection_anchor = null;
        return end > start;
    }

    pub fn lineCount(self: *const TextAreaState) usize {
        var count: usize = 1;
        for (self.buffer.items) |b| {
            if (b == '\n') count += 1;
        }
        return count;
    }

    pub fn cursorLineCol(self: *const TextAreaState) CursorLineCol {
        var line: usize = 0;
        var line_start: usize = 0;
        for (self.buffer.items[0..self.cursor], 0..) |b, i| {
            if (b == '\n') {
                line += 1;
                line_start = i + 1;
            }
        }
        const before = self.buffer.items[line_start..self.cursor];
        return .{
            .line = line,
            .col_byte = self.cursor - line_start,
            .col_display = visualWidthWithTabs(before, 4),
        };
    }

    fn visualWidthWithTabs(slice: []const u8, tab_size: u8) u16 {
        const ts: u16 = @max(@as(u8, 1), tab_size);
        var col: u16 = 0;
        var git = text_root.GraphemeIterator.init(slice);
        while (git.next()) |g| {
            if (std.mem.eql(u8, g.slice, "\t")) {
                col +|= ts - (col % ts);
            } else {
                col +|= g.width;
            }
        }
        return col;
    }

    pub fn insertCodepoint(self: *TextAreaState, cp: u21) !void {
        _ = self.deleteSelection();
        var utf8_buf: [4]u8 = undefined;
        const n = std.unicode.utf8Encode(cp, &utf8_buf) catch return;
        try self.buffer.insertSlice(self.allocator, self.cursor, utf8_buf[0..n]);
        self.cursor += n;
    }

    pub fn insertNewline(self: *TextAreaState) !void {
        _ = self.deleteSelection();
        try self.buffer.insert(self.allocator, self.cursor, '\n');
        self.cursor += 1;
    }

    pub fn insertSlice(self: *TextAreaState, slice: []const u8) !void {
        _ = self.deleteSelection();
        for (slice) |b| {
            if (b == '\r') continue;
            try self.buffer.insert(self.allocator, self.cursor, b);
            self.cursor += 1;
        }
    }

    pub fn backspace(self: *TextAreaState) bool {
        if (self.deleteSelection()) return true;
        if (self.cursor == 0) return false;
        const prev = self.prevGraphemeOffset(self.cursor);
        self.buffer.replaceRangeAssumeCapacity(prev, self.cursor - prev, &.{});
        self.cursor = prev;
        return true;
    }

    pub fn deleteForward(self: *TextAreaState) bool {
        if (self.deleteSelection()) return true;
        if (self.cursor >= self.buffer.items.len) return false;
        const next_end = self.nextGraphemeOffset(self.cursor);
        self.buffer.replaceRangeAssumeCapacity(self.cursor, next_end - self.cursor, &.{});
        return true;
    }

    fn applyExtend(self: *TextAreaState, extend: bool) void {
        if (extend) {
            if (self.selection_anchor == null) self.selection_anchor = self.cursor;
        } else {
            self.selection_anchor = null;
        }
    }

    pub fn moveUp(self: *TextAreaState) void {
        self.moveUpEx(false);
    }

    pub fn moveUpEx(self: *TextAreaState, extend: bool) void {
        self.applyExtend(extend);
        const lc = self.cursorLineCol();
        if (lc.line == 0) return;
        self.moveToLineDisplayCol(lc.line - 1, lc.col_display);
    }

    pub fn moveDown(self: *TextAreaState) void {
        self.moveDownEx(false);
    }

    pub fn moveDownEx(self: *TextAreaState, extend: bool) void {
        self.applyExtend(extend);
        const lc = self.cursorLineCol();
        if (lc.line + 1 >= self.lineCount()) return;
        self.moveToLineDisplayCol(lc.line + 1, lc.col_display);
    }

    pub fn moveHomeLine(self: *TextAreaState) void {
        self.moveHomeLineEx(false);
    }

    pub fn moveHomeLineEx(self: *TextAreaState, extend: bool) void {
        self.applyExtend(extend);
        var p = self.cursor;
        while (p > 0 and self.buffer.items[p - 1] != '\n') p -= 1;
        self.cursor = p;
    }

    pub fn moveEndLine(self: *TextAreaState) void {
        self.moveEndLineEx(false);
    }

    pub fn moveEndLineEx(self: *TextAreaState, extend: bool) void {
        self.applyExtend(extend);
        var p = self.cursor;
        while (p < self.buffer.items.len and self.buffer.items[p] != '\n') p += 1;
        self.cursor = p;
    }

    pub fn handleEvent(self: *TextAreaState, event: Event, focused: bool) !bool {
        if (!focused) return false;
        switch (event) {
            .paste => |p| {
                try self.insertSlice(p);
                return true;
            },
            .key => |k| {
                if (k.kind == .release) return false;
                switch (k.code) {
                    .enter => {
                        try self.insertNewline();
                        return true;
                    },
                    .tab => {
                        try self.insertSlice("    ");
                        return true;
                    },
                    .backspace => return self.backspace(),
                    .delete => return self.deleteForward(),
                    .left => {
                        self.applyExtend(k.modifiers.shift);
                        if (self.cursor > 0) self.cursor = self.prevGraphemeOffset(self.cursor);
                        return false;
                    },
                    .right => {
                        self.applyExtend(k.modifiers.shift);
                        if (self.cursor < self.buffer.items.len) self.cursor = self.nextGraphemeOffset(self.cursor);
                        return false;
                    },
                    .up => {
                        self.moveUpEx(k.modifiers.shift);
                        return false;
                    },
                    .down => {
                        self.moveDownEx(k.modifiers.shift);
                        return false;
                    },
                    .home => {
                        self.moveHomeLineEx(k.modifiers.shift);
                        return false;
                    },
                    .end => {
                        self.moveEndLineEx(k.modifiers.shift);
                        return false;
                    },
                    .page_up => {
                        self.applyExtend(k.modifiers.shift);
                        var step: usize = 0;
                        while (step < 10) : (step += 1) self.moveUpEx(k.modifiers.shift);
                        return false;
                    },
                    .page_down => {
                        self.applyExtend(k.modifiers.shift);
                        var step: usize = 0;
                        while (step < 10) : (step += 1) self.moveDownEx(k.modifiers.shift);
                        return false;
                    },
                    .char => |cp| {
                        if (k.modifiers.ctrl) {
                            switch (cp) {
                                'a' => self.selectAll(),
                                'e' => self.moveEndLineEx(k.modifiers.shift),
                                'k' => {
                                    var end = self.cursor;
                                    while (end < self.buffer.items.len and self.buffer.items[end] != '\n') end += 1;
                                    if (end > self.cursor) {
                                        self.buffer.replaceRangeAssumeCapacity(self.cursor, end - self.cursor, &.{});
                                        self.selection_anchor = null;
                                        return true;
                                    }
                                },
                                'u' => {
                                    self.clear();
                                    return true;
                                },
                                else => {},
                            }
                            return false;
                        }
                        if (!k.modifiers.alt and cp >= 0x20) {
                            try self.insertCodepoint(cp);
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

    fn moveToLineDisplayCol(self: *TextAreaState, target_line: usize, target_col: u16) void {
        var line: usize = 0;
        var pos: usize = 0;
        while (pos < self.buffer.items.len and line < target_line) : (pos += 1) {
            if (self.buffer.items[pos] == '\n') line += 1;
        }
        const line_start = pos;
        const line_end = std.mem.indexOfScalarPos(u8, self.buffer.items, line_start, '\n') orelse self.buffer.items.len;
        const line_slice = self.buffer.items[line_start..line_end];
        var col: u16 = 0;
        var fit_len: usize = 0;
        var git = text_root.GraphemeIterator.init(line_slice);
        while (git.next()) |g| {
            const w: u16 = if (std.mem.eql(u8, g.slice, "\t")) 4 - (col % 4) else g.width;
            if (col + w > target_col) break;
            col +|= w;
            fit_len = git.index;
        }
        self.cursor = line_start + fit_len;
    }

    fn prevGraphemeOffset(self: *const TextAreaState, offset: usize) usize {
        if (offset == 0) return 0;
        if (self.buffer.items[offset - 1] == '\n') return offset - 1;
        var line_start = offset;
        while (line_start > 0 and self.buffer.items[line_start - 1] != '\n') line_start -= 1;
        var it = text_root.GraphemeIterator.init(self.buffer.items[line_start..offset]);
        var last_start: usize = 0;
        while (it.next()) |g| last_start = it.index - g.slice.len;
        return line_start + last_start;
    }

    fn nextGraphemeOffset(self: *const TextAreaState, offset: usize) usize {
        if (offset >= self.buffer.items.len) return self.buffer.items.len;
        if (self.buffer.items[offset] == '\n') return offset + 1;
        const end = std.mem.indexOfScalarPos(u8, self.buffer.items, offset, '\n') orelse self.buffer.items.len;
        var it = text_root.GraphemeIterator.init(self.buffer.items[offset..end]);
        _ = it.next() orelse return offset + 1;
        return offset + it.index;
    }
};

/// Multi-line text editor widget with optional line-number gutter, active-line highlight,
/// selection highlight, placeholder, and automatic hardware cursor updates.
pub const TextArea = struct {
    block: ?Block = .{ .border_type = .rounded },
    placeholder: []const u8 = "",
    focused: bool = false,
    read_only: bool = false,
    line_numbers: bool = true,
    style: ?Style = null,
    line_number_style: ?Style = null,
    cursor_line_style: ?Style = null,
    cursor_visible: bool = true,

    /// Renders multi-line editor contents and updates viewport scroll offsets inside `state`.
    pub fn renderStateful(self: TextArea, ui: *Ui, area: Rect, state: *TextAreaState) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        const base_style = self.style orelse if (self.focused) ui.theme.input_focused else ui.theme.input;
        var inner = bounds;
        if (self.block) |blk_base| {
            if (bounds.height >= 3 and bounds.width >= 4) {
                var blk = blk_base;
                blk.focused = self.focused;
                blk.style = base_style;
                blk.fill_background = true;
                try blk.render(ui, bounds);
                inner = blk.inner(bounds);
            } else {
                ui.buffer.fill(bounds, " ", base_style);
            }
        } else {
            ui.buffer.fill(bounds, " ", base_style);
        }
        if (inner.isEmpty()) return;

        const lc = state.cursorLineCol();
        if (lc.line < state.scroll_y) {
            state.scroll_y = lc.line;
        } else if (lc.line >= state.scroll_y + inner.height) {
            state.scroll_y = lc.line - inner.height + 1;
        }

        const total_lines = state.lineCount();
        const digits: u16 = blk_d: {
            var n = @max(1, total_lines);
            var d: u16 = 0;
            while (n > 0) : (n /= 10) d += 1;
            break :blk_d d;
        };
        const gutter_w: u16 = if (self.line_numbers and inner.width > digits + 3) digits + 2 else 0;
        const text_x = inner.left() + gutter_w;
        const text_w = inner.right() -| text_x;
        if (text_w == 0) return;

        if (lc.col_display < state.scroll_x) {
            state.scroll_x = lc.col_display;
        } else if (lc.col_display >= state.scroll_x +| text_w) {
            state.scroll_x = lc.col_display - text_w + 1;
        }

        const ln_style = self.line_number_style orelse ui.theme.muted;
        const active_ln_style = self.cursor_line_style orelse base_style;

        if (state.text().len == 0 and self.placeholder.len > 0) {
            _ = ui.buffer.setStringClipped(text_x, inner.top(), self.placeholder, text_w, ui.theme.muted, inner);
        }

        const sel_range = state.selectedRange();
        const sel_style = base_style.patch(ui.theme.selection);

        var byte_offset: usize = 0;
        var line_idx: usize = 0;
        var line_iter = std.mem.splitScalar(u8, state.text(), '\n');
        var gutter_buf: [16]u8 = undefined;
        while (line_iter.next()) |raw_line| : ({
            byte_offset += raw_line.len + 1;
            line_idx += 1;
        }) {
            if (line_idx < state.scroll_y) continue;
            const rel_row = line_idx - state.scroll_y;
            if (rel_row >= inner.height) break;
            const y = inner.top() + @as(u16, @intCast(rel_row));
            const is_cursor_line = self.focused and line_idx == lc.line;

            if (gutter_w > 0) {
                const num_str = std.fmt.bufPrint(&gutter_buf, "{[num]d: >[w]} ", .{ .num = line_idx + 1, .w = gutter_w - 1 }) catch "";
                _ = ui.buffer.setStringClipped(inner.left(), y, num_str, gutter_w, if (is_cursor_line) ui.theme.accent else ln_style, inner);
            }

            if (is_cursor_line) {
                ui.buffer.setStyle(Rect.init(text_x, y, text_w, 1), active_ln_style);
            }

            // Horizontal clip after `scroll_x`, honoring tab stops and active selection highlighting.
            var skipped: u16 = 0;
            var draw_x = text_x;
            var col_acc: u16 = 0;
            var git = text_root.GraphemeIterator.init(raw_line);
            const row_s = if (is_cursor_line) active_ln_style else base_style;
            while (git.next()) |g| {
                const is_tab = std.mem.eql(u8, g.slice, "\t");
                const gw: u16 = if (is_tab)
                    @as(u16, @max(@as(u8, 1), ui.tab_size)) - (col_acc % @as(u16, @max(@as(u8, 1), ui.tab_size)))
                else
                    g.width;
                if (gw == 0) continue;
                const abs_start = byte_offset + (git.index - g.slice.len);
                const abs_end = byte_offset + git.index;
                col_acc +|= gw;

                if (skipped < state.scroll_x) {
                    skipped += gw;
                    if (skipped > state.scroll_x and draw_x < inner.right()) {
                        draw_x = ui.buffer.setStringClipped(draw_x, y, " ", 1, row_s, inner).x;
                    }
                    continue;
                }
                if (draw_x + (if (is_tab) 1 else gw) > inner.right()) break;
                const is_sel = if (sel_range) |sr| abs_end > sr.start and abs_start < sr.end else false;
                const cell_s = if (is_sel) sel_style else row_s;
                if (is_tab) {
                    var t_i: u16 = 0;
                    while (t_i < gw and draw_x < inner.right()) : (t_i += 1) {
                        draw_x = ui.buffer.setStringClipped(draw_x, y, " ", 1, cell_s, inner).x;
                    }
                } else {
                    draw_x = ui.buffer.setStringClipped(draw_x, y, g.slice, gw, cell_s, inner).x;
                }
            }
        }

        if (self.focused and self.cursor_visible) {
            const cy = inner.top() + @as(u16, @intCast(lc.line -| state.scroll_y));
            const cx = @min(text_x +| (lc.col_display -| state.scroll_x), inner.right() -| 1);
            ui.setCursor(cx, cy);
        }
    }

    /// Handles mouse clicks (to place cursor at clicked line/column) and wheel scrolling inside `area`.
    pub fn handleEvent(self: TextArea, state: *TextAreaState, event: Event, area: Rect) !bool {
        if (event == .mouse) {
            const m = event.mouse;
            const inner = if (self.block) |b| b.inner(area) else area;
            if (!m.isInside(inner)) return false;

            if (m.kind == .scroll_up) {
                state.moveUp();
                return false;
            }
            if (m.kind == .scroll_down) {
                state.moveDown();
                return false;
            }
            if ((m.kind == .down or m.kind == .drag) and m.button == .left) {
                const digits: u16 = blk_d: {
                    var n = @max(1, state.lineCount());
                    var d: u16 = 0;
                    while (n > 0) : (n /= 10) d += 1;
                    break :blk_d d;
                };
                const gutter_w: u16 = if (self.line_numbers and inner.width > digits + 3) digits + 2 else 0;
                const text_x = inner.left() + gutter_w;
                const clicked_line = state.scroll_y + (m.y - inner.top());
                if (clicked_line < state.lineCount()) {
                    const extend = m.kind == .drag or m.modifiers.shift;
                    state.applyExtend(extend);
                    const col = (m.x -| text_x) +| state.scroll_x;
                    state.moveToLineDisplayCol(clicked_line, col);
                }
                return false;
            }
        }
        if (self.read_only) {
            if (event == .paste) return false;
            if (event == .key) {
                const c = event.key.code;
                if (c == .enter or c == .tab or c == .backspace or c == .delete) return false;
                if (c == .char and !event.key.modifiers.ctrl) return false;
            }
        }
        return state.handleEvent(event, self.focused);
    }
};

test "text area edits multiple lines and renders gutter numbers" {
    const alloc = testing.allocator;
    var state = try TextAreaState.initWithText(alloc, "one\ntwo\nthree");
    defer state.deinit();

    try testing.expectEqual(@as(usize, 3), state.lineCount());
    state.moveUp();
    try testing.expectEqual(@as(usize, 1), state.cursorLineCol().line);

    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 20, 5));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    try ui.renderStateful(TextArea{ .focused = true }, &state, buf.area);
    try testing.expect(cursor != null);
    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "1 ") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "two") != null);

    // Mouse click positions cursor inside text area lines accurately.
    const ta = TextArea{ .focused = true };
    _ = try ta.handleEvent(&state, .{ .mouse = .{ .kind = .down, .button = .left, .x = 5, .y = 1 } }, buf.area);
    try testing.expectEqual(@as(usize, 0), state.cursorLineCol().line);

    // Ctrl+A selects all and Shift+Right extends selection.
    _ = try ta.handleEvent(&state, .{ .key = .{ .code = .{ .char = 'a' }, .modifiers = event_root.KeyModifiers.ctrl_only } }, buf.area);
    try testing.expectEqualStrings("one\ntwo\nthree", state.selectedText().?);
    _ = try ta.handleEvent(&state, .{ .key = .{ .code = .{ .char = 'X' } } }, buf.area);
    try testing.expectEqualStrings("X", state.text());
}
