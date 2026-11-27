const std = @import("std");
const tui = @import("tui");

const State = struct {
    cpu: f64 = 0.64,
    mem: f64 = 0.42,
    disk: f64 = 0.88,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    if (event == .key and event.key.kind != .release) {
        if (event.key.code == .right or event.key.code == .up) {
            state.cpu = @min(1.0, state.cpu + 0.05);
            state.mem = @min(1.0, state.mem + 0.04);
        } else if (event.key.code == .left or event.key.code == .down) {
            state.cpu = @max(0.0, state.cpu - 0.05);
            state.mem = @max(0.0, state.mem - 0.04);
        }
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "Gauges", .right = "Arrows Adjust Load" }, hdr.area);

    var body = layout[1].margin(tui.Margin.uniform(1));
    try body.panel(.{ .title = "Sub-cell 1/8th Fractional Gauges", .padding = tui.Padding.uniform(1) }, body.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            try p.gauge(.{
                .ratio = st.cpu,
                .block = .{ .title = "CPU Usage", .border_type = .rounded },
                .gauge_style = p.theme.accent,
            }, null);
            p.space(1);
            try p.gauge(.{
                .ratio = st.mem,
                .block = .{ .title = "Memory Pool", .border_type = .rounded },
                .gauge_style = p.theme.success,
            }, null);
            p.space(1);
            try p.gauge(.{
                .ratio = st.disk,
                .label = "NVMe Cache 88%",
                .block = .{ .title = "Disk Throughput", .border_type = .rounded },
                .gauge_style = p.theme.warning,
            }, null);
            p.space(1);
            try p.lineGauge(.{
                .ratio = st.cpu,
                .label = "Compact Line Gauge ",
            }, null);
        }
    }.draw);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = "GAUGE", .badge = true }},
        .right = &.{.{ .text = "Arrows Adjust  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 80, .height = 24 } } else .auto,
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        _ = try onEvent(&state, .{ .key = .{ .code = .up } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "NVMe Cache 88%") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
