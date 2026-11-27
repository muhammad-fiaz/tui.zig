const std = @import("std");
const tui = @import("tui");

const State = struct {
    focus: tui.FocusGroup = .{ .count = 4 },
    clicks: [4]usize = .{ 0, 0, 0, 0 },
    last_action: []const u8 = "None yet",
    btn_rects: [4]tui.Rect = @splat(tui.Rect.zero),
};

fn triggerButton(state: *State, idx: usize) void {
    state.focus.active = idx;
    state.clicks[idx] += 1;
    state.last_action = switch (idx) {
        0 => "Deployed build",
        1 => "Saved configuration",
        2 => "Reset cache",
        else => "Opened logs",
    };
}

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    if (state.focus.handleEvent(event)) return true;

    if (event == .mouse and event.mouse.kind == .down and event.mouse.button == .left) {
        for (state.btn_rects, 0..) |rect, i| {
            if (event.mouse.isInside(rect)) {
                triggerButton(state, i);
                break;
            }
        }
        return true;
    }

    if (event == .key and event.key.kind != .release and (event.key.code == .enter or event.isChar(' '))) {
        triggerButton(state, state.focus.active);
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "Buttons", .right = "Tab Cycle  Enter / Click Activate" }, hdr.area);

    var panel = layout[1].margin(tui.Margin.uniform(1));
    try panel.panel(.{ .title = "Action Variants", .padding = tui.Padding.uniform(1) }, panel.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            const specs = [_]struct { lbl: []const u8, var_kind: tui.ButtonVariant, icon: []const u8 }{
                .{ .lbl = "Deploy", .var_kind = .primary, .icon = "▶" },
                .{ .lbl = "Save", .var_kind = .success, .icon = "✓" },
                .{ .lbl = "Purge", .var_kind = .danger, .icon = "!" },
                .{ .lbl = "Logs", .var_kind = .outline, .icon = "≡" },
            };
            const btn_cols = p.cols(4, .{ .{ .fill = 1 }, .{ .fill = 1 }, .{ .fill = 1 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 2 } });
            for (btn_cols, specs, 0..) |col_ui, sp, i| {
                var c = col_ui;
                const r = c.allocateRows(3);
                st.btn_rects[i] = r;
                try c.button(.{
                    .label = sp.lbl,
                    .icon = sp.icon,
                    .variant = sp.var_kind,
                    .focused = st.focus.isFocused(i),
                }, r);
                var count_buf: [32]u8 = undefined;
                const txt = std.fmt.bufPrint(&count_buf, "Clicks: {d}", .{st.clicks[i]}) catch "";
                try c.text(txt, .{ .alignment = .center, .style = c.theme.muted }, c.allocateRows(1));
            }
        }
    }.draw);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{ .{ .text = "LAST", .badge = true }, .{ .text = state.last_action } },
        .right = &.{.{ .text = "Tab Focus  Enter / Click Press  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 80, .height = 24 } } else .auto,
        .settings = .{ .mouse = true },
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        try app.draw(&state, render);
        const target = state.btn_rects[1];
        _ = try onEvent(&state, .{ .mouse = .{ .kind = .down, .button = .left, .x = target.left() + 1, .y = target.top() + 1 } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Saved configuration") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
