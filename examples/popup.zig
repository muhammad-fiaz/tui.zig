const std = @import("std");
const tui = @import("tui");

const State = struct {
    dialog: tui.ConfirmState = .{ .open = true },
    popup_trans: tui.Transition = .{ .active = true, .progress = 0.2, .duration_ms = 220 },
    toast: tui.ToastState = blk: {
        var t = tui.ToastState{ .duration_ms = 2600 };
        t.show("Status", "Pending user choice", .info);
        break :blk t;
    },
    last_result: []const u8 = "Pending user choice",
};

const confirm_dialog = tui.ConfirmDialog{
    .title = "Confirm Reset",
    .message = "Reset staged workspace artifacts before rebuilding?",
    .confirm_label = "Reset",
    .cancel_label = "Keep",
    .destructive = true,
    .backdrop_dismiss = true,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    if (event == .tick) {
        const dt = app.deltaMs();
        _ = state.popup_trans.update(dt);
        _ = state.toast.update(dt);
        return true;
    }
    if (state.dialog.open) {
        switch (state.dialog.handleEventAt(event, app.area(), confirm_dialog)) {
            .confirmed => {
                state.last_result = "Confirmed archive reset";
                state.popup_trans.close();
                state.toast.show("Confirmed", state.last_result, .success);
            },
            .cancelled => {
                state.last_result = "Cancelled action";
                state.popup_trans.close();
                state.toast.show("Cancelled", state.last_result, .warning);
            },
            .pending => {},
        }
        return true;
    }
    if (event.isChar('o') or (event == .key and event.key.code == .enter)) {
        state.dialog.open = true;
        state.popup_trans.open();
    }
    if (event.isEscape()) {
        app.quit();
        return false;
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "Animated Popups, Modals & Toasts", .right = "o Reopen Dialog  q Quit" }, hdr.area);

    var bg = layout[1].margin(tui.Margin.uniform(1));
    try bg.panel(.{ .title = "Workspace Background" }, bg.area, state.last_result, struct {
        fn draw(res: []const u8, p: *tui.Ui) !void {
            try p.paragraph(.{
                .raw = "Background dashboard stays rendered underneath modal dialogs.\nPress `o` or `Enter` to reopen the animated confirmation popup, or click outside to dismiss.",
                .wrap = .word,
            }, null);
            p.space(1);
            try p.text(res, .{ .style = p.theme.accent }, null);
        }
    }.draw);

    if (state.dialog.open or state.popup_trans.isVisible()) {
        tui.fx.dimBackdrop(ui.buffer, ui.area, state.popup_trans.eased() * 0.85);
        const lay = confirm_dialog.layout(ui.area);
        const anim_box = state.popup_trans.animatedRect(lay.box, .center);
        if (!anim_box.isEmpty()) {
            const anim_dlg = tui.ConfirmDialog{
                .title = confirm_dialog.title,
                .message = confirm_dialog.message,
                .confirm_label = confirm_dialog.confirm_label,
                .cancel_label = confirm_dialog.cancel_label,
                .destructive = confirm_dialog.destructive,
                .backdrop_dismiss = confirm_dialog.backdrop_dismiss,
                .width = anim_box.width,
                .height = anim_box.height,
            };
            var vis_state = state.dialog;
            vis_state.open = true;
            try ui.confirmDialog(anim_dlg, &vis_state, null);
        }
    }

    try state.toast.render(ui, ui.area);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = if (state.dialog.open) "MODAL" else "NORMAL", .badge = true }},
        .right = &.{.{ .text = "Tab/Click/Esc Choose  o Reopen  q Quit" }},
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
        for (0..25) |_| {
            _ = app.advanceTimer();
            _ = try onEvent(&state, .tick, &app);
        }
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Confirm Reset") != null);

        _ = try onEvent(&state, .{ .mouse = .{ .kind = .down, .button = .left, .x = 0, .y = 0 } }, &app);
        std.debug.assert(!state.dialog.open);
        try app.draw(&state, render);
        const closed_snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, closed_snap, "Cancelled action") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
