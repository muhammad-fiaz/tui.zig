const std = @import("std");
const tui = @import("tui");

const State = struct {
    cal: tui.CalendarState = .{
        .cursor = tui.Date.init(2026, 11, 26),
        .today = tui.Date.init(2026, 11, 26),
    },
    start_monday: bool = true,
    cal_rect: tui.Rect = tui.Rect.zero,
};

const events = [_]tui.CalendarEvent{
    .{ .date = tui.Date.init(2026, 11, 10), .style = .{ .foreground = .green, .bold = true } },
    .{ .date = tui.Date.init(2026, 11, 20), .style = .{ .foreground = .yellow, .bold = true } },
    .{ .date = tui.Date.init(2026, 12, 25), .style = .{ .foreground = .cyan, .bold = true } },
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    if (event.isChar('m')) {
        state.start_monday = !state.start_monday;
        return true;
    }
    _ = state.cal.handleEventAt(event, state.cal_rect, .{
        .events = &events,
        .first_weekday = if (state.start_monday) .monday else .sunday,
        .block = .{ .title = "Schedule", .focused = true },
    }, true);
    return true;
}

fn drawSelectedDatePanel(d: tui.Date, p: *tui.Ui) !void {
    var buf: [64]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, "Date: {d}-{d:0>2}-{d:0>2} ({s})", .{
        d.year,
        d.month,
        d.day,
        d.weekday().shortName(),
    }) catch "";
    try p.text(line, .{ .style = p.theme.accent }, null);
    p.space(1);
    try p.paragraph(.{
        .raw = "Use Left/Right/Up/Down to step days/weeks, PgUp/PgDn to change month, and Home to jump to today.",
        .wrap = .word,
    }, null);
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "Calendar", .right = "Arrows Move  PgUp/PgDn Month  m First Day" }, hdr.area);

    var cal_ui: tui.Ui = undefined;
    var info_ui: tui.Ui = undefined;
    if (layout[1].isCompact(58)) {
        const stacked = layout[1].rows(2, .{ .{ .length = 10 }, .{ .fill = 1 } }, .{ .margin = tui.Margin.uniform(1), .spacing = .{ .space = 1 } });
        cal_ui = stacked[0];
        info_ui = stacked[1];
    } else {
        const cols = layout[1].cols(2, .{ .{ .length = 30 }, .{ .fill = 1 } }, .{ .margin = tui.Margin.uniform(1), .spacing = .{ .space = 2 } });
        cal_ui = cols[0];
        info_ui = cols[1];
    }

    state.cal_rect = cal_ui.area;
    try cal_ui.calendar(.{
        .events = &events,
        .first_weekday = if (state.start_monday) .monday else .sunday,
        .block = .{ .title = "Schedule", .focused = true },
    }, &state.cal, cal_ui.area);

    try info_ui.panel(.{ .title = "Selected Date", .padding = tui.Padding.uniform(1) }, info_ui.area, state.cal.cursor, drawSelectedDatePanel);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = "CALENDAR", .badge = true }},
        .right = &.{.{ .text = "Home Today  m Monday/Sunday  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 80, .height = 18 } } else .auto,
        .settings = .{ .mouse = true },
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        _ = try onEvent(&state, .{ .key = .{ .code = .page_down } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "December 2026") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
