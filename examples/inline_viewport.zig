const std = @import("std");
const tui = @import("tui");

const State = struct {
    progress: f64 = 0.0,
    done: usize = 0,
    ticks: u64 = 0,
};

const step_logs = [_][]const u8{
    "Step 1/4 resolved manifest [OK]",
    "Step 2/4 fetched dependencies [OK]",
    "Step 3/4 verified checksums [OK]",
    "Step 4/4 build artifacts cached [DONE]",
};

fn render(state: *State, ui: *tui.Ui) !void {
    const blk = tui.Block{
        .title = "Inline Viewport Progress (q / Esc Quit)",
        .border_type = .rounded,
        .padding = tui.Padding.symmetric(1, 0),
    };
    try blk.render(ui, ui.area);
    const inner = blk.inner(ui.area);
    var sub = ui.region(inner);
    try sub.progress(.{
        .label = if (state.done >= step_logs.len) "All steps finished" else "Downloading packages",
        .ratio = state.progress,
    }, sub.allocateRows(1));
}

fn logStep(msg: []const u8, buf: *tui.Buffer) void {
    _ = buf.setStringClipped(0, 0, msg, buf.area.width, .{ .foreground = .green, .bold = true }, buf.area);
}

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    if (event == .tick) {
        state.ticks +%= 1;
        if (state.done < step_logs.len and state.ticks % 6 == 0) {
            try app.insertBefore(1, step_logs[state.done], logStep);
            state.done += 1;
            state.progress = @as(f64, @floatFromInt(state.done)) / @as(f64, @floatFromInt(step_logs.len));
        }
    }
    return true;
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 64, .height = 12 } } else .auto,
        .viewport = .{ .inline_height = 4 },
        .settings = .{ .alternate_screen = false, .fps = 12 },
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        try app.insertBefore(1, step_logs[2], logStep);
        state.done = 3;
        state.progress = 0.75;
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Inline Viewport Progress") != null);
        std.debug.assert(std.mem.indexOf(u8, app.scrollback(), "verified checksums") != null);
        return;
    }

    try app.enter();
    try app.insertBefore(1, step_logs[0], logStep);
    state.done = 1;
    state.progress = 0.25;
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
