const std = @import("std");
const tui = @import("tui");

const total_lines: usize = 60;

const State = struct {
    scroll: tui.ScrollViewState = .{ .content_height = total_lines },
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    const vp = app.area().height -| 6;
    switch (event) {
        .mouse => |m| {
            if (m.kind == .scroll_down) state.scroll.scrollBy(2, vp);
            if (m.kind == .scroll_up) state.scroll.scrollBy(-2, vp);
        },
        .key => |k| {
            if (k.kind == .release) return true;
            if (k.code == .down or k.isChar('j')) state.scroll.scrollBy(1, vp);
            if (k.code == .up or k.isChar('k')) state.scroll.scrollBy(-1, vp);
            if (k.code == .page_down) state.scroll.scrollBy(@intCast(@max(1, vp)), vp);
            if (k.code == .page_up) state.scroll.scrollBy(-@as(isize, @intCast(@max(1, vp))), vp);
            if (k.code == .home) state.scroll.offset_y = 0;
            if (k.code == .end) state.scroll.offset_y = total_lines -| vp;
        },
        else => {},
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "ScrollView & Scrollbar", .right = "Up/Down/PgUp/PgDn" }, hdr.area);

    var body = layout[1].margin(tui.Margin.uniform(1));
    try body.scrollView(.{
        .block = .{ .title = "Log Stream (60 entries)", .focused = true },
        .content_height = total_lines,
    }, &state.scroll, body.area, {}, struct {
        fn draw(_: void, view: *tui.Ui, offset_y: usize) !void {
            var line_buf: [80]u8 = undefined;
            var r: u16 = 0;
            while (r < view.area.height) : (r += 1) {
                const idx = offset_y + r;
                if (idx >= total_lines) break;
                const txt = std.fmt.bufPrint(&line_buf, "[{d:0>3}] event=frame_flush latency_us={d}", .{ idx + 1, 120 + (idx * 7) % 90 }) catch "";
                _ = view.buffer.setStringClipped(view.area.left(), view.area.top() + r, txt, view.area.width, view.theme.text, view.area);
            }
        }
    }.draw);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = "SCROLL", .badge = true }},
        .right = &.{.{ .text = "Home/End/PgDn  q Quit" }},
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
        _ = try onEvent(&state, .{ .key = .{ .code = .page_down } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "latency_us=") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
