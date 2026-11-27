//! Vertical and horizontal `Scrollbar` widget and `ScrollbarState`.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Buffer = core_root.Buffer;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const ScrollbarSet = style_root.ScrollbarSet;
pub const symbols = style_root.symbols;

/// Edge and orientation along which a `Scrollbar` renders inside its assigned `Rect`.
pub const ScrollbarOrientation = enum {
    vertical_right,
    vertical_left,
    horizontal_bottom,
    horizontal_top,

    pub fn isVertical(self: ScrollbarOrientation) bool {
        return self == .vertical_right or self == .vertical_left;
    }
};

/// Mutable scroll state tracking total content items/lines, visible viewport length, and offset.
pub const ScrollbarState = struct {
    /// Total number of scrollable items or rows.
    content_length: usize = 0,
    /// Current scroll offset (`0 <= position <= maxOffset()`).
    position: usize = 0,
    /// Number of items visible simultaneously in the viewport (used for proportional thumb sizing).
    viewport_content_length: usize = 0,

    /// Maximum valid scroll offset (`content_length -| viewport_content_length`, or `content_length -| 1` if viewport unknown).
    pub fn maxOffset(self: ScrollbarState) usize {
        if (self.content_length == 0) return 0;
        if (self.viewport_content_length > 0) {
            return self.content_length -| self.viewport_content_length;
        }
        return self.content_length -| 1;
    }

    /// Clamps `position` inside `[0, maxOffset()]`.
    pub fn clamp(self: *ScrollbarState) void {
        const m = self.maxOffset();
        if (self.position > m) self.position = m;
    }

    /// Scrolls relative by signed `delta`, clamping safely at ends.
    pub fn scrollBy(self: *ScrollbarState, delta: isize) void {
        if (delta < 0) {
            const dec: usize = @intCast(-delta);
            self.position -|= dec;
        } else {
            const inc: usize = @intCast(delta);
            self.position = @min(self.maxOffset(), self.position +| inc);
        }
    }

    /// Sets `position` directly (clamped).
    pub fn scrollTo(self: *ScrollbarState, pos: usize) void {
        self.position = @min(self.maxOffset(), pos);
    }

    /// Moves forward by one viewport page (or 1 when viewport is unset).
    pub fn pageDown(self: *ScrollbarState) void {
        const step = @max(1, self.viewport_content_length);
        self.scrollTo(self.position +| step);
    }

    /// Moves backward by one viewport page (or 1 when viewport is unset).
    pub fn pageUp(self: *ScrollbarState) void {
        const step = @max(1, self.viewport_content_length);
        self.position -|= step;
    }
};

/// Stateful proportional scrollbar widget for lists, tables, trees, and scroll views.
pub const Scrollbar = struct {
    orientation: ScrollbarOrientation = .vertical_right,
    symbols_set: ?ScrollbarSet = null,
    show_arrows: bool = true,
    thumb_style: ?Style = null,
    track_style: ?Style = null,
    begin_style: ?Style = null,
    end_style: ?Style = null,

    /// Stateless render using zero position (or track-only preview).
    pub fn render(self: Scrollbar, ui: *Ui, area: Rect) !void {
        var dummy = ScrollbarState{};
        try self.renderStateful(ui, area, &dummy);
    }

    /// Renders proportional thumb, track, and optional arrow caps using `state`.
    pub fn renderStateful(self: Scrollbar, ui: *Ui, area: Rect, state: *ScrollbarState) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        state.clamp();
        const set = self.symbols_set orelse if (self.orientation.isVertical())
            symbols.scrollbar.vertical
        else
            symbols.scrollbar.horizontal;

        const trk_style = self.track_style orelse ui.theme.border;
        const thm_style = self.thumb_style orelse ui.theme.accent;
        const beg_style = self.begin_style orelse trk_style;
        const end_s = self.end_style orelse trk_style;

        const bar_len: u16 = if (self.orientation.isVertical()) bounds.height else bounds.width;
        if (bar_len == 0) return;

        const use_arrows = self.show_arrows and bar_len >= 3;
        const track_start: u16 = if (use_arrows) 1 else 0;
        const track_len: u16 = if (use_arrows) bar_len - 2 else bar_len;
        if (track_len == 0) return;

        const viewport = @max(@as(usize, 1), state.viewport_content_length);
        const total = @max(viewport, state.content_length);
        const thumb_len: u16 = if (state.content_length <= viewport)
            track_len
        else
            @intCast(@max(@as(usize, 1), (@as(usize, track_len) * viewport) / total));

        const max_off = state.maxOffset();
        const track_travel = track_len -| thumb_len;
        const thumb_offset: u16 = if (max_off == 0 or track_travel == 0)
            0
        else
            @intCast(@min(@as(usize, track_travel), (state.position * @as(usize, track_travel) + max_off / 2) / max_off));

        var i: u16 = 0;
        while (i < bar_len) : (i += 1) {
            const gx: u16 = switch (self.orientation) {
                .vertical_left => bounds.left(),
                .vertical_right => bounds.right() - 1,
                .horizontal_top, .horizontal_bottom => bounds.left() + i,
            };
            const gy: u16 = switch (self.orientation) {
                .vertical_left, .vertical_right => bounds.top() + i,
                .horizontal_top => bounds.top(),
                .horizontal_bottom => bounds.bottom() - 1,
            };

            const cell = ui.buffer.getMut(gx, gy) orelse continue;
            if (use_arrows and i == 0) {
                try ui.buffer.setCellSymbol(cell, set.begin);
                cell.setStyle(beg_style);
            } else if (use_arrows and i == bar_len - 1) {
                try ui.buffer.setCellSymbol(cell, set.end);
                cell.setStyle(end_s);
            } else {
                const track_pos = i - track_start;
                const is_thumb = track_pos >= thumb_offset and track_pos < thumb_offset + thumb_len;
                try ui.buffer.setCellSymbol(cell, if (is_thumb) set.thumb else set.track);
                cell.setStyle(if (is_thumb) thm_style else trk_style);
            }
            cell.diff_option = .none;
        }
    }

    /// Handles mouse wheel scrolling and left-click track/arrow navigation inside `area`.
    pub fn handleEvent(
        self: Scrollbar,
        state: *ScrollbarState,
        event: @import("../event/root.zig").Event,
        area: Rect,
    ) bool {
        if (event != .mouse) return false;
        const m = event.mouse;
        if (!m.isInside(area)) return false;

        switch (m.kind) {
            .scroll_up, .scroll_left => {
                const prev = state.position;
                state.scrollBy(-1);
                return state.position != prev;
            },
            .scroll_down, .scroll_right => {
                const prev = state.position;
                state.scrollBy(1);
                return state.position != prev;
            },
            .down, .drag => {
                if (m.button != .left) return false;
                const bar_len: u16 = if (self.orientation.isVertical()) area.height else area.width;
                if (bar_len == 0) return false;
                const offset: u16 = if (self.orientation.isVertical()) m.y - area.top() else m.x - area.left();
                const use_arrows = self.show_arrows and bar_len >= 3;
                if (use_arrows and offset == 0) {
                    const prev = state.position;
                    state.scrollBy(-1);
                    return state.position != prev;
                }
                if (use_arrows and offset == bar_len - 1) {
                    const prev = state.position;
                    state.scrollBy(1);
                    return state.position != prev;
                }
                const track_len: u16 = if (use_arrows) bar_len - 2 else bar_len;
                const track_rel: u16 = offset -| if (use_arrows) @as(u16, 1) else 0;
                const denom: u128 = @max(@as(u128, 1), track_len -| 1);
                const max_off = state.maxOffset();
                const target: usize = @intCast((@as(u128, max_off) * @min(track_rel, track_len -| 1) + denom / 2) / denom);
                const prev = state.position;
                state.scrollTo(target);
                return state.position != prev;
            },
            else => return false,
        }
    }
};

test "scrollbar renders proportional thumb and updates scroll bounds" {
    const alloc = testing.allocator;
    var buf = try Buffer.init(alloc, Rect.init(0, 0, 10, 8));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    var state = ScrollbarState{
        .content_length = 40,
        .viewport_content_length = 10,
        .position = 30,
    };
    try testing.expectEqual(@as(usize, 30), state.maxOffset());

    try ui.renderStateful(Scrollbar{ .orientation = .vertical_right }, &state, Rect.init(0, 0, 10, 8));
    try testing.expectEqualStrings("↑", buf.get(9, 0).?.symbol());
    try testing.expectEqualStrings("↓", buf.get(9, 7).?.symbol());
    // Scrolled all the way to bottom: bottom track slot holds thumb.
    try testing.expectEqualStrings(symbols.block.full, buf.get(9, 6).?.symbol());

    state.pageUp();
    try testing.expectEqual(@as(usize, 20), state.position);

    // Clicking top arrow decrements position; wheel down increments it.
    const sb = Scrollbar{ .orientation = .vertical_right };
    const sb_rect = Rect.init(9, 0, 1, 8);
    try testing.expect(sb.handleEvent(&state, .{ .mouse = .{ .kind = .down, .button = .left, .x = 9, .y = 0 } }, sb_rect));
    try testing.expectEqual(@as(usize, 19), state.position);
    try testing.expect(sb.handleEvent(&state, .{ .mouse = .{ .kind = .scroll_down, .x = 9, .y = 3 } }, sb_rect));
    try testing.expectEqual(@as(usize, 20), state.position);
}
