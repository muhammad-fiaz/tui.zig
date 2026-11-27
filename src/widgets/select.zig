//! Dropdown / `Select` combobox widget with overlay menu and `SelectState`.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const event_root = @import("../event/root.zig");
const block_mod = @import("block.zig");
const clear_mod = @import("clear.zig");
const list_mod = @import("list.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const Block = block_mod.Block;
pub const Event = event_root.Event;
pub const List = list_mod.List;
pub const ListState = list_mod.ListState;

/// Mutable open/closed and highlight state for a `Select` / `Dropdown`.
pub const SelectState = struct {
    selected: usize = 0,
    open: bool = false,
    max_dropdown_rows: u16 = 6,
    list_state: ListState = .{ .selected = 0 },

    /// Handles toggling open/close, wheel scroll, and clicks inside the dropdown popup (defaults to bottom placement if screen omitted).
    pub fn handleEvent(
        self: *SelectState,
        event: Event,
        item_count: usize,
        header_bounds: Rect,
        focused: bool,
    ) bool {
        const fallback_screen = Rect.init(0, 0, std.math.maxInt(u16), header_bounds.bottom() +| self.max_dropdown_rows +| 4);
        return self.handleEventIn(event, item_count, header_bounds, fallback_screen, focused);
    }

    /// Screen-aware event handler accurately matching flipped above/below popup placement, wheel scroll, and outside click dismiss.
    pub fn handleEventIn(
        self: *SelectState,
        event: Event,
        item_count: usize,
        header_bounds: Rect,
        screen: Rect,
        focused: bool,
    ) bool {
        if (item_count == 0) return false;
        switch (event) {
            .mouse => |m| {
                if (self.open and (m.kind == .scroll_up or m.kind == .scroll_down)) {
                    const popup_rect = Select.popupRect(header_bounds, screen, item_count, self.max_dropdown_rows);
                    if (m.isInside(popup_rect)) {
                        if (m.kind == .scroll_up) {
                            self.list_state.selectPrevious(item_count);
                        } else {
                            self.list_state.selectNext(item_count);
                        }
                        return false;
                    }
                }
                if (m.kind == .down and m.button == .left) {
                    if (m.isInside(header_bounds)) {
                        self.open = !self.open;
                        self.list_state.selected = self.selected;
                        return false;
                    }
                    if (self.open) {
                        const popup_rect = Select.popupRect(header_bounds, screen, item_count, self.max_dropdown_rows);
                        const list_inner = Rect.init(popup_rect.x +| 1, popup_rect.y +| 1, popup_rect.width -| 2, popup_rect.height -| 2);
                        if (m.isInside(list_inner)) {
                            const row = self.list_state.offset + (m.y - list_inner.top());
                            if (row < item_count) {
                                self.selected = row;
                                self.list_state.selected = row;
                                self.open = false;
                                return true;
                            }
                        } else {
                            self.open = false;
                        }
                    }
                }
                return false;
            },
            .key => |k| {
                if (!focused or k.kind == .release) return false;
                if (!self.open) {
                    if (k.code == .enter or k.isChar(' ') or k.code == .down) {
                        self.open = true;
                        self.list_state.selected = self.selected;
                    }
                    return false;
                }
                switch (k.code) {
                    .escape => {
                        self.open = false;
                        return false;
                    },
                    .enter => {
                        if (self.list_state.selected) |hl| {
                            if (hl < item_count) self.selected = hl;
                        }
                        self.open = false;
                        return true;
                    },
                    .char => |cp| {
                        if (cp == ' ') {
                            if (self.list_state.selected) |hl| {
                                if (hl < item_count) self.selected = hl;
                            }
                            self.open = false;
                            return true;
                        }
                        return false;
                    },
                    .down => {
                        self.list_state.selectNext(item_count);
                        return false;
                    },
                    .up => {
                        self.list_state.selectPrevious(item_count);
                        return false;
                    },
                    .home => {
                        self.list_state.selectFirst(item_count);
                        return false;
                    },
                    .end => {
                        self.list_state.selectLast(item_count);
                        return false;
                    },
                    else => return false,
                }
            },
            else => return false,
        }
    }
};

/// Combobox / dropdown selector widget (`Dropdown` alias).
pub const Select = struct {
    items: []const []const u8 = &.{},
    placeholder: []const u8 = "Select...",
    label: ?[]const u8 = null,
    focused: bool = false,
    disabled: bool = false,
    max_dropdown_rows: u16 = 6,
    block: ?Block = .{ .border_type = .rounded },
    style: ?Style = null,
    focused_style: ?Style = null,
    highlight_style: ?Style = null,

    /// Computes floating dropdown placement (below `bounds`, or above when near bottom edge of `screen`),
    /// reserving space for drop shadows so popup never overflows `screen`.
    pub fn popupRect(bounds: Rect, screen: Rect, item_count: usize, max_dropdown_rows: u16) Rect {
        if (item_count == 0 or bounds.isEmpty() or screen.isEmpty()) return Rect.zero;
        const visible_rows: u16 = @intCast(@min(@as(usize, max_dropdown_rows), item_count));
        const popup_h = @min(screen.height, visible_rows + 2);
        const fits_below = bounds.bottom() +| popup_h <= screen.bottom();
        const py: u16 = if (fits_below) bounds.bottom() else bounds.top() -| popup_h;
        const max_w = screen.right() -| bounds.left();
        return Rect.init(bounds.left(), py, @min(bounds.width, max_w), popup_h).intersection(screen);
    }

    /// Screen-aware interaction handler that enforces `self.disabled` and supports type-ahead character jump while open.
    pub fn handleEvent(
        self: Select,
        state: *SelectState,
        event: Event,
        header_bounds: Rect,
        screen: Rect,
    ) bool {
        if (self.disabled or self.items.len == 0) {
            state.open = false;
            return false;
        }
        if (state.open and event == .key and event.key.kind != .release) {
            if (event.key.code == .char and !event.key.modifiers.ctrl and !event.key.modifiers.alt) {
                const cp = event.key.code.char;
                if (cp >= 0x20 and cp < 0x80) {
                    const ch = std.ascii.toLower(@intCast(cp));
                    const start = ((state.list_state.selected orelse state.selected) + 1) % self.items.len;
                    for (0..self.items.len) |off| {
                        const idx = (start + off) % self.items.len;
                        if (self.items[idx].len > 0 and std.ascii.toLower(self.items[idx][0]) == ch) {
                            state.list_state.selected = idx;
                            return false;
                        }
                    }
                }
            }
        }
        return state.handleEventIn(event, self.items.len, header_bounds, screen, self.focused);
    }

    /// Renders closed combobox field and (when `state.open`) overlays the floating option list.
    pub fn renderStateful(self: Select, ui: *Ui, area: Rect, state: *SelectState) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        const box_style = if (self.disabled)
            ui.theme.disabled
        else if (self.focused)
            self.focused_style orelse ui.theme.input_focused
        else
            self.style orelse ui.theme.input;

        var inner = bounds;
        if (self.block) |blk_base| {
            var blk = blk_base;
            if (blk.title == null and self.label != null) blk.title = self.label;
            blk.focused = self.focused;
            blk.style = box_style;
            blk.fill_background = true;
            try blk.render(ui, bounds);
            inner = blk.inner(bounds);
        } else {
            ui.buffer.fill(bounds, " ", box_style);
        }
        if (inner.isEmpty()) return;

        const y = inner.top() + inner.height / 2;
        const val_text = if (self.items.len > 0 and state.selected < self.items.len)
            self.items[state.selected]
        else
            self.placeholder;
        const val_style = if (self.items.len > 0) box_style else ui.theme.muted;
        const arrow = if (state.open) "▴" else "▾";

        if (inner.width > 2) {
            _ = ui.buffer.setStringClipped(inner.left(), y, val_text, inner.width - 2, val_style, inner);
        }
        _ = ui.buffer.setStringClipped(inner.right() - 1, y, arrow, 1, ui.theme.accent, inner);

        // Floating overlay menu immediately below `bounds` (or above when constrained by screen bottom).
        if (state.open and !self.disabled and self.items.len > 0) {
            state.max_dropdown_rows = self.max_dropdown_rows;
            const screen = ui.buffer.area;
            const popup_rect = popupRect(bounds, screen, self.items.len, self.max_dropdown_rows);
            if (popup_rect.height < 3) return;

            (clear_mod.Clear{ .style = ui.theme.surface }).renderToBuffer(ui.buffer, popup_rect);
            var full_ui = ui.*;
            full_ui.area = screen;
            const popup_list = List{
                .raw_items = self.items,
                .block = .{
                    .border_type = .rounded,
                    .focused = true,
                    .style = ui.theme.surface,
                    .fill_background = true,
                    .shadow = .{ .enabled = true },
                },
                .highlight_style = self.highlight_style orelse ui.theme.selection,
                .focused = true,
            };
            try popup_list.renderStateful(&full_ui, popup_rect, &state.list_state);
        }
    }
};

/// Idiomatic alias for `Select`.
pub const Dropdown = Select;
/// Idiomatic alias for `SelectState`.
pub const DropdownState = SelectState;

test "select toggles overlay dropdown and commits chosen item" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 24, 9));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    const choices = [_][]const u8{ "Local", "Staging", "Production" };
    var state = SelectState{};
    const header = Rect.init(0, 0, 20, 3);

    _ = state.handleEvent(.{ .key = .{ .code = .enter } }, choices.len, header, true);
    try testing.expect(state.open);
    _ = state.handleEvent(.{ .key = .{ .code = .down } }, choices.len, header, true);

    try ui.renderStateful(Select{ .items = &choices, .label = "Env", .focused = true }, &state, header);
    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Production") != null);

    try testing.expect(state.handleEvent(.{ .key = .{ .code = .enter } }, choices.len, header, true));
    try testing.expect(!state.open);
    try testing.expectEqual(@as(usize, 1), state.selected);

    // Flipped-upward dropdown click at bottom of screen.
    const bot_header = Rect.init(0, 6, 20, 3);
    const scr = Rect.init(0, 0, 24, 9);
    const pop_up = Select.popupRect(bot_header, scr, choices.len, 6);
    try testing.expect(pop_up.bottom() <= bot_header.top());
    state.open = true;
    try testing.expect(state.handleEventIn(.{ .mouse = .{ .kind = .down, .button = .left, .x = 2, .y = pop_up.top() + 1 } }, choices.len, bot_header, scr, true));
    try testing.expectEqual(@as(usize, 0), state.selected);
}
