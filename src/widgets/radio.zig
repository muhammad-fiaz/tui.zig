//! Mutually exclusive `RadioGroup` widget and `RadioState`.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const event_root = @import("../event/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Direction = core_root.Direction;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const RadioSet = style_root.RadioSet;
pub const symbols = style_root.symbols;
pub const Block = block_mod.Block;
pub const Event = event_root.Event;

/// Mutable state tracking selected option index in a `RadioGroup`.
pub const RadioState = struct {
    selected: usize = 0,

    pub fn selectNext(self: *RadioState, item_count: usize) void {
        if (item_count == 0) return;
        self.selected = (self.selected + 1) % item_count;
    }

    pub fn selectPrev(self: *RadioState, item_count: usize) void {
        if (item_count == 0) return;
        self.selected = if (self.selected == 0) item_count - 1 else self.selected - 1;
    }

    /// Handles keyboard navigation (`Up`/`Down`/`Left`/`Right`/Vim `j`/`k`) and mouse clicks inside `bounds`.
    /// Returns `true` when `selected` changed.
    pub fn handleEvent(
        self: *RadioState,
        event: Event,
        item_count: usize,
        bounds: Rect,
        direction: Direction,
        focused: bool,
    ) bool {
        if (item_count == 0) return false;
        switch (event) {
            .mouse => |m| {
                if (m.isLeftClickInside(bounds) and direction == .vertical) {
                    const row = m.y - bounds.top();
                    if (row < item_count) {
                        self.selected = row;
                        return true;
                    }
                }
                return false;
            },
            .key => |k| {
                if (!focused or k.kind == .release) return false;
                switch (k.code) {
                    .down, .right => {
                        self.selectNext(item_count);
                        return true;
                    },
                    .up, .left => {
                        self.selectPrev(item_count);
                        return true;
                    },
                    .char => |cp| {
                        if (cp == 'j' or cp == 'l') {
                            self.selectNext(item_count);
                            return true;
                        }
                        if (cp == 'k' or cp == 'h') {
                            self.selectPrev(item_count);
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

/// Vertical or horizontal radio selector over a borrowed slice of option labels.
pub const RadioGroup = struct {
    items: []const []const u8 = &.{},
    selected: usize = 0,
    direction: Direction = .vertical,
    wrap: bool = false,
    focused: bool = false,
    disabled: bool = false,
    symbols_set: RadioSet = symbols.radio.unicode,
    block: ?Block = null,
    gap: u16 = 2,
    style: ?Style = null,
    selected_style: ?Style = null,
    focused_style: ?Style = null,

    /// Handles keyboard and mouse events (vertical and horizontal, including wrapped rows) within `area`.
    pub fn handleEvent(self: RadioGroup, state: *RadioState, event: Event, area: Rect) bool {
        if (self.disabled or self.items.len == 0) return false;
        const inner = if (self.block) |b| b.inner(area) else area;
        if (inner.isEmpty()) return false;

        if (event == .mouse and event.mouse.isLeftClickInside(inner)) {
            const m = event.mouse;
            switch (self.direction) {
                .vertical => {
                    const row = m.y - inner.top();
                    if (row < self.items.len) {
                        state.selected = row;
                        return true;
                    }
                },
                .horizontal => {
                    var x = inner.left();
                    var y = inner.top();
                    for (self.items, 0..) |item, i| {
                        const glyph = if (i == state.selected) self.symbols_set.selected else self.symbols_set.unselected;
                        const item_w = text_root.displayWidth(glyph) +| 1 +| text_root.displayWidth(item);
                        if (self.wrap and x > inner.left() and x +| item_w > inner.right()) {
                            x = inner.left();
                            y += 1;
                        }
                        if (y >= inner.bottom()) break;
                        if (m.y == y and m.x >= x and m.x < x +| item_w) {
                            state.selected = i;
                            return true;
                        }
                        x +|= item_w +| self.gap;
                    }
                },
            }
            return false;
        }
        return state.handleEvent(event, self.items.len, inner, self.direction, self.focused);
    }

    /// Stateless render using `self.selected`.
    pub fn render(self: RadioGroup, ui: *Ui, area: Rect) !void {
        var st = RadioState{ .selected = self.selected };
        try self.renderStateful(ui, area, &st);
    }

    /// Stateful render synchronized with `state.selected`.
    pub fn renderStateful(self: RadioGroup, ui: *Ui, area: Rect, state: *RadioState) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty() or self.items.len == 0) return;

        if (state.selected >= self.items.len) state.selected = 0;

        const base_style = if (self.disabled) ui.theme.disabled else self.style orelse ui.theme.text;
        const active_style = if (self.disabled)
            ui.theme.disabled
        else if (self.focused)
            self.focused_style orelse ui.theme.accent.patch(.{ .bold = true })
        else
            self.selected_style orelse ui.theme.accent;

        switch (self.direction) {
            .vertical => {
                for (self.items, 0..) |item, i| {
                    if (i >= inner.height) break;
                    const y = inner.top() + @as(u16, @intCast(i));
                    const is_sel = i == state.selected;
                    const glyph = if (is_sel) self.symbols_set.selected else self.symbols_set.unselected;
                    const row_s = if (is_sel) active_style else base_style;
                    var pos = ui.buffer.setStringClipped(inner.left(), y, glyph, inner.width, row_s, inner);
                    if (pos.x < inner.right()) {
                        pos = ui.buffer.setStringClipped(pos.x, y, " ", 1, row_s, inner);
                    }
                    if (pos.x < inner.right()) {
                        _ = ui.buffer.setStringClipped(pos.x, y, item, inner.right() - pos.x, row_s, inner);
                    }
                }
            },
            .horizontal => {
                var x = inner.left();
                var y = inner.top();
                for (self.items, 0..) |item, i| {
                    const is_sel = i == state.selected;
                    const glyph = if (is_sel) self.symbols_set.selected else self.symbols_set.unselected;
                    const item_w = text_root.displayWidth(glyph) +| 1 +| text_root.displayWidth(item);
                    if (self.wrap and x > inner.left() and x +| item_w > inner.right()) {
                        x = inner.left();
                        y += 1;
                    }
                    if (y >= inner.bottom()) break;
                    if (!self.wrap and x >= inner.right()) break;

                    const row_s = if (is_sel) active_style else base_style;
                    x = ui.buffer.setStringClipped(x, y, glyph, inner.right() - x, row_s, inner).x;
                    if (x < inner.right()) {
                        x = ui.buffer.setStringClipped(x, y, " ", 1, row_s, inner).x;
                    }
                    if (x < inner.right()) {
                        x = ui.buffer.setStringClipped(x, y, item, inner.right() - x, row_s, inner).x;
                    }
                    x +|= self.gap;
                }
            },
        }
    }
};

test "radio group renders horizontal/vertical options and handles selection" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 30, 4));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    var state = RadioState{ .selected = 0 };
    const opts = [_][]const u8{ "Fast", "Balanced", "Accurate" };
    const rg = RadioGroup{ .items = &opts, .focused = true };

    _ = state.handleEvent(.{ .key = .{ .code = .down } }, opts.len, buf.area, .vertical, true);
    try testing.expectEqual(@as(usize, 1), state.selected);

    try ui.renderStateful(rg, &state, Rect.init(0, 0, 20, 3));
    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "( ) Fast") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "(●) Balanced") != null);

    // Horizontal radio hit-testing selects exact clicked option.
    const h_rg = RadioGroup{ .items = &opts, .direction = .horizontal, .focused = true };
    try testing.expect(h_rg.handleEvent(&state, .{ .mouse = .{ .kind = .down, .button = .left, .x = 12, .y = 0 } }, Rect.init(0, 0, 30, 1)));
    try testing.expectEqual(@as(usize, 1), state.selected);
}
