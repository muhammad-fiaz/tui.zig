const std = @import("std");
const tui = @import("tui");

const State = struct {
    marker_idx: usize = 0,
    tick: u64 = 0,
};

const markers = [_]tui.style.Marker{ .braille, .half_block, .quadrant };

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    if (event == .tick) state.tick +%= 1;
    if (event.isChar('m') or (event == .key and event.key.code == .enter)) {
        state.marker_idx = (state.marker_idx + 1) % markers.len;
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    const cur_marker = markers[state.marker_idx];
    var hdr = layout[0];
    hdr.header(.{ .title = "High-Res Canvas", .subtitle = @tagName(cur_marker), .right = "m Switch Marker" }, hdr.area);

    const shapes = [_]tui.Shape{
        .{ .rect = .{ .x = 8, .y = 10, .width = 84, .height = 80, .color = .blue } },
        .{ .circle = .{ .x = 50, .y = 50, .radius = 30, .color = .cyan } },
        .{ .line = .{ .x1 = 10, .y1 = 15, .x2 = 90, .y2 = 85, .color = .yellow } },
        .{ .line = .{ .x1 = 10, .y1 = 85, .x2 = 90, .y2 = 15, .color = .magenta } },
    };

    var body = layout[1].margin(tui.Margin.uniform(1));
    const canvas = tui.Canvas{
        .x_bounds = .{ .min = 0, .max = 100 },
        .y_bounds = .{ .min = 0, .max = 100 },
        .marker = cur_marker,
        .shapes = &shapes,
        .block = .{ .title = "Vector Primitives", .focused = true },
    };
    try canvas.paintWith(&body, body.area, state.tick, struct {
        fn draw(tk: u64, painter: *tui.Painter) void {
            const phase = @as(f64, @floatFromInt(tk % 60)) * 0.1;
            const px = 50.0 + @cos(phase) * 20.0;
            const py = 50.0 + @sin(phase) * 20.0;
            painter.circle(px, py, 6.0, .green);
            painter.text(44, 50, "Origin", .{ .foreground = .white, .bold = true });
        }
    }.draw);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = @tagName(cur_marker), .badge = true }},
        .right = &.{.{ .text = "m Switch Marker  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 80, .height = 24 } } else .auto,
        .settings = .{ .fps = 20 },
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        try app.draw(&state, render);
        _ = try onEvent(&state, .{ .key = .{ .code = .{ .char = 'm' } } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Vector Primitives") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
