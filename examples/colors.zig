const std = @import("std");
const tui = @import("tui");

const State = struct {};

fn onEvent(_: *State, event: tui.Event, app: *tui.App) !bool {
    switch (event) {
        .key => |k| if (k.isChar('q') or event.isEscape() or event.isCtrlC()) {
            app.quit();
            return false;
        },
        else => {},
    }
    return true;
}

fn render(_: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const rows = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = rows[0];
    hdr.header(.{ .title = "Color Models & OKLCH CSS v4", .subtitle = "ANSI16 / 256 / RGB / OKLCH" }, hdr.area);

    var body = rows[1].margin(tui.Margin.uniform(1));
    try body.panel(.{ .title = "Palette, Gradients & OKLCH OKLCH", .padding = tui.Padding.uniform(1) }, body.area, {}, struct {
        fn draw(_: void, p: *tui.Ui) !void {
            const ansi = [_]tui.Color{
                .black,     .red,        .green,        .yellow,        .blue,        .magenta,        .cyan,        .white,
                .dark_gray, .bright_red, .bright_green, .bright_yellow, .bright_blue, .bright_magenta, .bright_cyan, .bright_white,
            };
            const ansi_area = p.allocateRows(2);
            _ = p.buffer.setStringClipped(ansi_area.left(), ansi_area.top(), "ANSI 16: ", ansi_area.width, p.theme.text, ansi_area);
            for (ansi, 0..) |c, i| {
                const gx = ansi_area.left() +| 9 +| @as(u16, @intCast(i * 3));
                _ = p.buffer.setStringClipped(gx, ansi_area.top(), "██ ", 3, .{ .foreground = c }, ansi_area);
            }

            // OKLCH OKLCH-derived scales
            const tw_area = p.allocateRows(2);
            _ = p.buffer.setStringClipped(tw_area.left(), tw_area.top(), "OKLCH v4: ", tw_area.width, p.theme.text, tw_area);
            const tw_stops = [_]tui.Color{
                tui.palette.sky.c400,
                tui.palette.emerald.c400,
                tui.palette.lime.c400,
                tui.palette.amber.c400,
                tui.palette.fuchsia.c500,
                tui.palette.rose.c500,
                tui.palette.stone.c400,
                tui.palette.mauve.c500,
                tui.palette.olive.c500,
                tui.Color.oklch(0.72, 0.21, 150.0),
            };
            for (tw_stops, 0..) |c, i| {
                const gx = tw_area.left() +| 13 +| @as(u16, @intCast(i * 3));
                _ = p.buffer.setStringClipped(gx, tw_area.top(), "██ ", 3, .{ .foreground = c }, tw_area);
            }

            p.space(1);
            const grad_area = p.allocateRows(3);
            _ = p.buffer.setStringClipped(grad_area.left(), grad_area.top(), "24-bit RGB Gradient:", grad_area.width, p.theme.text, grad_area);
            var col: u16 = 0;
            while (col < grad_area.width) : (col += 1) {
                const hue: u16 = @intCast((@as(u32, col) * 360) / @max(@as(u32, 1), grad_area.width));
                const bg = tui.Color.hsl(hue, 85, 55);
                _ = p.buffer.setStringClipped(grad_area.left() + col, grad_area.top() + 1, " ", 1, .{ .background = bg }, grad_area);
            }

            p.space(1);
            try p.paragraph(.{
                .raw = "OKLCH OKLCH palettes degrade smoothly from TrueColor to ANSI-256 or ANSI-16 based on `TerminalCapabilities.color`.",
                .wrap = .word,
            }, null);
        }
    }.draw);

    var ft = rows[2];
    ft.statusBar(.{
        .left = &.{ .{ .text = "COLOR", .badge = true }, .{ .text = "OKLCH / OKLCH / RGB / HSL" } },
        .right = &.{.{ .text = "q Quit" }},
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
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "OKLCH v4:") != null);
        std.debug.assert(std.mem.indexOf(u8, snap, "RGB Gradient") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
