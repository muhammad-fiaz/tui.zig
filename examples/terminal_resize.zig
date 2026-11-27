const std = @import("std");
const tui = @import("tui");

const State = struct {
    resizes: usize = 0,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    if (event == .resize) state.resizes += 1;
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const w = ui.area.width;
    const h = ui.area.height;
    const tier: []const u8 = if (w < 50) "COMPACT (<50 cols)" else if (w < 90) "MEDIUM (50-89 cols)" else "WIDE (>=90 cols)";

    var size_buf: [48]u8 = undefined;
    const dim_str = std.fmt.bufPrint(&size_buf, "{d}x{d} (resizes: {d})", .{ w, h, state.resizes }) catch "";

    const rows = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});
    var hdr = rows[0];
    hdr.header(.{ .title = "Responsive Layout", .subtitle = tier, .right = dim_str }, hdr.area);

    var body = rows[1].margin(tui.Margin.uniform(1));
    if (w < 50) {
        // Single stacked layout for narrow terminals.
        try body.panel(.{ .title = "Stacked View" }, body.area, {}, struct {
            fn draw(_: void, p: *tui.Ui) !void {
                try p.paragraph(.{ .raw = "Narrow terminal detected: collapsed into a single-column pane.", .wrap = .word }, null);
            }
        }.draw);
    } else if (w < 90) {
        const two = body.cols(2, .{ .{ .length = 24 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 1 } });
        var c0 = two[0];
        try c0.block(.{ .title = "Nav Rail" }, c0.area);
        var c1 = two[1];
        try c1.block(.{ .title = "Main Content", .focused = true }, c1.area);
    } else {
        const three = body.cols(3, .{ .{ .length = 22 }, .{ .fill = 2 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 1 } });
        var c0 = three[0];
        try c0.block(.{ .title = "Sidebar" }, c0.area);
        var c1 = three[1];
        try c1.block(.{ .title = "Workspace", .focused = true }, c1.area);
        var c2 = three[2];
        try c2.block(.{ .title = "Inspector" }, c2.area);
    }

    var ft = rows[2];
    ft.statusBar(.{
        .left = &.{.{ .text = tier, .badge = true }},
        .right = &.{.{ .text = "Resize terminal window  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 100, .height = 24 } } else .auto,
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        try app.draw(&state, render);
        var snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "WIDE") != null);

        try app.resizeTest(.{ .width = 40, .height = 14 });
        _ = try onEvent(&state, .{ .resize = .{ .width = 40, .height = 14 } }, &app);
        try app.draw(&state, render);
        snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "COMPACT") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
