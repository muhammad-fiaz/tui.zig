//! Interactive monthly `Calendar` widget, pure Zig Gregorian `Date` math,
//! event date highlights, and keyboard/mouse `CalendarState`.

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

/// Calendar weekday index (Sunday = 0 .. Saturday = 6).
pub const Weekday = enum(u3) {
    sunday = 0,
    monday = 1,
    tuesday = 2,
    wednesday = 3,
    thursday = 4,
    friday = 5,
    saturday = 6,

    pub fn isWeekend(self: Weekday) bool {
        return self == .sunday or self == .saturday;
    }

    pub fn shortName(self: Weekday) []const u8 {
        return switch (self) {
            .sunday => "Su",
            .monday => "Mo",
            .tuesday => "Tu",
            .wednesday => "We",
            .thursday => "Th",
            .friday => "Fr",
            .saturday => "Sa",
        };
    }
};

/// Gregorian calendar month (`1..=12`).
pub const Month = enum(u4) {
    january = 1,
    february = 2,
    march = 3,
    april = 4,
    may = 5,
    june = 6,
    july = 7,
    august = 8,
    september = 9,
    october = 10,
    november = 11,
    december = 12,

    pub fn name(self: Month) []const u8 {
        return switch (self) {
            .january => "January",
            .february => "February",
            .march => "March",
            .april => "April",
            .may => "May",
            .june => "June",
            .july => "July",
            .august => "August",
            .september => "September",
            .october => "October",
            .november => "November",
            .december => "December",
        };
    }
};

/// Compact Proleptic Gregorian calendar date (`year`, `month`, `day`).
pub const Date = struct {
    year: i32,
    month: u8,
    day: u8,

    pub fn init(year: i32, month: u8, day: u8) Date {
        const m = std.math.clamp(month, 1, 12);
        const max_d = daysInMonth(year, m);
        return .{ .year = year, .month = m, .day = std.math.clamp(day, 1, max_d) };
    }

    pub fn isLeapYear(year: i32) bool {
        return (@mod(year, 4) == 0 and @mod(year, 100) != 0) or @mod(year, 400) == 0;
    }

    pub fn daysInMonth(year: i32, month: u8) u8 {
        return switch (month) {
            1, 3, 5, 7, 8, 10, 12 => 31,
            4, 6, 9, 11 => 30,
            2 => if (isLeapYear(year)) 29 else 28,
            else => 30,
        };
    }

    /// Computes day of week using Tomohiko Sakamoto's algorithm.
    pub fn weekday(self: Date) Weekday {
        const offsets = [_]i32{ 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 };
        var y = self.year;
        if (self.month < 3) y -= 1;
        const w = @mod(y + @divFloor(y, 4) - @divFloor(y, 100) + @divFloor(y, 400) + offsets[self.month - 1] + @as(i32, self.day), 7);
        return @fromBackingInt(@intCast(@as(u3, @intCast(w))));
    }

    pub fn eql(a: Date, b: Date) bool {
        return a.year == b.year and a.month == b.month and a.day == b.day;
    }

    /// Shifts by signed `months` while clamping `day` cleanly inside the target month.
    pub fn addMonths(self: Date, delta: i32) Date {
        const total_months = (self.year * 12) + (@as(i32, self.month) - 1) + delta;
        const next_y = @divFloor(total_months, 12);
        const next_m: u8 = @intCast(@mod(total_months, 12) + 1);
        return Date.init(next_y, next_m, self.day);
    }

    /// Steps backward or forward across month/year boundaries by signed `delta` days.
    pub fn addDays(self: Date, delta: i32) Date {
        var cur = self;
        var rem = delta;
        while (rem > 0) {
            const dim = daysInMonth(cur.year, cur.month);
            if (@as(i32, cur.day) + rem <= dim) {
                cur.day = @intCast(@as(i32, cur.day) + rem);
                return cur;
            }
            rem -= (@as(i32, dim) - @as(i32, cur.day) + 1);
            cur = Date.init(if (cur.month == 12) cur.year + 1 else cur.year, if (cur.month == 12) 1 else cur.month + 1, 1);
        }
        while (rem < 0) {
            if (@as(i32, cur.day) + rem >= 1) {
                cur.day = @intCast(@as(i32, cur.day) + rem);
                return cur;
            }
            rem += @as(i32, cur.day);
            const prev_m: u8 = if (cur.month == 1) 12 else cur.month - 1;
            const prev_y = if (cur.month == 1) cur.year - 1 else cur.year;
            cur = .{ .year = prev_y, .month = prev_m, .day = daysInMonth(prev_y, prev_m) };
        }
        return cur;
    }
};

/// Style annotation attached to a specific calendar `Date`.
pub const CalendarEvent = struct {
    date: Date,
    style: Style,
};

/// Interactive state tracking highlighted cursor/view month in `Calendar`.
pub const CalendarState = struct {
    /// Currently focused/selected date.
    cursor: Date,
    /// Optional "today" marker date rendered distinctly.
    today: ?Date = null,

    pub fn init(cursor: Date) CalendarState {
        return .{ .cursor = cursor };
    }

    /// Processes Left/Right/Up/Down/PgUp/PgDn keys and scroll wheel; returns `true` when cursor moved.
    pub fn handleEvent(self: *CalendarState, event: Event, focused: bool) bool {
        switch (event) {
            .mouse => |m| {
                if (m.kind == .scroll_up) {
                    self.cursor = self.cursor.addMonths(-1);
                    return true;
                }
                if (m.kind == .scroll_down) {
                    self.cursor = self.cursor.addMonths(1);
                    return true;
                }
                return false;
            },
            .key => |k| {
                if (!focused or k.kind == .release) return false;
                switch (k.code) {
                    .left => {
                        self.cursor = self.cursor.addDays(-1);
                        return true;
                    },
                    .right => {
                        self.cursor = self.cursor.addDays(1);
                        return true;
                    },
                    .up => {
                        self.cursor = self.cursor.addDays(-7);
                        return true;
                    },
                    .down => {
                        self.cursor = self.cursor.addDays(7);
                        return true;
                    },
                    .page_up => {
                        self.cursor = self.cursor.addMonths(-1);
                        return true;
                    },
                    .page_down => {
                        self.cursor = self.cursor.addMonths(1);
                        return true;
                    },
                    .home => {
                        if (self.today) |td| {
                            self.cursor = td;
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

    /// Handles keyboard, wheel, and left-mouse clicks directly on day cells inside `area`.
    pub fn handleEventAt(self: *CalendarState, event: Event, area: Rect, cal: Calendar, focused: bool) bool {
        if (event == .mouse) {
            const m = event.mouse;
            const layout = cal.gridLayout(area, self.cursor) orelse return false;
            if (!m.isInside(layout.inner)) return false;
            if (m.isLeftClickInside(layout.inner)) {
                if (m.y >= layout.grid_y and m.x >= layout.grid_x) {
                    const row = m.y - layout.grid_y;
                    const rel_x = m.x - layout.grid_x;
                    const visual_col = rel_x / 3;
                    const in_cell = (rel_x % 3) < 2;
                    if (row < 6 and visual_col < 7 and in_cell) {
                        const col = if (cal.direction == .rtl) 6 - visual_col else visual_col;
                        const clicked = layout.first_cell_date.addDays(@as(i32, @intCast(row * 7 + col)));
                        if (clicked.month == self.cursor.month or cal.show_surrounding) {
                            self.cursor = clicked;
                            return true;
                        }
                    }
                }
                return false;
            }
            return self.handleEvent(event, focused);
        }
        return self.handleEvent(event, focused);
    }
};

/// Monthly calendar grid widget with configurable start-of-week (`monday` or `sunday`),
/// surrounding days, event styling, and keyboard cursor navigation.
pub const Calendar = struct {
    /// Displayed date (`year` and `month` used when rendered statelessly; overridden by `state.cursor` when stateful).
    display_date: Date = .{ .year = 2026, .month = 11, .day = 1 },
    /// Optional event annotations highlighted on matching calendar cells.
    events: []const CalendarEvent = &.{},
    first_weekday: Weekday = .monday,
    month_names: ?[12][]const u8 = null,
    weekday_names: ?[7][]const u8 = null,
    direction: text_root.TextDirection = .ltr,
    show_month_header: bool = true,
    show_weekdays_header: bool = true,
    show_surrounding: bool = true,
    block: ?Block = null,
    header_style: ?Style = null,
    weekday_style: ?Style = null,
    day_style: ?Style = null,
    weekend_style: ?Style = null,
    surrounding_style: ?Style = null,
    today_style: ?Style = null,
    selected_style: ?Style = null,
    focused: bool = true,

    pub const GridLayout = struct {
        inner: Rect,
        grid_x: u16,
        grid_y: u16,
        first_cell_date: Date,
    };

    /// Computes header-adjusted day grid origin and first cell `Date` inside `area`.
    pub fn gridLayout(self: Calendar, area: Rect, view_cursor: Date) ?GridLayout {
        const inner = if (self.block) |b| b.inner(area) else area;
        if (inner.width < 20 or inner.height < 6) return null;

        var y = inner.top();
        if (self.show_month_header and y < inner.bottom()) y += 1;
        if (self.show_weekdays_header and y < inner.bottom()) y += 1;

        const grid_x = inner.left() + (inner.width -| 20) / 2;
        const first_idx: u8 = @backingInt(self.first_weekday);
        const first_of_month = Date.init(view_cursor.year, view_cursor.month, 1);
        const first_wd: u8 = @backingInt(first_of_month.weekday());
        const leading_blanks: i32 = @mod(@as(i32, first_wd) - @as(i32, first_idx), 7);
        return .{
            .inner = inner,
            .grid_x = grid_x,
            .grid_y = y,
            .first_cell_date = first_of_month.addDays(-leading_blanks),
        };
    }

    /// Stateless render showing `self.display_date`.
    pub fn render(self: Calendar, ui: *Ui, area: Rect) !void {
        var st = CalendarState{ .cursor = self.display_date };
        try self.renderStateful(ui, area, &st);
    }

    /// Stateful render displaying `state.cursor`'s month with selected day & today markers.
    pub fn renderStateful(self: Calendar, ui: *Ui, area: Rect, state: *CalendarState) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.width < 20 or inner.height < 6) return;

        const view_year = state.cursor.year;
        const view_month = state.cursor.month;
        var y = inner.top();
        var rtl_buf: [128]u8 = undefined;

        // 1. Month + Year Header.
        if (self.show_month_header and y < inner.bottom()) {
            const m_name: []const u8 = if (self.month_names) |names|
                names[(view_month - 1) % 12]
            else
                (@as(Month, @fromBackingInt(@intCast(@as(u4, @intCast(view_month)))))).name();
            var title_buf: [96]u8 = undefined;
            const raw_title = std.fmt.bufPrint(&title_buf, "{s} {d}", .{ m_name, view_year }) catch "";
            const title = text_root.visualOrderInto(raw_title, self.direction, &rtl_buf);
            const hdr_s = self.header_style orelse ui.theme.title;
            const tw = text_root.displayWidth(title);
            const tx = inner.left() + (inner.width -| tw) / 2;
            _ = ui.buffer.setStringClipped(tx, y, title, inner.width, hdr_s, inner);
            y += 1;
        }

        const grid_x = inner.left() + (inner.width -| 20) / 2;
        const first_idx: u8 = @backingInt(self.first_weekday);
        const is_rtl = self.direction == .rtl;

        // 2. Weekday Column Strip (7 * 3 - 1 = 20 cols).
        if (self.show_weekdays_header and y < inner.bottom()) {
            const wd_s = self.weekday_style orelse ui.theme.accent;
            for (0..7) |col| {
                const wd_idx = (first_idx + col) % 7;
                const raw_lbl: []const u8 = if (self.weekday_names) |wds|
                    wds[wd_idx]
                else
                    (@as(Weekday, @fromBackingInt(@intCast(@as(u3, @intCast(wd_idx)))))).shortName();
                const wd_lbl = text_root.visualOrderInto(raw_lbl, self.direction, &rtl_buf);
                const visual_col = if (is_rtl) 6 - col else col;
                _ = ui.buffer.setStringClipped(grid_x + @as(u16, @intCast(visual_col * 3)), y, wd_lbl, 2, wd_s, inner);
            }
            y += 1;
        }

        // 3. Weeks (up to 6 rows of 7 days).
        const first_of_month = Date.init(view_year, view_month, 1);
        const first_wd: u8 = @backingInt(first_of_month.weekday());
        const leading_blanks: i32 = @mod(@as(i32, first_wd) - @as(i32, first_idx), 7);
        var cur = first_of_month.addDays(-leading_blanks);

        const default_s = self.day_style orelse ui.theme.text;
        const wknd_s = self.weekend_style orelse ui.theme.muted;
        const surr_s = self.surrounding_style orelse ui.theme.disabled;
        const today_s = self.today_style orelse ui.theme.info.patch(.{ .bold = true, .underline = true });
        const sel_s = self.selected_style orelse if (self.focused) ui.theme.selection else ui.theme.muted.patch(.{ .reverse = true });

        var row: u16 = 0;
        var day_buf: [4]u8 = undefined;
        while (row < 6 and y + row < inner.bottom()) : (row += 1) {
            for (0..7) |col| {
                const in_month = cur.month == view_month and cur.year == view_year;
                const is_sel = cur.eql(state.cursor);
                const is_today = if (state.today) |td| cur.eql(td) else false;

                var cell_s: Style = if (!in_month)
                    surr_s
                else if (cur.weekday().isWeekend())
                    wknd_s
                else
                    default_s;

                if (in_month) {
                    for (self.events) |ev| {
                        if (ev.date.eql(cur)) cell_s = cell_s.patch(ev.style);
                    }
                }
                if (is_today) cell_s = cell_s.patch(today_s);
                if (is_sel) cell_s = sel_s;

                const visual_col = if (is_rtl) 6 - col else col;
                const cx = grid_x + @as(u16, @intCast(visual_col * 3));
                const gy = y + row;
                if (in_month or self.show_surrounding) {
                    const txt = std.fmt.bufPrint(&day_buf, "{d: >2}", .{cur.day}) catch "  ";
                    _ = ui.buffer.setStringClipped(cx, gy, txt, 2, cell_s, inner);
                }
                cur = cur.addDays(1);
            }
        }
    }
};

test "calendar Gregorian math and monthly grid render accurately" {
    const d = Date.init(2026, 2, 28);
    try testing.expect(!Date.isLeapYear(2026));
    try testing.expect(Date.isLeapYear(2024));
    try testing.expectEqual(@as(u8, 1), d.addDays(1).day);
    try testing.expectEqual(@as(u8, 3), d.addDays(1).month);

    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 26, 10));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    var st = CalendarState{ .cursor = Date.init(2026, 11, 26), .today = Date.init(2026, 11, 26) };
    try ui.renderStateful(Calendar{ .block = .{ .title = "Schedule" } }, &st, buf.area);

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "November 2026") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "Mo Tu We Th Fr Sa Su") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "26") != null);

    // Clicking on a day cell inside the rendered grid updates `state.cursor`.
    const cal = Calendar{ .block = .{ .title = "Schedule" } };
    const gl = cal.gridLayout(buf.area, st.cursor).?;
    try testing.expect(st.handleEventAt(.{ .mouse = .{ .kind = .down, .button = .left, .x = gl.grid_x, .y = gl.grid_y } }, buf.area, cal, true));
    try testing.expectEqual(gl.first_cell_date.day, st.cursor.day);

    const month_before = st.cursor.month;
    try testing.expect(st.handleEvent(.{ .mouse = .{ .kind = .scroll_down, .x = 0, .y = 0 } }, true));
    try testing.expect(st.cursor.month != month_before);
}
