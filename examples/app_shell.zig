const std = @import("std");
const tui = @import("tui");

const log_data = [_]tui.LogEntry{
    .{ .timestamp = "05:30:01", .level = .info, .source = "http", .message = "Listening on 0.0.0.0:8080 (TLS 1.3)" },
    .{ .timestamp = "05:30:04", .level = .debug, .source = "pool", .message = "Warmed 16 database connections" },
    .{ .timestamp = "05:30:07", .level = .warn, .source = "auth", .message = "Token clock skew +410ms from client" },
    .{ .timestamp = "05:30:11", .level = .err, .source = "worker", .message = "Retry #2 timed out connecting to redis-02" },
    .{ .timestamp = "05:30:14", .level = .info, .source = "worker", .message = "Recovered failover stream on redis-01" },
    .{ .timestamp = "05:30:18", .level = .trace, .source = "cache", .message = "Evicted 42 stale session keys (LRU)" },
    .{ .timestamp = "05:30:22", .level = .info, .source = "http", .message = "GET /api/v1/health 200 OK (1.4ms)" },
    .{ .timestamp = "05:30:25", .level = .debug, .source = "auth", .message = "Rotated JWKS signing key kid=2026-11" },
    .{ .timestamp = "05:30:29", .level = .warn, .source = "pool", .message = "Connection wait queue peaked at 11" },
    .{ .timestamp = "05:30:33", .level = .info, .source = "cache", .message = "Snapshot persisted to disk (18.4 MB)" },
    .{ .timestamp = "05:30:37", .level = .err, .source = "http", .message = "Upstream 502 on POST /webhooks/billing" },
    .{ .timestamp = "05:30:41", .level = .info, .source = "worker", .message = "Scheduled retry #1 succeeded in 94ms" },
};

const diff_data = [_]tui.DiffLine{
    .{ .kind = .hunk, .text = "@@ -10,8 +10,10 @@ fn renderShell(ui: *Ui) !void" },
    .{ .kind = .context, .old_line = 10, .new_line = 10, .text = "const info = ui.app;" },
    .{ .kind = .context, .old_line = 11, .new_line = 11, .text = "const sb = state.resolvedSidebar();" },
    .{ .kind = .removed, .old_line = 12, .text = "var panel = try tui.TreeState.init(alloc);" },
    .{ .kind = .added, .new_line = 12, .text = "var panel = app.treeState();" },
    .{ .kind = .added, .new_line = 13, .text = "defer panel.deinit();" },
    .{ .kind = .context, .old_line = 13, .new_line = 14, .text = "const split = sb.splitLayout(area);" },
    .{ .kind = .hunk, .text = "@@ -28,4 +30,5 @@ fn syncWindowTitle(app: *App) !void" },
    .{ .kind = .removed, .old_line = 28, .text = "try app.setTitle(info.name);" },
    .{ .kind = .added, .new_line = 30, .text = "const snap = try app.snapshot();" },
    .{ .kind = .added, .new_line = 31, .text = "try app.setTitle(info.effectiveTitle());" },
    .{ .kind = .context, .old_line = 29, .new_line = 32, .text = "}" },
};

const nav_items_en = [_][]const u8{ "Overview", "Logs & Diff", "Controls" };
const nav_items_ar = [_][]const u8{ "نظرة عامة", "السجلات", "التحكم" };

const envs = [_][]const u8{ "development", "staging", "production" };
const mode_choices = [_][]const u8{ "Automatic", "Canary", "Locked" };

const State = struct {
    route: usize = 0, // 0=Overview, 1=Logs/Diff, 2=Controls
    direction: tui.TextDirection = .ltr,
    sidebar_side: tui.SidebarSide = .auto, // .auto mirrors cleanly on .rtl, or explicitly .left / .right
    sidebar_collapsed: bool = false,
    focus_sidebar: bool = true,
    route1_focus: u8 = 0, // 0=Logs, 1=Diff, 2=Pagination
    logs: tui.LogViewerState = .{ .min_level = .trace, .follow_tail = true },
    diff: tui.DiffViewerState = .{},
    page: usize = 2,
    env_sel: tui.DropdownState = .{ .selected = 1 },
    note_input: tui.TextInputState,
    auto_deploy: bool = true,
    replicas: tui.SliderState = .{ .value = 4, .min = 1, .max = 16, .step = 1 },
    rollout_mode: tui.RadioState = .{ .selected = 0 },
    cal: tui.CalendarState = .{ .cursor = tui.Date.init(2026, 11, 27), .today = tui.Date.init(2026, 11, 27) },
    toasts: tui.ToastManager(3) = .{ .anchor = .top_right },

    // Exact rendered hitboxes for responsive mouse/scroll routing
    log_rect: tui.Rect = tui.Rect.zero,
    diff_rect: tui.Rect = tui.Rect.zero,
    pg_rect: tui.Rect = tui.Rect.zero,
    drop_rect: tui.Rect = tui.Rect.zero,
    slider_rect: tui.Rect = tui.Rect.zero,
    radio_rect: tui.Rect = tui.Rect.zero,

    fn deinit(self: *State) void {
        self.note_input.deinit();
    }

    fn resolvedSidebar(self: *const State) tui.Sidebar {
        return .{
            .title = if (self.direction == .rtl) "القائمة" else "Navigation",
            .items = if (self.direction == .rtl) &.{
                .{ .label = "نظرة عامة", .icon = "◈", .badge = "3" },
                .{ .label = "السجلات", .icon = "≡", .badge = "12" },
                .{ .label = "التحكم", .icon = "⚙" },
            } else &.{
                .{ .label = "Overview", .icon = "◈", .badge = "3" },
                .{ .label = "Logs & Diff", .icon = "≡", .badge = "12" },
                .{ .label = "Controls", .icon = "⚙" },
            },
            .selected = self.route,
            .side = self.sidebar_side,
            .direction = self.direction,
            .collapsed = self.sidebar_collapsed,
            .width = if (self.direction == .rtl) 18 else 22,
            .focused = self.focus_sidebar,
            .footer = if (self.direction == .rtl) "s جانب  d اتجاه" else "s Side  d RTL/LTR",
        };
    }

    fn logViewerWidget(self: *const State) tui.LogViewer {
        return .{
            .entries = &log_data,
            .block = .{ .title = "Structured Logs", .focused = !self.focus_sidebar and self.route1_focus == 0 },
            .show_line_numbers = true,
            .focused = !self.focus_sidebar and self.route1_focus == 0,
        };
    }

    fn diffViewerWidget(self: *const State) tui.DiffViewer {
        return .{
            .lines = &diff_data,
            .block = .{ .title = "Unified Diff", .focused = !self.focus_sidebar and self.route1_focus == 1 },
            .show_line_numbers = true,
            .focused = !self.focus_sidebar and self.route1_focus == 1,
        };
    }
};

fn syncWindowTitle(state: *const State, app: *tui.App) !void {
    var title_buf: [128]u8 = undefined;
    const route_name = nav_items_en[@min(state.route, nav_items_en.len - 1)];
    const t = std.fmt.bufPrint(&title_buf, "{s} — {s} [{s}]", .{
        app.info().name,
        route_name,
        @tagName(state.direction),
    }) catch app.info().name;
    try app.setTitle(t);
}

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    if (event == .tick) {
        _ = state.toasts.update(app.deltaMs());
        return true;
    }

    const scr = app.area();
    const nav_rect = tui.Rect.init(scr.x, scr.y, scr.width, 1);
    const body_rect = tui.Rect.init(scr.x, scr.y + 1, scr.width, scr.height -| 2);

    const nav = tui.Navbar{
        .brand = app.info().name,
        .items = if (state.direction == .rtl) &nav_items_ar else &nav_items_en,
        .active = state.route,
        .direction = state.direction,
    };
    if (event == .mouse and nav.handleEvent(&state.route, event, nav_rect)) {
        try syncWindowTitle(state, app);
        return true;
    }

    const sb = state.resolvedSidebar();
    const split = sb.splitLayout(body_rect);
    if (event == .mouse and event.mouse.kind == .down and event.mouse.button == .left) {
        if (event.mouse.isInside(split.sidebar)) {
            state.focus_sidebar = true;
        } else if (event.mouse.isInside(split.content)) {
            state.focus_sidebar = false;
        }
    }
    if (sb.handleEvent(&state.route, event, split.sidebar, state.focus_sidebar)) {
        try syncWindowTitle(state, app);
        return true;
    }

    if (event == .key and event.key.kind != .release) {
        if (event.key.isChar('d')) {
            state.direction = if (state.direction == .ltr) .rtl else .ltr;
            state.sidebar_side = .auto;
            state.toasts.anchor = if (state.direction == .rtl) .top_left else .top_right;
            state.toasts.push("Direction", if (state.direction == .rtl) "Switched to RTL right sidebar" else "Switched to LTR left sidebar", .info);
            try syncWindowTitle(state, app);
            return true;
        }
        if (event.key.isChar('s')) {
            state.sidebar_side = switch (sb.resolvedSide()) {
                .left => .right,
                .right => .left,
            };
            state.toasts.push("Sidebar Dock", if (state.sidebar_side == .right) "Pinned to right edge" else "Pinned to left edge", .info);
            return true;
        }
        if (event.key.isChar('c')) {
            state.sidebar_collapsed = !state.sidebar_collapsed;
            return true;
        }
        if (event.key.code == .tab) {
            if (state.focus_sidebar) {
                state.focus_sidebar = false;
                state.route1_focus = 0;
            } else if (state.route == 1 and state.route1_focus < 2) {
                state.route1_focus += 1;
            } else {
                state.focus_sidebar = true;
                state.route1_focus = 0;
            }
            return true;
        }
    }

    // Route-specific controls using exact rendered bounds
    if (state.route == 1) {
        if (event == .mouse and event.mouse.kind == .down and event.mouse.button == .left) {
            if (event.mouse.isInside(state.log_rect)) state.route1_focus = 0 else if (event.mouse.isInside(state.diff_rect)) state.route1_focus = 1 else if (event.mouse.isInside(state.pg_rect)) state.route1_focus = 2;
        }
        const pager = tui.Pagination{ .total_pages = 8, .focused = !state.focus_sidebar and state.route1_focus == 2 };
        if (pager.handleEvent(&state.page, event, state.pg_rect)) {
            state.logs.follow_tail = false;
            state.logs.scroll_y = @min(log_data.len -| 1, (state.page - 1) * 2);
            return true;
        }
        if (state.logViewerWidget().handleEvent(&state.logs, event, state.log_rect)) return true;
        if (state.diffViewerWidget().handleEvent(&state.diff, event, state.diff_rect)) return true;
    } else if (state.route == 2) {
        if (!state.focus_sidebar) {
            if (event.isChar(' ')) {
                state.auto_deploy = !state.auto_deploy;
                return true;
            }
            _ = try state.note_input.handleEvent(event, true);
        }
        _ = (tui.Dropdown{ .items = &envs, .label = "Target" }).handleEvent(&state.env_sel, event, state.drop_rect, scr);
        _ = (tui.Slider{ .precision = 0, .unit = " pods" }).handleEvent(&state.replicas, event, state.slider_rect);
        _ = (tui.RadioGroup{
            .items = &mode_choices,
            .direction = .horizontal,
            .wrap = true,
            .focused = !state.focus_sidebar,
        }).handleEvent(&state.rollout_mode, event, state.radio_rect);
    }

    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const shell = ui.rows(3, .{
        .{ .length = 1 },
        .{ .fill = 1 },
        .{ .length = 1 },
    }, .{});

    var nav_ui = shell[0];
    nav_ui.navbar(.{
        .brand = ui.app.name,
        .items = if (state.direction == .rtl) &nav_items_ar else &nav_items_en,
        .active = state.route,
        .right_text = ui.app.version,
        .direction = state.direction,
    }, nav_ui.area);

    const sb = state.resolvedSidebar();
    const split = sb.splitLayout(shell[1].area);

    var sb_ui = shell[1].region(split.sidebar);
    try sb_ui.sidebar(sb, sb_ui.area);

    var main_ui = shell[1].region(split.content).margin(tui.Margin.symmetric(1, 0));
    switch (state.route) {
        0 => {
            const ov = main_ui.rows(3, .{
                .{ .length = 3 },
                .{ .length = 11 },
                .{ .fill = 1 },
            }, .{ .spacing = .{ .space = 0 } });

            var stp = ov[0];
            try stp.stepper(.{
                .steps = &.{
                    .{ .label = "Lint", .status = .completed },
                    .{ .label = "Build", .status = .completed },
                    .{ .label = "Deploy", .status = .active },
                    .{ .label = "Verify", .status = .pending },
                },
                .block = .{ .border_type = .plain },
            }, stp.area);

            const mid = if (ov[1].isCompact(60))
                ov[1].rows(2, .{ .{ .percentage = 50 }, .{ .fill = 1 } }, .{})
            else
                ov[1].cols(2, .{ .{ .percentage = 50 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 1 } });

            var pie_ui = mid[0];
            try pie_ui.pieChart(.{
                .slices = &.{
                    .{ .label = "Compute", .value = 54, .color = tui.palette.sky.c400 },
                    .{ .label = "Storage", .value = 28, .color = tui.palette.emerald.c400 },
                    .{ .label = "Network", .value = 18, .color = tui.palette.amber.c400 },
                },
                .donut_ratio = 0.5,
                .center_label = "100%",
                .block = .{ .title = "Cost Breakdown" },
            }, pie_ui.area);

            var chart_ui = mid[1];
            try chart_ui.chart(.{
                .datasets = &.{
                    .{
                        .name = "Area",
                        .data = &.{ .{ .x = 0, .y = 20 }, .{ .x = 30, .y = 65 }, .{ .x = 65, .y = 48 }, .{ .x = 100, .y = 85 } },
                        .graph_type = .area,
                        .style = .{ .foreground = tui.palette.sky.c400 },
                    },
                    .{
                        .name = "Limit",
                        .data = &.{ .{ .x = 0, .y = 50 }, .{ .x = 50, .y = 75 }, .{ .x = 100, .y = 75 } },
                        .graph_type = .step,
                        .style = .{ .foreground = tui.palette.amber.c400 },
                    },
                },
                .x_axis = .{ .labels = &.{ "0s", "50s", "100s" } },
                .y_axis = .{ .labels = &.{ "0", "50", "100" } },
                .block = .{ .title = "Area & Step Chart" },
            }, chart_ui.area);

            const bot = if (ov[2].isCompact(60))
                ov[2].rows(2, .{ .{ .percentage = 50 }, .{ .fill = 1 } }, .{})
            else
                ov[2].cols(2, .{ .{ .percentage = 55 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 1 } });

            var hm_ui = bot[0];
            try hm_ui.heatmap(.{
                .rows = 3,
                .cols = 4,
                .values = &.{ 12, 34, 58, 82, 20, 44, 91, 63, 8, 22, 41, 70 },
                .row_labels = &.{ "us-1", "eu-1", "ap-1" },
                .col_labels = &.{ "00", "06", "12", "18" },
                .show_values = true,
                .block = .{ .title = "Latency Heatmap (ms)" },
            }, hm_ui.area);

            var kv_ui = bot[1];
            try kv_ui.keyValueList(.{
                .entries = &.{
                    .{ .key = "App", .value = ui.app.name, .value_style = ui.theme.accent },
                    .{ .key = "Version", .value = ui.app.version },
                    .{ .key = "Dock", .value = @tagName(sb.resolvedSide()) },
                    .{ .key = "Direction", .value = @tagName(state.direction) },
                },
                .block = .{ .title = "Instance Info" },
            }, kv_ui.area);
        },
        1 => {
            const panes = main_ui.rows(2, .{ .{ .fill = 1 }, .{ .length = 1 } }, .{});
            const split_ld = if (panes[0].isCompact(72))
                panes[0].rows(2, .{ .{ .percentage = 50 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 1 } })
            else
                panes[0].cols(2, .{ .{ .percentage = 50 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 1 } });

            var lv_ui = split_ld[0];
            state.log_rect = lv_ui.area;
            try lv_ui.logViewer(state.logViewerWidget(), &state.logs, lv_ui.area);

            var dv_ui = split_ld[1];
            state.diff_rect = dv_ui.area;
            try dv_ui.diffViewer(state.diffViewerWidget(), &state.diff, dv_ui.area);

            var pg_ui = panes[1];
            state.pg_rect = pg_ui.area;
            try pg_ui.pagination(.{
                .total_pages = 8,
                .focused = !state.focus_sidebar and state.route1_focus == 2,
            }, &state.page, pg_ui.area);
        },
        else => {
            const form_cols = if (main_ui.isCompact(64))
                main_ui.rows(2, .{ .{ .percentage = 52 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 1 } })
            else
                main_ui.cols(2, .{ .{ .percentage = 55 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 1 } });

            var left_p = form_cols[0];
            try left_p.panel(.{ .title = "Deployment Controls", .padding = tui.Padding.uniform(1) }, left_p.area, state, struct {
                fn draw(st: *State, p: *tui.Ui) !void {
                    try p.textInput(.{
                        .label = "Release Note",
                        .focused = !st.focus_sidebar,
                    }, &st.note_input, null);
                    p.space(1);
                    p.switchToggle(.{ .label = "Auto Canary Promotion", .on = st.auto_deploy }, null);
                    p.space(1);
                    st.slider_rect = p.allocateRows(1);
                    try p.slider(.{ .label = "Replicas", .precision = 0, .unit = " pods" }, &st.replicas, st.slider_rect);
                    p.space(1);
                    st.radio_rect = p.available();
                    try p.radio(.{ .items = &mode_choices, .direction = .horizontal, .wrap = true }, &st.rollout_mode, st.radio_rect);
                }
            }.draw);

            var right_p = form_cols[1];
            const rc = right_p.rows(2, .{ .{ .length = 3 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 1 } });
            var cal_ui = rc[1];
            try cal_ui.calendar(.{
                .block = .{ .title = "Release Schedule" },
            }, &state.cal, cal_ui.area);

            var dd_ui = rc[0];
            state.drop_rect = dd_ui.area;
            try dd_ui.select(.{ .items = &envs, .label = "Target" }, &state.env_sel, dd_ui.area);
        },
    }

    try state.toasts.render(ui, ui.area);

    var ft = shell[2];
    const side_lbl = if (sb.resolvedSide() == .right) "RIGHT" else "LEFT";
    const dir_lbl = if (state.direction == .rtl) "RTL" else "LTR";
    ft.statusBar(.{
        .left = &.{
            .{ .text = ui.app.name, .badge = true },
            .{ .text = side_lbl },
            .{ .text = dir_lbl },
        },
        .right = &.{
            .{ .text = ui.app.effectiveTitle() },
            .{ .text = "Tab Focus  d RTL/LTR  s Side  c Collapse  q Quit" },
        },
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .app = .{
            .name = "Workspace",
            .version = tui.version,
            .description = "Multi-Pane Client Shell",
            .title = "Workspace — Overview",
        },
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 108, .height = 28 } } else .auto,
        .settings = .{ .mouse = true, .fps = 24 },
    });
    defer app.deinit();

    var state = State{
        .note_input = try app.textInputWith("Rollout v" ++ tui.version),
    };
    defer state.deinit();
    state.toasts.push("Deployment", "Wrapped cleanly without horizontal or vertical overflow.", .info);

    if (headless) {
        // 1. Default LTR Left Sidebar Overview
        try app.draw(&state, render);
        const snap_ltr = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap_ltr, "Cost Breakdown") != null);
        std.debug.assert(std.mem.indexOf(u8, snap_ltr, "Compute 54%") != null);
        std.debug.assert(std.mem.indexOf(u8, snap_ltr, "LEFT") != null);

        // 2. Toggle RTL Right Sidebar + inspect Logs/Diff, line numbers, target filter, and Pagination
        _ = try onEvent(&state, .{ .key = .{ .code = .{ .char = 'd' } } }, &app);
        std.debug.assert(state.direction == .rtl);
        std.debug.assert(state.resolvedSidebar().resolvedSide() == .right);
        state.toasts.clear(); // clear transient toast before inspecting Route 1 widgets
        state.route = 1;
        state.focus_sidebar = false;
        state.route1_focus = 0;
        try syncWindowTitle(&state, &app);
        try app.draw(&state, render);
        const snap_rtl = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap_rtl, "Structured Logs") != null);
        std.debug.assert(std.mem.indexOf(u8, snap_rtl, "Unified Diff") != null);
        std.debug.assert(std.mem.indexOf(u8, snap_rtl, "RIGHT") != null);
        std.debug.assert(std.mem.indexOf(u8, snap_rtl, "RTL") != null);
        std.debug.assert(std.mem.indexOf(u8, snap_rtl, "Prev") != null);

        // Toggle LogViewer EWIDT target matrix ('h') and navigate Pagination ('Tab' x2 -> Right)
        _ = try onEvent(&state, .{ .key = .{ .code = .{ .char = 'h' } } }, &app);
        std.debug.assert(state.logs.show_targets);
        state.route1_focus = 2;
        _ = try onEvent(&state, .{ .key = .{ .code = .right } }, &app);
        std.debug.assert(state.page == 3);
        try app.draw(&state, render);
        const snap_targets = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap_targets, "EWIDT") != null);

        // 3. Controls route + compact resize responsiveness check
        state.route = 2;
        try app.resizeTest(.{ .width = 58, .height = 24 });
        try app.draw(&state, render);
        const snap_ctrl = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap_ctrl, "Rollout") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
