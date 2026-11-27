const std = @import("std");
const tui = @import("tui");

const State = struct {
    bounce_tween: tui.Tween = blk: {
        var tw = tui.Tween.init(0.0, 1.0, 1400, .ease_out_bounce);
        tw.mode = .ping_pong;
        break :blk tw;
    },
    wipe_tween: tui.Tween = blk: {
        var tw = tui.Tween.init(0.0, 1.0, 1800, .ease_in_out_cubic);
        tw.mode = .ping_pong;
        break :blk tw;
    },
    meter_spring: tui.Spring = .{ .value = 0.25, .target = 0.85, .stiffness = 140.0, .damping = 14.0 },
    modal_transition: tui.Transition = .{ .duration_ms = 260, .easing = .ease_out_cubic },
    toast: tui.ToastState = .{ .duration_ms = 2400 },
    loading: bool = true,
    shimmer_phase: f64 = 0.0,
    pulse_phase: f64 = 0.0,
    marquee_tick: usize = 0,
    char_tick: usize = 0,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    if (event.isEscape()) {
        if (state.modal_transition.active) {
            state.modal_transition.close();
            return true;
        }
        app.quit();
        return false;
    }
    switch (event) {
        .tick => {
            const dt = app.deltaMs();
            _ = state.bounce_tween.advance(dt);
            _ = state.wipe_tween.advance(dt);
            _ = state.meter_spring.step(dt);
            _ = state.modal_transition.update(dt);
            _ = state.toast.update(dt);
            const dt_s = app.deltaSeconds();
            state.shimmer_phase = @mod(state.shimmer_phase + dt_s * 0.75, 1.0);
            state.pulse_phase += dt_s * 4.5;
            state.marquee_tick +%= 1;
            if (state.marquee_tick % 2 == 0) state.char_tick +%= 1;
        },
        .key => |k| {
            if (k.kind == .release) return true;
            if (k.isChar('l')) {
                state.loading = !state.loading;
                state.toast.show("Loader", if (state.loading) "Showing Skeleton shimmer" else "Content revealed", .info);
            } else if (k.isChar('p')) {
                state.modal_transition.toggle();
            } else if (k.isChar('t')) {
                state.toast.show("Effect Triggered", "Fade + progress countdown toast", .success);
            } else if (k.isChar(' ')) {
                const next_t: f64 = if (state.meter_spring.target > 0.5) 0.18 else 0.92;
                state.meter_spring.setTarget(next_t);
            }
        },
        else => {},
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const rows = ui.rows(4, .{
        .{ .length = 1 },
        .{ .fill = 1 },
        .{ .length = 4 },
        .{ .length = 1 },
    }, .{});

    var hdr = rows[0];
    hdr.header(.{
        .title = "Animations, Easing & Visual Effects",
        .subtitle = if (state.loading) "Skeleton Loading" else "Live View",
        .right = "Space Spring  p Popup  t Toast  l Load",
    }, hdr.area);

    const mid_cols = rows[1].cols(2, .{ .{ .percentage = 50 }, .{ .fill = 1 } }, .{
        .margin = tui.Margin.uniform(1),
        .spacing = .{ .space = 1 },
    });

    // Left: Tweens & Spring meters
    var left = mid_cols[0];
    try left.panel(.{ .title = "Easing, Spring & Shimmer", .padding = tui.Padding.uniform(1) }, left.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            const g1_rect = p.allocateRows(1);
            try p.gauge(.{
                .ratio = st.bounce_tween.value(),
                .label = "Tween (ease_out_bounce)",
                .gauge_style = .{ .foreground = tui.palette.sky.c400 },
            }, g1_rect);
            tui.fx.shimmer(p.buffer, g1_rect, st.shimmer_phase, .white, 6.0);
            p.space(1);

            const g2_rect = p.allocateRows(1);
            try p.gauge(.{
                .ratio = std.math.clamp(st.meter_spring.value, 0.0, 1.0),
                .label = "Damped Spring Meter",
                .gauge_style = .{ .foreground = tui.palette.emerald.c400 },
            }, g2_rect);
            tui.fx.pulseHighlight(p.buffer, g2_rect, st.pulse_phase, tui.palette.teal.c300);
            p.space(1);

            const tw_txt = tui.fx.typewriterSlice(
                "Typewriter reveal: native zero-alloc Zig animations!",
                (st.char_tick % 60) + 1,
            );
            try p.text(tw_txt, .{ .style = .{ .foreground = tui.palette.amber.c300 } }, p.allocateRows(1));
        }
    }.draw);

    // Right: Skeleton loading shimmer vs Wipe/Dissolve reveal panel
    var right = mid_cols[1];
    try right.panel(.{
        .title = if (state.loading) "Loading Skeleton (Press l)" else "Dissolve / Wipe Reveal",
        .padding = tui.Padding.uniform(1),
    }, right.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            if (st.loading) {
                try p.skeleton(.{
                    .rows = 4,
                    .phase = st.shimmer_phase,
                    .highlight_color = tui.palette.sky.c300,
                }, null);
            } else {
                const reveal_area = p.area;
                try p.paragraph(.{
                    .raw = "Data loaded cleanly!\nSwipe / dissolve reveal and marquee stream active.",
                    .wrap = .word,
                    .style = .{ .foreground = tui.palette.emerald.c300 },
                }, reveal_area);
                tui.fx.sweepWipe(p.buffer, reveal_area, .horizontal, st.wipe_tween.value(), .cyan);
            }
        }
    }.draw);

    // Marquee banner row
    var mq_area = rows[2].margin(tui.Margin.symmetric(1, 0));
    try mq_area.panel(.{ .title = "Scrolling Marquee Ticker", .padding = tui.Padding.symmetric(1, 0) }, mq_area.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            var m_buf: [160]u8 = undefined;
            const ticker = tui.fx.marqueeSlice(
                "tui.zig v0.1.0 • Easing curves • Damped Spring physics • Shimmer skeletons • Sweep/Dissolve transitions • Zero C dependencies",
                st.marquee_tick,
                p.area.width,
                &m_buf,
            );
            _ = p.buffer.setStringClipped(p.area.left(), p.area.top(), ticker, p.area.width, .{ .foreground = tui.palette.violet.c300 }, p.area);
        }
    }.draw);

    // Animated modal popup reveal
    if (state.modal_transition.isVisible()) {
        const pop = tui.Popup{
            .title = "Animated Modal Transition",
            .footer_hint = "Press p or Esc to close",
            .width_percent = 54,
            .height_percent = 45,
            .dim_backdrop = false,
        };
        const full_box = pop.computeRect(ui.area);
        const anim_box = state.modal_transition.animatedRect(full_box, .center);
        tui.fx.dimBackdrop(ui.buffer, ui.area, state.modal_transition.eased() * 0.8);
        if (!anim_box.isEmpty()) {
            const anim_pop = tui.Popup{
                .title = "Animated Modal Transition",
                .footer_hint = "Esc / p to close",
                .width = anim_box.width,
                .height = anim_box.height,
                .dim_backdrop = false,
                .shadow = true,
            };
            try anim_pop.renderWith(ui, ui.area, state.modal_transition.eased(), struct {
                fn drawModal(eased: f64, modal: *tui.Ui) !void {
                    try modal.paragraph(.{
                        .raw = "Popup size scales smoothly via `Transition.animatedRect` while `dimBackdrop` fades background contrast.",
                        .wrap = .word,
                    }, null);
                    tui.fx.dissolve(modal.buffer, modal.area, eased, 42);
                }
            }.drawModal);
        }
    }

    try state.toast.render(ui, ui.area);

    var ft = rows[3];
    ft.statusBar(.{
        .left = &.{ .{ .text = "FX", .badge = true }, .{ .text = if (state.loading) "Loading..." else "Loaded" } },
        .right = &.{.{ .text = "Space Spring  l Load  p Modal  t Toast  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 96, .height = 24 } } else .auto,
        .settings = .{ .fps = 30 },
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        state.toast.show("Ready", "Animated toast online", .info);
        for (0..8) |_| {
            _ = app.advanceTimer();
            _ = try onEvent(&state, .tick, &app);
        }
        try app.draw(&state, render);
        const snap1 = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap1, "Animations, Easing") != null);
        std.debug.assert(std.mem.indexOf(u8, snap1, "Animated toast online") != null);

        _ = try onEvent(&state, .{ .key = .{ .code = .{ .char = 'p' } } }, &app);
        _ = try onEvent(&state, .{ .key = .{ .code = .{ .char = 'l' } } }, &app);
        for (0..12) |_| {
            _ = app.advanceTimer();
            _ = try onEvent(&state, .tick, &app);
        }
        try app.draw(&state, render);
        const snap2 = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap2, "Animated Modal Transition") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
