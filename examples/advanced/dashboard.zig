const std = @import("std");
const tui = @import("tui");

const themes = [_]tui.Theme{
    tui.Theme.dark,
    tui.Theme.catppuccin,
    tui.Theme.tokyo_night,
    tui.Theme.nord,
};

const State = struct {
    tab: usize = 0,
    theme_idx: usize = 0,
    table: tui.TableState = .{ .selected = 0 },
    ticks: u64 = 0,
    shimmer_phase: f64 = 0.0,
    cap_spring: tui.Spring = .{ .value = 0.42, .target = 0.68, .stiffness = 120.0, .damping = 15.0 },
    toast: tui.ToastState = blk: {
        var t = tui.ToastState{ .duration_ms = 2400 };
        t.show("Dashboard", "Connected to telemetry stream", .success);
        break :blk t;
    },
    tabs_rect: tui.Rect = tui.Rect.zero,
    table_rect: tui.Rect = tui.Rect.zero,
    table_visible: u16 = 8,
};

const jobs = [_]tui.TableRow{
    tui.TableRow.fromStrings(&.{ "ingest-eu-01", "Healthy", "24%", "1.4 ms" }),
    tui.TableRow.fromStrings(&.{ "ingest-us-02", "Healthy", "41%", "2.1 ms" }),
    tui.TableRow.fromStrings(&.{ "worker-ml-01", "Busy", "89%", "14.8 ms" }),
    tui.TableRow.fromStrings(&.{ "billing-cron", "Idle", "3%", "0.6 ms" }),
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    const bar = tui.Tabs{ .titles = &.{ "Overview", "Workloads", "Telemetry" }, .selected = state.tab };
    if (bar.handleEvent(&state.tab, event, state.tabs_rect, true)) return true;
    _ = state.table.handleEvent(event, jobs.len, 4, @max(@as(u16, 1), state.table_visible), state.table_rect, state.tab == 0 or state.tab == 1);

    switch (event) {
        .tick => {
            const dt = app.deltaMs();
            state.ticks +%= 1;
            state.shimmer_phase = @mod(state.shimmer_phase + app.deltaSeconds() * 0.7, 1.0);
            state.cap_spring.setTarget(0.62 + 0.16 * @sin(@as(f64, @floatFromInt(state.ticks)) * 0.12));
            _ = state.cap_spring.step(dt);
            _ = state.toast.update(dt);
        },
        .key => |k| {
            if (k.kind == .release) return true;
            if (k.isChar('t')) {
                state.theme_idx = (state.theme_idx + 1) % themes.len;
                app.setTheme(themes[state.theme_idx]);
                state.toast.show("Theme", "Switched color theme", .info);
            } else if (k.code == .tab) {
                state.tab = (state.tab + 1) % 3;
            } else if (k.code == .back_tab) {
                state.tab = if (state.tab == 0) 2 else state.tab - 1;
            }
        },
        else => {},
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const shell = ui.rows(4, .{
        .{ .length = 1 },
        .{ .length = 1 },
        .{ .fill = 1 },
        .{ .length = 1 },
    }, .{});

    var hdr = shell[0];
    hdr.header(.{ .title = "tui.zig Operations Dashboard", .subtitle = "Cluster us-east", .right = "t Theme  q Quit" }, hdr.area);

    var tab_ui = shell[1];
    state.tabs_rect = tab_ui.area;
    try tab_ui.tabs(.{ .titles = &.{ "Overview", "Workloads", "Telemetry" }, .selected = state.tab }, tab_ui.area);

    const workspace = shell[2];
    const pts = [_]tui.Point{ .{ .x = 0, .y = 28 }, .{ .x = 25, .y = 54 }, .{ .x = 50, .y = 49 }, .{ .x = 75, .y = 81 }, .{ .x = 100, .y = 69 } };

    switch (state.tab) {
        0 => {
            // Overview split layout (stacks automatically on narrow terminals)
            if (workspace.isCompact(72)) {
                const stacked = workspace.rows(2, .{ .{ .percentage = 50 }, .{ .fill = 1 } }, .{ .margin = tui.Margin.uniform(1), .spacing = .{ .space = 1 } });
                var top_c = stacked[0];
                try top_c.chart(.{
                    .datasets = &.{.{ .name = "RPS (k)", .data = &pts, .style = .{ .foreground = .cyan } }},
                    .x_axis = .{ .labels = &.{ "-60s", "-30s", "now" } },
                    .y_axis = .{ .labels = &.{ "0", "50", "100" } },
                    .block = .{ .title = "Cluster Load", .focused = true },
                }, top_c.area);

                var bot_t = stacked[1];
                const tbl_blk = tui.Block{ .title = "Active Workers" };
                state.table_rect = tbl_blk.inner(bot_t.area);
                state.table_visible = state.table_rect.height -| 2;
                try bot_t.table(.{
                    .header = tui.TableRow.fromStrings(&.{ "Node", "State", "CPU", "P99" }),
                    .rows = &jobs,
                    .widths = &.{ .{ .length = 14 }, .{ .length = 9 }, .{ .length = 6 }, .{ .fill = 1 } },
                    .block = tbl_blk,
                    .show_header_separator = true,
                }, &state.table, bot_t.area);
            } else {
                const main_cols = workspace.cols(2, .{ .{ .percentage = 55 }, .{ .fill = 1 } }, .{ .margin = tui.Margin.uniform(1), .spacing = .{ .space = 1 } });
                const left_rows = main_cols[0].rows(2, .{ .{ .percentage = 55 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 1 } });
                var chart_ui = left_rows[0];
                try chart_ui.chart(.{
                    .datasets = &.{.{ .name = "RPS (k)", .data = &pts, .style = .{ .foreground = .cyan } }},
                    .x_axis = .{ .labels = &.{ "-60s", "-30s", "now" } },
                    .y_axis = .{ .labels = &.{ "0", "50", "100" } },
                    .block = .{ .title = "Cluster Load", .focused = true },
                }, chart_ui.area);

                var sp_ui = left_rows[1];
                try sp_ui.sparkline(.{
                    .raw_data = &.{ 12, 16, 14, 22, 34, 28, 39, 44, 41, 48, 52, 49, 55, 62 },
                    .block = .{ .title = "Frame Time (µs)" },
                    .style = sp_ui.theme.success,
                }, sp_ui.area);

                const right_rows = main_cols[1].rows(2, .{ .{ .fill = 1 }, .{ .length = 6 } }, .{ .spacing = .{ .space = 1 } });
                var tbl_ui = right_rows[0];
                const tbl_blk = tui.Block{ .title = "Active Workers" };
                state.table_rect = tbl_blk.inner(tbl_ui.area);
                state.table_visible = state.table_rect.height -| 2;
                try tbl_ui.table(.{
                    .header = tui.TableRow.fromStrings(&.{ "Node", "State", "CPU", "P99" }),
                    .rows = &jobs,
                    .widths = &.{ .{ .length = 14 }, .{ .length = 9 }, .{ .length = 6 }, .{ .fill = 1 } },
                    .block = tbl_blk,
                    .show_header_separator = true,
                }, &state.table, tbl_ui.area);

                var health_ui = right_rows[1];
                try health_ui.panel(.{ .title = "Capacity", .padding = tui.Padding.symmetric(1, 0) }, health_ui.area, state, struct {
                    fn draw(st: *State, p: *tui.Ui) !void {
                        const g_r = p.allocateRows(1);
                        try p.gauge(.{ .ratio = std.math.clamp(st.cap_spring.value, 0.0, 1.0), .label = "Memory Capacity" }, g_r);
                        tui.fx.shimmer(p.buffer, g_r, st.shimmer_phase, .white, 5.0);
                        p.space(1);
                        p.spinner(.{ .tick = st.ticks, .label = "Stream connected" }, null);
                    }
                }.draw);
            }
        },
        1 => {
            // Workloads tab: full-width table + per-cluster bars
            const panes = workspace.rows(2, .{ .{ .fill = 1 }, .{ .length = 8 } }, .{ .margin = tui.Margin.uniform(1), .spacing = .{ .space = 1 } });
            var tbl_ui = panes[0];
            const tbl_blk = tui.Block{ .title = "Cluster Workloads (Full View)", .focused = true };
            state.table_rect = tbl_blk.inner(tbl_ui.area);
            state.table_visible = state.table_rect.height -| 2;
            try tbl_ui.table(.{
                .header = tui.TableRow.fromStrings(&.{ "Node", "State", "CPU", "P99" }),
                .rows = &jobs,
                .widths = &.{ .{ .length = 20 }, .{ .length = 14 }, .{ .length = 10 }, .{ .fill = 1 } },
                .block = tbl_blk,
                .show_header_separator = true,
            }, &state.table, tbl_ui.area);

            var bar_ui = panes[1];
            try bar_ui.barChart(.{
                .bars = &.{
                    tui.Bar.init("ingest-eu", 24),
                    tui.Bar.init("ingest-us", 41),
                    tui.Bar.init("worker-ml", 89),
                    tui.Bar.init("billing", 3),
                },
                .direction = .horizontal,
                .block = .{ .title = "Node Utilization" },
            }, bar_ui.area);
        },
        else => {
            // Telemetry tab: zoomed XY chart + sparkline
            const panes = workspace.rows(2, .{ .{ .fill = 1 }, .{ .length = 7 } }, .{ .margin = tui.Margin.uniform(1), .spacing = .{ .space = 1 } });
            var c_ui = panes[0];
            try c_ui.chart(.{
                .datasets = &.{.{ .name = "Throughput (k RPS)", .data = &pts, .style = .{ .foreground = tui.palette.sky.c400 } }},
                .x_axis = .{ .title = "Window", .labels = &.{ "-60s", "-30s", "now" } },
                .y_axis = .{ .title = "Load", .labels = &.{ "0", "50", "100" } },
                .show_grid_lines = true,
                .block = .{ .title = "Live Telemetry Stream", .focused = true },
            }, c_ui.area);

            var s_ui = panes[1];
            try s_ui.sparkline(.{
                .raw_data = &.{ 12, 16, 14, 22, 34, 28, 39, 44, 41, 48, 52, 49, 55, 62, 58, 70 },
                .block = .{ .title = "Latency Sparkline (µs)" },
                .style = .{ .foreground = tui.palette.emerald.c400 },
            }, s_ui.area);
        },
    }

    try state.toast.render(ui, ui.area);

    var ft = shell[3];
    ft.statusBar(.{
        .left = &.{ .{ .text = "LIVE", .badge = true }, .{ .text = "60 FPS" } },
        .right = &.{.{ .text = "t Theme  Tab Section  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 100, .height = 28 } } else .auto,
        .settings = .{ .mouse = true },
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        try app.draw(&state, render);
        const snap1 = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap1, "Operations Dashboard") != null);
        std.debug.assert(std.mem.indexOf(u8, snap1, "worker-ml-01") != null);

        // Verify Tab switches to Workloads view cleanly.
        _ = try onEvent(&state, .{ .key = .{ .code = .tab } }, &app);
        try app.draw(&state, render);
        const snap2 = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap2, "Cluster Workloads") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
