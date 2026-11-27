const std = @import("std");
const tui = @import("tui");

const State = struct {
    tick: u64 = 0,
    table: tui.TableState = .{ .selected = 0 },
    cpu_spring: tui.Spring = .{ .value = 0.45, .target = 0.45, .stiffness = 110.0, .damping = 14.0 },
};

const procs = [_]tui.TableRow{
    tui.TableRow.fromStrings(&.{ "1042", "zig-build", "18.4%", "412 MB" }),
    tui.TableRow.fromStrings(&.{ "1108", "postgres", "7.2%", "290 MB" }),
    tui.TableRow.fromStrings(&.{ "1290", "caddy", "1.1%", "64 MB" }),
    tui.TableRow.fromStrings(&.{ "1401", "metrics", "0.5%", "38 MB" }),
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    switch (event) {
        .tick => {
            state.tick +%= 1;
            const wave: f64 = 0.48 + 0.30 * @sin(@as(f64, @floatFromInt(state.tick)) * 0.14);
            state.cpu_spring.setTarget(std.math.clamp(wave, 0.10, 0.95));
            _ = state.cpu_spring.step(app.deltaMs());
        },
        .key => |k| {
            if (k.kind == .release) return true;
            if (k.code == .down or k.isChar('j')) state.table.selectNext(procs.len);
            if (k.code == .up or k.isChar('k')) state.table.selectPrevious(procs.len);
        },
        else => {},
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(4, .{
        .{ .length = 1 },
        .{ .length = 7 },
        .{ .fill = 1 },
        .{ .length = 1 },
    }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "System Monitor", .subtitle = "Host telemetry", .right = "20 FPS" }, hdr.area);

    const top_cols = layout[1].cols(2, .{ .{ .percentage = 50 }, .{ .fill = 1 } }, .{ .margin = tui.Margin.symmetric(1, 0), .spacing = .{ .space = 1 } });
    var g_panel = top_cols[0];
    try g_panel.panel(.{ .title = "Resources" }, g_panel.area, state.cpu_spring.value, struct {
        fn draw(cpu_val: f64, p: *tui.Ui) !void {
            try p.gauge(.{ .ratio = std.math.clamp(cpu_val, 0.0, 1.0), .label = "CPU Cores 0-7" }, null);
            p.space(1);
            try p.lineGauge(.{ .ratio = 0.58, .label = "RAM 18.6/32 GB " }, null);
        }
    }.draw);

    var b_panel = top_cols[1];
    try b_panel.barChart(.{
        .bars = &.{
            tui.Bar.init("Core0", 62),
            tui.Bar.init("Core1", 48),
            tui.Bar.init("Core2", 81),
            tui.Bar.init("Core3", 39),
        },
        .block = .{ .title = "Per-Core Load (%)" },
        .bar_width = 5,
    }, b_panel.area);

    var bottom = layout[2].margin(tui.Margin.uniform(1));
    try bottom.table(.{
        .header = tui.TableRow.fromStrings(&.{ "PID", "Command", "CPU", "RSS" }),
        .rows = &procs,
        .widths = &.{ .{ .length = 8 }, .{ .length = 16 }, .{ .length = 10 }, .{ .fill = 1 } },
        .block = .{ .title = "Top Processes", .focused = true },
        .show_header_separator = true,
    }, &state.table, bottom.area);

    var ft = layout[3];
    ft.statusBar(.{
        .left = &.{.{ .text = "MONITOR", .badge = true }},
        .right = &.{.{ .text = "Up/Down Select  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 90, .height = 24 } } else .auto,
        .settings = .{ .fps = 20 },
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        _ = app.advanceTimer();
        _ = try onEvent(&state, .tick, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "zig-build") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
