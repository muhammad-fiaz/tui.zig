const std = @import("std");
const tui = @import("tui");

const State = struct {
    ticks: u64 = 0,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    switch (event) {
        .key => |k| {
            if (k.isChar('q') or event.isEscape() or event.isCtrlC()) {
                app.quit();
                return false;
            }
        },
        .tick => state.ticks +%= 1,
        else => {},
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();

    const layout = ui.rows(3, .{
        .{ .length = 1 },
        .{ .fill = 1 },
        .{ .length = 1 },
    }, .{});

    var top = layout[0];
    top.header(.{
        .title = ui.app.name,
        .subtitle = ui.app.description,
        .right = "v" ++ tui.version,
    }, top.area);

    var center = layout[1].margin(tui.Margin.symmetric(4, 2));
    try center.panel(.{
        .title = "Welcome",
        .border_type = .rounded,
        .focused = true,
        .padding = tui.Padding.uniform(1),
    }, center.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            try p.paragraph(.{
                .raw = "Hello from native Zig terminal UI!\n\nThis window adapts dynamically to terminal dimensions, renders through a diffed double buffer, and restores your terminal cleanly on exit.",
                .wrap = .word,
                .alignment = .center,
            }, null);
            p.space(1);
            p.spinner(.{ .tick = st.ticks, .label = "Running event loop smoothly" }, null);
        }
    }.draw);

    var bottom = layout[2];
    bottom.statusBar(.{
        .left = &.{ .{ .text = "READY", .badge = true }, .{ .text = "Hello World Example" } },
        .right = &.{.{ .text = "q / Esc Quit" }},
    }, bottom.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .app = .{
            .name = "tui.zig",
            .version = tui.version,
            .description = "Hello World",
            .title = "tui.zig — Hello World",
        },
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 72, .height = 20 } } else .auto,
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Hello from native Zig") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
