//! Scrollable `List`, `ListItem`, and `ListState` supporting plain strings and rich multi-line items.

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
pub const Line = text_root.Line;
pub const Event = event_root.Event;

/// Controls whether highlight prefix width is reserved for unselected rows.
pub const HighlightSpacing = enum {
    always,
    when_selected,
    never,
};

/// Stacking direction of items within a `List`.
pub const ListDirection = enum {
    top_to_bottom,
    bottom_to_top,
};

/// Single entry inside a `List` (plain string, single rich `Line`, or multi-line item).
pub const ListItem = struct {
    raw: ?[]const u8 = null,
    line: ?Line = null,
    lines: []const Line = &.{},
    style: ?Style = null,

    pub fn init(raw: []const u8) ListItem {
        return .{ .raw = raw };
    }

    pub fn fromLine(ln: Line) ListItem {
        return .{ .line = ln };
    }

    pub fn fromLines(lns: []const Line) ListItem {
        return .{ .lines = lns };
    }

    pub fn height(self: ListItem) u16 {
        if (self.lines.len > 0) return @intCast(@min(std.math.maxInt(u16), self.lines.len));
        if (self.line != null) return 1;
        if (self.raw) |r| {
            var count: u16 = 1;
            for (r) |b| {
                if (b == '\n') count +|= 1;
            }
            return count;
        }
        return 1;
    }
};

/// Scroll and selection state for a `List`.
pub const ListState = struct {
    selected: ?usize = null,
    offset: usize = 0,

    pub fn select(self: *ListState, index: ?usize) void {
        self.selected = index;
        if (index == null) self.offset = 0;
    }

    pub fn selectFirst(self: *ListState, count: usize) void {
        if (count == 0) {
            self.selected = null;
            return;
        }
        self.selected = 0;
    }

    pub fn selectLast(self: *ListState, count: usize) void {
        if (count == 0) {
            self.selected = null;
            return;
        }
        self.selected = count - 1;
    }

    pub fn selectNext(self: *ListState, count: usize) void {
        if (count == 0) return;
        self.selected = if (self.selected) |s| (if (s + 1 >= count) 0 else s + 1) else 0;
    }

    pub fn selectPrevious(self: *ListState, count: usize) void {
        if (count == 0) return;
        self.selected = if (self.selected) |s| (if (s == 0) count - 1 else s - 1) else count - 1;
    }

    /// Handles keyboard navigation (`Up`/`Down`/`j`/`k`/`Home`/`End`/`PageUp`/`PageDown`)
    /// and mouse click / wheel scrolling inside `bounds`. Returns `true` if state changed.
    pub fn handleEvent(
        self: *ListState,
        event: Event,
        item_count: usize,
        viewport_height: u16,
        bounds: Rect,
        focused: bool,
    ) bool {
        if (item_count == 0) return false;
        switch (event) {
            .mouse => |m| {
                if (!m.isInside(bounds)) return false;
                if (m.kind == .down and m.button == .left) {
                    const row = self.offset + (m.y - bounds.top());
                    if (row < item_count) {
                        self.selected = row;
                        return true;
                    }
                } else if (m.kind == .scroll_up) {
                    self.selectPrevious(item_count);
                    return true;
                } else if (m.kind == .scroll_down) {
                    self.selectNext(item_count);
                    return true;
                }
                return false;
            },
            .key => |k| {
                if (!focused or k.kind == .release) return false;
                const page = @max(@as(usize, 1), viewport_height);
                switch (k.code) {
                    .down => {
                        self.selectNext(item_count);
                        return true;
                    },
                    .up => {
                        self.selectPrevious(item_count);
                        return true;
                    },
                    .home => {
                        self.selectFirst(item_count);
                        return true;
                    },
                    .end => {
                        self.selectLast(item_count);
                        return true;
                    },
                    .page_down => {
                        const cur = self.selected orelse 0;
                        self.selected = @min(item_count - 1, cur + page);
                        return true;
                    },
                    .page_up => {
                        const cur = self.selected orelse 0;
                        self.selected = cur -| page;
                        return true;
                    },
                    .char => |cp| {
                        if (cp == 'j') {
                            self.selectNext(item_count);
                            return true;
                        }
                        if (cp == 'k') {
                            self.selectPrevious(item_count);
                            return true;
                        }
                        if (cp == 'g') {
                            self.selectFirst(item_count);
                            return true;
                        }
                        if (cp == 'G') {
                            self.selectLast(item_count);
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

/// Scrollable vertical list widget supporting plain strings (`raw_items`) or styled `ListItem`s (`items`).
pub const List = struct {
    items: []const ListItem = &.{},
    raw_items: []const []const u8 = &.{},
    block: ?Block = null,
    style: ?Style = null,
    highlight_style: ?Style = null,
    highlight_symbol: ?[]const u8 = "▸ ",
    highlight_spacing: HighlightSpacing = .when_selected,
    repeat_highlight_symbol: bool = false,
    direction: ListDirection = .top_to_bottom,
    focused: bool = true,

    /// Convenience constructor for plain string items.
    pub fn fromStrings(items: []const []const u8) List {
        return .{ .raw_items = items };
    }

    /// Convenience constructor for styled `ListItem` slice.
    pub fn fromItems(items: []const ListItem) List {
        return .{ .items = items };
    }

    pub fn len(self: List) usize {
        return if (self.items.len > 0) self.items.len else self.raw_items.len;
    }

    fn itemAt(self: List, idx: usize) ListItem {
        if (self.items.len > 0) return self.items[idx];
        return .{ .raw = self.raw_items[idx] };
    }

    /// Stateless render (no selection highlight).
    pub fn render(self: List, ui: *Ui, area: Rect) !void {
        var st = ListState{};
        try self.renderStateful(ui, area, &st);
    }

    /// Renders visible list rows and adjusts `state.offset` so `state.selected` stays visible.
    pub fn renderStateful(self: List, ui: *Ui, area: Rect, state: *ListState) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        const base_style = self.style orelse ui.theme.text;
        if (self.style != null) {
            ui.buffer.setStyle(inner, base_style);
        }

        const total = self.len();
        if (total == 0) {
            state.selected = null;
            state.offset = 0;
            return;
        }

        if (state.selected) |sel| {
            if (sel >= total) state.selected = total - 1;
        }
        if (state.offset >= total) state.offset = total - 1;

        // Scroll offset maintenance so selected item fits in `inner.height`.
        if (state.selected) |sel| {
            if (sel < state.offset) {
                state.offset = sel;
            } else {
                // Ensure total heights from `offset..=sel` fit within `inner.height`.
                while (state.offset < sel) {
                    var h_sum: u32 = 0;
                    var k = state.offset;
                    while (k <= sel) : (k += 1) {
                        h_sum += self.itemAt(k).height();
                    }
                    if (h_sum <= inner.height) break;
                    state.offset += 1;
                }
            }
        }

        const sym = self.highlight_symbol orelse "";
        const sym_w = text_root.displayWidth(sym);
        const reserve_sym_col: u16 = switch (self.highlight_spacing) {
            .always => sym_w,
            .when_selected => if (state.selected != null) sym_w else 0,
            .never => 0,
        };
        const hl_style = self.highlight_style orelse if (self.focused) ui.theme.selection else ui.theme.muted.patch(.{ .reverse = true });

        var used_rows: u16 = 0;
        var idx = state.offset;
        while (idx < total and used_rows < inner.height) : (idx += 1) {
            const item = self.itemAt(idx);
            const item_h = item.height();
            const is_sel = if (state.selected) |s| s == idx else false;
            const item_style = if (is_sel)
                hl_style
            else if (item.style) |is|
                base_style.patch(is)
            else
                base_style;

            var sub_row: u16 = 0;
            while (sub_row < item_h and used_rows < inner.height) : (sub_row += 1) {
                const screen_y = switch (self.direction) {
                    .top_to_bottom => inner.top() + used_rows,
                    .bottom_to_top => inner.bottom() - 1 - used_rows,
                };
                used_rows += 1;

                ui.buffer.setStyle(Rect.init(inner.left(), screen_y, inner.width, 1), item_style);

                if (reserve_sym_col > 0 and is_sel and (sub_row == 0 or self.repeat_highlight_symbol)) {
                    _ = ui.buffer.setStringClipped(inner.left(), screen_y, sym, @min(reserve_sym_col, inner.width), item_style, inner);
                }

                const content_x = inner.left() +| reserve_sym_col;
                const content_w = inner.right() -| content_x;
                if (content_w == 0) continue;
                const content_rect = Rect.init(content_x, screen_y, content_w, 1);

                if (item.lines.len > 0) {
                    item.lines[sub_row].render(ui.buffer, content_rect, .left, item_style);
                } else if (item.line) |ln| {
                    ln.render(ui.buffer, content_rect, .left, item_style);
                } else if (item.raw) |r| {
                    var line_it = text_root.splitLinesIter(r);
                    var n: u16 = 0;
                    var slice: []const u8 = "";
                    while (line_it.next()) |s| : (n += 1) {
                        if (n == sub_row) {
                            slice = s;
                            break;
                        }
                    }
                    _ = ui.buffer.setStringClipped(content_x, screen_y, slice, content_w, item_style, content_rect);
                }
            }
        }
    }
};

test "list renders items, highlights selection, and auto-scrolls" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 20, 4));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    const items = [_][]const u8{ "Alpha", "Beta", "Gamma", "Delta", "Epsilon" };
    var state = ListState{ .selected = 0 };
    try testing.expect(state.handleEvent(.{ .key = .{ .code = .end } }, items.len, 2, Rect.init(0, 0, 20, 4), true));
    try testing.expectEqual(@as(?usize, 4), state.selected);

    try ui.renderStateful(List{
        .raw_items = &items,
        .block = .{ .title = "Items", .border_type = .plain },
    }, &state, Rect.init(0, 0, 20, 4));
    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Epsilon") != null);
}
