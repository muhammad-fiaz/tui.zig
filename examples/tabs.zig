const std = @import("std");
const tui = @import("tui");

const State = struct {
    tab: usize = 0,
    tabs_rect: tui.Rect = tui.Rect.init(0, 1, 80, 3),
};

const tab_titles = [_][]const u8{ "Overview", "Architecture", "Backends", "License" };

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    const bar = tui.Tabs{
        .titles = &tab_titles,
        .selected = state.tab,
        .block = .{ .border_type = .rounded },
    };
    if (bar.handleEvent(&state.tab, event, state.tabs_rect, true)) return true;
    if (event == .key and event.key.kind != .release) {
        switch (event.key.code) {
            .tab => state.tab = (state.tab + 1) % tab_titles.len,
            .back_tab => state.tab = if (state.tab == 0) tab_titles.len - 1 else state.tab - 1,
            .char => |c| if (c >= '1' and c <= '4') {
                state.tab = c - '1';
            },
            else => {},
        }
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(4, .{
        .{ .length = 1 },
        .{ .length = 3 },
        .{ .fill = 1 },
        .{ .length = 1 },
    }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "Tabs & Breadcrumbs", .right = "1-4 / Tab / Arrows" }, hdr.area);

    var tab_area = layout[1];
    state.tabs_rect = tab_area.area;
    try tab_area.tabs(.{
        .titles = &tab_titles,
        .selected = state.tab,
        .block = .{ .border_type = .rounded },
    }, tab_area.area);

    var page_area = layout[2].margin(tui.Margin.symmetric(1, 0));
    try page_area.panel(.{ .title = tab_titles[state.tab], .focused = true, .padding = tui.Padding.uniform(1) }, page_area.area, state.tab, struct {
        fn draw(tab: usize, p: *tui.Ui) !void {
            p.breadcrumbs(.{ .segments = &.{ "tui.zig", "Tabs", tab_titles[tab] } }, null);
            p.space(1);
            const content = switch (tab) {
                0 => "Overview tab: zero-allocation layout and retained buffer primitives designed for Zig 0.17.0+.",
                1 => "Architecture tab: clean separation between core cell buffers, OKLCH palettes, events, backends, and widgets.",
                2 => "Backends tab: native Win32 Console, POSIX termios/SIGWINCH, pure ANSI, and deterministic Memory backends.",
                else => "License tab: MIT Licensed (2026 Muhammad Fiaz). Pure Zig with zero C runtime dependencies.",
            };
            try p.paragraph(.{ .raw = content, .wrap = .word }, null);
        }
    }.draw);

    var ft = layout[3];
    ft.statusBar(.{
        .left = &.{.{ .text = tab_titles[state.tab], .badge = true }},
        .right = &.{.{ .text = "Left/Right or Click Switch  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 80, .height = 20 } } else .auto,
        .settings = .{ .mouse = true },
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        _ = try onEvent(&state, .{ .key = .{ .code = .right } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Architecture") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
