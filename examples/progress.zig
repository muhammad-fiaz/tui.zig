const std = @import("std");
const tui = @import("tui");

const State = struct {
    tick: u64 = 0,
    ratio: f64 = 0.25,
    smooth_ratio: tui.Spring = .{ .value = 0.25, .target = 0.25, .stiffness = 140.0, .damping = 16.0 },
    shimmer_phase: f64 = 0.0,
    toast: tui.ToastState = .{},
    notified_done: bool = false,
    paused: bool = false,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    switch (event) {
        .tick => if (!state.paused) {
            const dt = app.deltaMs();
            state.tick +%= 1;
            state.shimmer_phase = @mod(state.shimmer_phase + app.deltaSeconds() * 0.85, 1.0);
            state.ratio += 0.015;
            if (state.ratio >= 1.0) {
                if (!state.notified_done) {
                    state.toast.show("Build", "All compilation targets finished!", .success);
                    state.notified_done = true;
                }
                if (state.ratio > 1.25) {
                    state.ratio = 0.0;
                    state.notified_done = false;
                }
            }
            state.smooth_ratio.setTarget(std.math.clamp(state.ratio, 0.0, 1.0));
            _ = state.smooth_ratio.step(dt);
            _ = state.toast.update(dt);
        },
        .key => |k| {
            if (k.kind == .release) return true;
            if (k.isChar(' ')) state.paused = !state.paused;
            if (k.isChar('r')) {
                state.ratio = 0.0;
                state.smooth_ratio.snap(0.0);
                state.notified_done = false;
                state.toast.show("Reset", "Progress restarted", .info);
            }
        },
        else => {},
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "Progress, Spinners & Loading Skeleton", .right = "Space Pause  r Reset" }, hdr.area);

    var body = layout[1].margin(tui.Margin.uniform(1));
    try body.panel(.{ .title = "Task Execution & Shimmer", .padding = tui.Padding.uniform(1) }, body.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            try p.progress(.{
                .label = if (st.ratio >= 1.0) "Completed" else "Compiling units",
                .ratio = std.math.clamp(st.smooth_ratio.value, 0.0, 1.0),
            }, null);
            p.space(1);
            try p.progress(.{ .indeterminate = true, .tick = st.tick }, null);
            p.space(1);
            try p.divider(.{ .label = "Spinner Presets" }, null);
            p.space(1);
            p.spinner(.{ .tick = st.tick, .label = "Braille dots spinner (default)", .frames = &tui.symbols.spinner.dots }, null);
            p.spinner(.{ .tick = st.tick, .label = "Arc spinner", .frames = &tui.symbols.spinner.arc }, null);
            p.spinner(.{ .tick = st.tick, .label = "Pulse spinner", .frames = &tui.symbols.spinner.pulse }, null);
            p.space(1);
            try p.skeleton(.{ .rows = 2, .phase = st.shimmer_phase }, null);
        }
    }.draw);

    try state.toast.render(ui, ui.area);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = if (state.paused) "PAUSED" else "RUNNING", .badge = true }},
        .right = &.{.{ .text = "Space Toggle  r Reset  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 80, .height = 20 } } else .auto,
        .settings = .{ .fps = 20 },
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        _ = app.advanceTimer();
        _ = try onEvent(&state, .tick, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Compiling units") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
