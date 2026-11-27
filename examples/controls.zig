const std = @import("std");
const tui = @import("tui");

const State = struct {
    turbo: bool = true,
    details_open: bool = true,
    volume: tui.SliderState = .{ .value = 65, .step = 5 },
    focus: tui.FocusGroup = .{ .count = 3 },
    switch_rect: tui.Rect = tui.Rect.zero,
    slider_rect: tui.Rect = tui.Rect.zero,
    accordion_rect: tui.Rect = tui.Rect.zero,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    if (state.focus.handleEvent(event)) return true;

    if (event == .mouse and event.mouse.kind == .down and event.mouse.button == .left) {
        if (event.mouse.isInside(state.switch_rect)) state.focus.active = 0;
        if (event.mouse.isInside(state.slider_rect)) state.focus.active = 1;
        if (event.mouse.isInside(tui.Rect.init(state.accordion_rect.x, state.accordion_rect.y, state.accordion_rect.width, 1))) state.focus.active = 2;
    }

    if (state.focus.isFocused(0)) {
        _ = tui.Switch.handleEvent(&state.turbo, event, state.switch_rect, true);
    } else if (state.focus.isFocused(1)) {
        _ = (tui.Slider{ .label = "Output Gain", .focused = true }).handleEvent(&state.volume, event, state.slider_rect);
    } else {
        _ = tui.Accordion.handleEvent(&state.details_open, event, state.accordion_rect, true);
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "Modern Controls", .right = "Tab Switch  Space/Arrows/Click Interact" }, hdr.area);

    var body = layout[1].margin(tui.Margin.uniform(1));
    try body.panel(.{
        .title = "Switch, Slider, Accordion & Badges",
        .padding = tui.Padding.uniform(1),
    }, body.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            st.switch_rect = p.allocateRows(1);
            p.switchToggle(.{
                .label = "Hardware Acceleration",
                .on = st.turbo,
                .focused = st.focus.isFocused(0),
            }, st.switch_rect);
            p.space(1);

            st.slider_rect = p.allocateRows(1);
            try p.slider(.{
                .label = "Output Gain",
                .focused = st.focus.isFocused(1),
            }, &st.volume, st.slider_rect);
            p.space(1);

            const b_cols = p.cols(3, .{ .{ .length = 12 }, .{ .length = 12 }, .{ .length = 14 } }, .{ .spacing = .{ .space = 1 } });
            var b0 = b_cols[0];
            b0.badge(.{ .label = "STABLE", .variant = .success }, b0.allocateRows(1));
            var b1 = b_cols[1];
            b1.badge(.{ .label = "WARNING", .variant = .warning }, b1.allocateRows(1));
            var b2 = b_cols[2];
            b2.badge(.{ .label = "OKLCH v4", .variant = .info }, b2.allocateRows(1));
            p.space(2);

            st.accordion_rect = p.available();
            try p.accordion(.{
                .title = "OKLCH OKLCH Telemetry (Expandable)",
                .expanded = st.details_open,
                .focused = st.focus.isFocused(2),
            }, st.accordion_rect, {}, struct {
                fn drawInner(_: void, inner: *tui.Ui) !void {
                    try inner.paragraph(.{
                        .raw = "Built-in OKLCH OKLCH scales (`tui.palette.sky.c400`) and interactive range sliders.",
                        .wrap = .word,
                        .style = .{ .foreground = tui.palette.sky.c300 },
                    }, null);
                }
            }.drawInner);
        }
    }.draw);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = "CONTROLS", .badge = true }},
        .right = &.{.{ .text = "Tab Cycle  Space/Arrows Edit  q Quit" }},
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
        state.focus.active = 1;
        _ = try onEvent(&state, .{ .key = .{ .code = .right } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "70") != null);
        std.debug.assert(std.mem.indexOf(u8, snap, "STABLE") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
