const std = @import("std");
const tui = @import("tui");

const State = struct {
    click_count: usize = 0,
    last_x: u16 = 0,
    last_y: u16 = 0,
    scroll_val: i32 = 50,
    hover_box: u8 = 0,
    pulse_phase: f64 = 0.0,
    left_box: tui.Rect = tui.Rect.zero,
    right_box: tui.Rect = tui.Rect.zero,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    if (event == .tick) {
        state.pulse_phase += app.deltaSeconds() * 5.0;
        return true;
    }
    if (event == .mouse) {
        const m = event.mouse;
        state.last_x = m.x;
        state.last_y = m.y;
        state.hover_box = if (m.isInside(state.left_box))
            1
        else if (m.isInside(state.right_box))
            2
        else
            0;
        if (m.kind == .down and m.button == .left) state.click_count += 1;
        if (m.kind == .scroll_up) state.scroll_val = @min(100, state.scroll_val + 5);
        if (m.kind == .scroll_down) state.scroll_val = @max(0, state.scroll_val - 5);
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});
    var hdr = layout[0];
    hdr.header(.{ .title = "Mouse Tracking", .right = "Click / Move / Scroll Wheel" }, hdr.area);

    var body = layout[1];
    try body.panel(.{ .title = "Hit Test Zones", .padding = tui.Padding.uniform(1) }, body.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            const zones = p.cols(2, .{ .{ .fill = 1 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 2 } });
            var z1 = zones[0];
            const b1 = z1.allocateRows(3);
            st.left_box = b1;
            try z1.button(.{ .label = "Zone A (Click)", .focused = st.hover_box == 1, .variant = .primary }, b1);
            if (st.hover_box == 1) tui.fx.pulseHighlight(z1.buffer, b1, st.pulse_phase, .cyan);

            var z2 = zones[1];
            const b2 = z2.allocateRows(3);
            st.right_box = b2;
            try z2.button(.{ .label = "Zone B (Click)", .focused = st.hover_box == 2, .variant = .success }, b2);
            if (st.hover_box == 2) tui.fx.pulseHighlight(z2.buffer, b2, st.pulse_phase, .green);

            p.space(4);
            try p.gauge(.{
                .ratio = @as(f64, @floatFromInt(st.scroll_val)) / 100.0,
                .label = "Mouse Wheel Meter",
                .block = .{ .title = "Scroll Wheel" },
            }, null);
            p.space(1);
            var info_buf: [64]u8 = undefined;
            const info = std.fmt.bufPrint(&info_buf, "Pointer: ({d}, {d})   Clicks: {d}   Active Zone: {d}", .{
                st.last_x,
                st.last_y,
                st.click_count,
                st.hover_box,
            }) catch "";
            try p.text(info, .{ .style = p.theme.muted }, null);
        }
    }.draw);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = "MOUSE", .badge = true }},
        .right = &.{.{ .text = "q Quit" }},
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
        // First draw populates exact responsive hitboxes in `state`.
        try app.draw(&state, render);
        const cx = state.left_box.left() + 2;
        const cy = state.left_box.top() + 1;
        _ = try onEvent(&state, .{ .mouse = .{ .kind = .down, .button = .left, .x = cx, .y = cy } }, &app);
        _ = try onEvent(&state, .{ .mouse = .{ .kind = .scroll_up, .x = cx, .y = cy } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Clicks: 1   Active Zone: 1") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
