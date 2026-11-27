const std = @import("std");
const tui = @import("tui");

/// Client-side custom component showing how to build modular multi-section UIs
/// in Zig using `tui.Ui`, responsive breakpoints, OKLCH colors,
/// hardware cursor inputs, and layout-derived mouse hitboxes.
const ServiceStatus = struct {
    name: []const u8,
    region: []const u8,
    uptime: []const u8,
    latency_ms: u16,
    healthy: bool,
};

const services = [_]ServiceStatus{
    .{ .name = "api-gateway", .region = "us-east", .uptime = "99.99%", .latency_ms = 12, .healthy = true },
    .{ .name = "auth-worker", .region = "eu-west", .uptime = "99.95%", .latency_ms = 18, .healthy = true },
    .{ .name = "ingest-edge", .region = "ap-south", .uptime = "98.40%", .latency_ms = 84, .healthy = false },
    .{ .name = "billing-cron", .region = "us-west", .uptime = "100.0%", .latency_ms = 9, .healthy = true },
};

const FilterMode = enum(u8) {
    all,
    healthy,
    degraded,
};

/// Custom client UI header pill switcher implementing `pub fn renderStateful`.
const FilterPills = struct {
    pub const Hitboxes = [3]tui.Rect;

    pub fn renderStateful(self: FilterPills, ui: *tui.Ui, area: tui.Rect, active: *FilterMode) !void {
        _ = self;
        var x = area.left();
        const y = area.top();
        const labels = [_][]const u8{ " All ", " Healthy ", " Degraded " };
        const modes = [_]FilterMode{ .all, .healthy, .degraded };
        for (labels, modes) |lbl, mode| {
            if (x >= area.right()) break;
            const selected = active.* == mode;
            const st: tui.Style = if (selected)
                .{
                    .foreground = tui.palette.slate.c950,
                    .background = tui.palette.sky.c400,
                    .bold = true,
                }
            else
                ui.theme.button;
            x = ui.buffer.setStringClipped(x, y, lbl, area.right() - x, st, area).x;
            if (x < area.right()) {
                x = ui.buffer.setStringClipped(x, y, " ", 1, ui.theme.surface, area).x;
            }
        }
    }

    pub fn hitboxes(area: tui.Rect) Hitboxes {
        var rects: Hitboxes = @splat(tui.Rect.zero);
        var x = area.left();
        const widths = [_]u16{ 5, 9, 10 };
        for (widths, 0..) |w, i| {
            if (x >= area.right()) break;
            const clamped = @min(w, area.right() - x);
            rects[i] = tui.Rect.init(x, area.top(), clamped, 1);
            x +|= w + 1;
        }
        return rects;
    }
};

/// Client-side reusable card component rendering directly with `tui.Block` and `tui.Ui`.
const ServiceCard = struct {
    svc: ServiceStatus,
    focused: bool,

    pub fn render(self: ServiceCard, ui: *tui.Ui, area: tui.Rect) !void {
        const badge_col = if (self.svc.healthy) tui.palette.emerald.c400 else tui.palette.rose.c400;
        const blk = tui.Block{
            .title = self.svc.name,
            .border_type = .rounded,
            .focused = self.focused,
            .border_style = if (self.focused)
                .{ .foreground = tui.palette.sky.c400, .bold = true }
            else
                ui.theme.border,
            .padding = tui.Padding.symmetric(1, 0),
        };
        try blk.render(ui, area);
        const inner = blk.inner(area);
        if (inner.isEmpty()) return;

        var sub = ui.region(inner);
        sub.badge(.{
            .label = if (self.svc.healthy) "HEALTHY" else "DEGRADED",
            .variant = if (self.svc.healthy) .success else .danger,
        }, sub.allocateRows(1));

        var info_buf: [64]u8 = undefined;
        const details = std.fmt.bufPrint(&info_buf, "Region: {s} | Uptime: {s} | {d} ms", .{
            self.svc.region,
            self.svc.uptime,
            self.svc.latency_ms,
        }) catch "";
        if (!sub.available().isEmpty()) {
            try sub.text(details, .{ .style = .{ .foreground = badge_col } }, sub.allocateRows(1));
        }
    }
};

const State = struct {
    filter: FilterMode = .all,
    search: tui.TextInputState,
    selected_idx: usize = 0,
    focus: tui.FocusGroup = .{ .count = 2 }, // 0 = search input, 1 = cards list
    search_rect: tui.Rect = tui.Rect.zero,
    pills_rect: tui.Rect = tui.Rect.zero,
    card_rects: [services.len]tui.Rect = @splat(tui.Rect.zero),
    card_indices: [services.len]usize = .{ 0, 1, 2, 3 },
    visible_cards: usize = 0,

    fn deinit(self: *State) void {
        self.search.deinit();
    }
};

fn matchesFilter(svc: ServiceStatus, mode: FilterMode, query: []const u8) bool {
    const mode_ok = switch (mode) {
        .all => true,
        .healthy => svc.healthy,
        .degraded => !svc.healthy,
    };
    if (!mode_ok) return false;
    if (query.len == 0) return true;
    if (query.len > svc.name.len) return false;
    var i: usize = 0;
    while (i + query.len <= svc.name.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(svc.name[i .. i + query.len], query)) return true;
    }
    return false;
}

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC()) {
        app.quit();
        return false;
    }
    if (!state.focus.isFocused(0) and event.isChar('q')) {
        app.quit();
        return false;
    }
    if (state.focus.handleEvent(event)) return true;

    if (event == .mouse and event.mouse.kind == .down and event.mouse.button == .left) {
        const m = event.mouse;
        if (m.isInside(state.search_rect)) {
            state.focus.active = 0;
            return true;
        }
        const pill_rects = FilterPills.hitboxes(state.pills_rect);
        const modes = [_]FilterMode{ .all, .healthy, .degraded };
        for (pill_rects, modes) |r, mode| {
            if (m.isInside(r)) {
                state.filter = mode;
                state.selected_idx = 0;
                return true;
            }
        }
        for (state.card_rects[0..state.visible_cards], 0..) |r, idx| {
            if (m.isInside(r)) {
                state.focus.active = 1;
                state.selected_idx = idx;
                return true;
            }
        }
        return true;
    }

    if (state.focus.isFocused(0)) {
        if (try state.search.handleEvent(event, true) == .changed) {
            state.selected_idx = 0;
        }
    } else if (event == .key and event.key.kind != .release) {
        switch (event.key.code) {
            .down => if (state.visible_cards > 0) {
                state.selected_idx = (state.selected_idx + 1) % state.visible_cards;
            },
            .up => if (state.visible_cards > 0) {
                state.selected_idx = if (state.selected_idx == 0) state.visible_cards - 1 else state.selected_idx - 1;
            },
            .char => |cp| switch (cp) {
                '1' => state.filter = .all,
                '2' => state.filter = .healthy,
                '3' => state.filter = .degraded,
                'j' => if (state.visible_cards > 0) {
                    state.selected_idx = (state.selected_idx + 1) % state.visible_cards;
                },
                'k' => if (state.visible_cards > 0) {
                    state.selected_idx = if (state.selected_idx == 0) state.visible_cards - 1 else state.selected_idx - 1;
                },
                else => {},
            },
            else => {},
        }
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const shell = ui.rows(4, .{
        .{ .length = 1 },
        .{ .length = 3 },
        .{ .fill = 1 },
        .{ .length = 1 },
    }, .{});

    var hdr = shell[0];
    hdr.header(.{ .title = "Client Custom UI Blueprint", .right = "Tab Search/Cards  1-3 Filter" }, hdr.area);

    // Responsive top bar: full row when narrow, search + pills when wide.
    if (shell[1].isCompact(64)) {
        state.search_rect = shell[1].area;
        state.pills_rect = tui.Rect.zero;
        var s_ui = shell[1];
        try s_ui.textInput(.{
            .prefix = "🔍 ",
            .placeholder = "Filter services...",
            .focused = state.focus.isFocused(0),
        }, &state.search, s_ui.area);
    } else {
        const bar = shell[1].cols(2, .{ .{ .percentage = 55 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 2 } });
        state.search_rect = bar[0].area;
        var s_ui = bar[0];
        try s_ui.textInput(.{
            .prefix = "🔍 ",
            .placeholder = "Filter services...",
            .focused = state.focus.isFocused(0),
        }, &state.search, s_ui.area);

        var p_ui = bar[1].margin(tui.Margin.symmetric(0, 1));
        state.pills_rect = p_ui.area;
        try p_ui.renderStateful(FilterPills{}, &state.filter, p_ui.area);
    }

    // Populate filtered visible indices before layout.
    state.visible_cards = 0;
    const q = state.search.text();
    for (services, 0..) |svc, idx| {
        if (matchesFilter(svc, state.filter, q)) {
            state.card_indices[state.visible_cards] = idx;
            state.visible_cards += 1;
        }
    }
    if (state.visible_cards > 0 and state.selected_idx >= state.visible_cards) {
        state.selected_idx = state.visible_cards - 1;
    }

    // Responsive workspace: single column on narrow widths, master-detail split on wide terminals.
    const body = shell[2].margin(tui.Margin.uniform(1));
    if (body.isCompact(72)) {
        var list_ui = body;
        for (0..state.visible_cards) |i| {
            const rect = list_ui.allocateRows(4);
            state.card_rects[i] = rect;
            if (rect.isEmpty()) break;
            const svc = services[state.card_indices[i]];
            try list_ui.renderWidget(ServiceCard{ .svc = svc, .focused = state.focus.isFocused(1) and i == state.selected_idx }, rect);
        }
    } else {
        const panes = body.cols(2, .{ .{ .percentage = 60 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 2 } });
        var left = panes[0];
        for (0..state.visible_cards) |i| {
            const rect = left.allocateRows(4);
            state.card_rects[i] = rect;
            if (rect.isEmpty()) break;
            const svc = services[state.card_indices[i]];
            try left.renderWidget(ServiceCard{ .svc = svc, .focused = state.focus.isFocused(1) and i == state.selected_idx }, rect);
        }

        var right = panes[1];
        try right.panel(.{ .title = "Selected Service Inspector", .padding = tui.Padding.uniform(1) }, right.area, state, struct {
            fn draw(st: *State, p: *tui.Ui) !void {
                if (st.visible_cards == 0) {
                    try p.paragraph(.{ .raw = "No services match the active filter.", .wrap = .word }, null);
                    return;
                }
                const svc = services[st.card_indices[st.selected_idx]];
                try p.text(svc.name, .{ .style = p.theme.title }, null);
                p.space(1);
                try p.paragraph(.{
                    .raw = "Cards above are custom stateless components composed cleanly inside `tui.Ui` regions with recorded mouse hitboxes.",
                    .wrap = .word,
                }, null);
                p.space(1);
                try p.gauge(.{ .ratio = @as(f64, @floatFromInt(@min(@as(u16, 100), svc.latency_ms))) / 100.0, .label = "Latency Budget" }, null);
            }
        }.draw);
    }

    var ft = shell[3];
    ft.statusBar(.{
        .left = &.{
            .{ .text = if (state.focus.isFocused(0)) "SEARCH" else "BROWSE", .badge = true },
            .{ .text = @tagName(state.filter) },
        },
        .right = &.{.{ .text = "Tab Switch  Arrows/Click Select  Esc Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .app = .{ .name = "Custom UI", .version = tui.version },
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 96, .height = 24 } } else .auto,
        .settings = .{ .mouse = true },
    });
    defer app.deinit();

    var state = State{
        .search = app.textInput(),
    };
    defer state.deinit();

    if (headless) {
        try app.draw(&state, render);
        try state.search.insertSlice("auth");
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "auth-worker") != null);
        std.debug.assert(app.cursorPos() != null);

        // Verify responsive compact mode cleanly without panics or overlaps.
        try app.resizeTest(.{ .width = 48, .height = 18 });
        try app.draw(&state, render);
        const narrow_snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, narrow_snap, "auth-worker") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
