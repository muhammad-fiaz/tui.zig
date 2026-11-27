const std = @import("std");
const tui = @import("tui");

/// Explicit client-side custom application loop (without calling `app.run()`),
/// demonstrating manual `enter()`, `beginFrame()`, `endFrame()`, `pollEvent()`,
/// `advanceTimer()`, staged loading pipeline state machine, custom logging, and animations.
const LoadStage = enum {
    connecting,
    fetching_manifest,
    compiling_modules,
    ready,

    pub fn label(self: LoadStage) []const u8 {
        return switch (self) {
            .connecting => "Connecting to registry...",
            .fetching_manifest => "Fetching dependency manifest...",
            .compiling_modules => "Building workspace targets...",
            .ready => "Workspace ready!",
        };
    }

    pub fn targetProgress(self: LoadStage) f64 {
        return switch (self) {
            .connecting => 0.18,
            .fetching_manifest => 0.48,
            .compiling_modules => 0.82,
            .ready => 1.0,
        };
    }
};

const ClientState = struct {
    stage: LoadStage = .connecting,
    stage_elapsed_ms: u64 = 0,
    shimmer_phase: f64 = 0.0,
    progress_spring: tui.Spring = .{ .value = 0.0, .target = 0.18, .stiffness = 120.0, .damping = 18.0 },
    toast: tui.ToastState = .{},
    logs: [6][64]u8 = undefined,
    log_lens: [6]usize = @splat(0),
    log_count: usize = 0,
    reload_rect: tui.Rect = tui.Rect.zero,

    fn pushLog(self: *ClientState, msg: []const u8) void {
        const slot = self.log_count % self.logs.len;
        const n = @min(msg.len, self.logs[slot].len);
        @memcpy(self.logs[slot][0..n], msg[0..n]);
        self.log_lens[slot] = n;
        self.log_count += 1;
    }

    fn restartPipeline(self: *ClientState) void {
        self.stage = .connecting;
        self.stage_elapsed_ms = 0;
        self.progress_spring.snap(0.0);
        self.progress_spring.setTarget(LoadStage.connecting.targetProgress());
        self.pushLog("Restarted async job pipeline");
        self.toast.show("Pipeline", "Started staged loader", .info);
    }

    fn stepTimers(self: *ClientState, dt_ms: u64) void {
        self.stage_elapsed_ms +|= dt_ms;
        self.shimmer_phase = @mod(self.shimmer_phase + (@as(f64, @floatFromInt(dt_ms)) / 1000.0) * 0.9, 1.0);
        _ = self.progress_spring.step(dt_ms);
        _ = self.toast.update(dt_ms);

        // Advance loader pipeline stages on realistic millisecond budgets.
        if (self.stage != .ready and self.stage_elapsed_ms >= 900) {
            self.stage_elapsed_ms = 0;
            self.stage = switch (self.stage) {
                .connecting => .fetching_manifest,
                .fetching_manifest => .compiling_modules,
                .compiling_modules => blk: {
                    self.toast.show("Complete", "All targets compiled cleanly", .success);
                    break :blk .ready;
                },
                .ready => .ready,
            };
            self.progress_spring.setTarget(self.stage.targetProgress());
            self.pushLog(self.stage.label());
        }
    }

    fn handleEvent(self: *ClientState, event: tui.Event, app: *tui.App) void {
        if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
            app.quit();
            return;
        }
        if (event.isChar('r') or (tui.Button{ .label = "Reload", .focused = true }).handleEvent(event, self.reload_rect)) {
            self.restartPipeline();
        }
    }
};

fn renderClientUi(state: *ClientState, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const shell = ui.rows(4, .{
        .{ .length = 1 },
        .{ .length = 5 },
        .{ .fill = 1 },
        .{ .length = 1 },
    }, .{});

    var hdr = shell[0];
    hdr.header(.{
        .title = "Custom Client Event Loop & Async Loader",
        .subtitle = state.stage.label(),
        .right = "r Reload  q Quit",
    }, hdr.area);

    // Top status & spring progress card
    var top_card = shell[1].margin(tui.Margin.symmetric(1, 0));
    try top_card.panel(.{ .title = "Staged Job Pipeline", .focused = true, .padding = tui.Padding.symmetric(1, 0) }, top_card.area, state, struct {
        fn draw(st: *ClientState, p: *tui.Ui) !void {
            const bar = p.cols(2, .{ .{ .fill = 1 }, .{ .length = 16 } }, .{ .spacing = .{ .space = 2 } });
            var left = bar[0];
            try left.progress(.{
                .label = st.stage.label(),
                .ratio = std.math.clamp(st.progress_spring.value, 0.0, 1.0),
            }, left.allocateRows(1));
            left.space(1);
            if (st.stage != .ready) {
                left.spinner(.{ .tick = @intFromFloat(st.shimmer_phase * 20.0), .label = "Background worker running..." }, left.allocateRows(1));
            } else {
                try left.text("All pipeline stages completed cleanly.", .{ .style = left.theme.success }, left.allocateRows(1));
            }

            var right = bar[1];
            const btn_r = right.allocateRows(3);
            st.reload_rect = btn_r;
            try right.button(.{ .label = "Reload", .variant = .primary, .focused = true }, btn_r);
        }
    }.draw);

    // Mid pane: Loading shimmer skeleton while busy, or log history once ready
    const mid = shell[2].cols(2, .{ .{ .percentage = 50 }, .{ .fill = 1 } }, .{ .margin = tui.Margin.uniform(1), .spacing = .{ .space = 1 } });
    var pane_a = mid[0];
    try pane_a.panel(.{ .title = if (state.stage == .ready) "Loaded Data Preview" else "Loading Shimmer...", .padding = tui.Padding.uniform(1) }, pane_a.area, state, struct {
        fn draw(st: *ClientState, p: *tui.Ui) !void {
            if (st.stage != .ready) {
                try p.skeleton(.{ .rows = 4, .phase = st.shimmer_phase }, null);
            } else {
                try p.paragraph(.{
                    .raw = "Build manifest resolved (0 warnings)\n42 native modules linked\nReady for interactive queries.",
                    .wrap = .word,
                    .style = p.theme.success,
                }, null);
            }
        }
    }.draw);

    var pane_b = mid[1];
    try pane_b.panel(.{ .title = "Custom Loop Event Log", .padding = tui.Padding.uniform(1) }, pane_b.area, state, struct {
        fn draw(st: *ClientState, p: *tui.Ui) !void {
            const shown = @min(st.log_count, st.logs.len);
            for (0..shown) |i| {
                const idx = (st.log_count - 1 - i) % st.logs.len;
                const row = p.allocateRows(1);
                if (row.isEmpty()) break;
                try p.text(st.logs[idx][0..st.log_lens[idx]], .{ .style = p.theme.text }, row);
            }
        }
    }.draw);

    try state.toast.render(ui, ui.area);

    var ft = shell[3];
    ft.statusBar(.{
        .left = &.{ .{ .text = @tagName(state.stage), .badge = true }, .{ .text = "Custom loop" } },
        .right = &.{.{ .text = "r / Click Reload  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 92, .height = 22 } } else .auto,
        .settings = .{ .mouse = true, .fps = 30 },
    });
    defer app.deinit();

    var state = ClientState{};
    state.pushLog("Initialized custom client loop");
    state.toast.show("Startup", "Running manual loop", .info);

    if (headless) {
        // Simulate several manual frames stepping explicit loop timers until `.ready`.
        var step: usize = 0;
        while (step < 120) : (step += 1) {
            const dt = app.advanceTimer();
            state.stepTimers(dt);
            var ui = try app.beginFrame();
            try renderClientUi(&state, &ui);
            try app.endFrame(&ui);
        }
        const snap = try app.snapshot();
        std.debug.assert(state.stage == .ready);
        std.debug.assert(std.mem.indexOf(u8, snap, "Build manifest resolved") != null);
        return;
    }

    // Explicit interactive client-owned loop (`enter` + `beginFrame`/`endFrame`/`pollEvent`).
    try app.enter();
    defer app.restore();

    const frame_ms: i32 = @intCast(app.targetFrameMs());
    while (app.isRunning()) {
        const dt = app.advanceTimer();
        state.stepTimers(dt);

        var ui = try app.beginFrame();
        try renderClientUi(&state, &ui);
        try app.endFrame(&ui);

        const ev = try app.pollEvent(frame_ms);
        if (ev != .none) {
            state.handleEvent(ev, &app);
        }
    }
}
