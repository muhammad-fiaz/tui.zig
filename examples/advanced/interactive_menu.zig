const std = @import("std");
const tui = @import("tui");

const export_formats = [_]tui.MenuItem{
    .{ .label = "Plain Text (.txt)", .id = "export.txt", .shortcut = "1" },
    .{ .label = "ANSI Color (.ans)", .id = "export.ans", .shortcut = "2" },
    .{ .label = "JSON Snapshot", .id = "export.json", .shortcut = "3" },
};

const file_actions = [_]tui.MenuItem{
    .{ .label = "New Project", .id = "file.new", .shortcut = "Ctrl+N" },
    .{ .label = "Open Workspace", .id = "file.open", .shortcut = "Ctrl+O" },
    .{ .label = "Export As", .children = &export_formats },
    .{ .label = "", .separator = true },
    .{ .label = "Quit", .id = "file.quit", .shortcut = "Ctrl+Q" },
};

const edit_actions = [_]tui.MenuItem{
    .{ .label = "Undo", .id = "edit.undo", .shortcut = "Ctrl+Z" },
    .{ .label = "Redo", .id = "edit.redo", .shortcut = "Ctrl+Y" },
    .{ .label = "", .separator = true },
    .{ .label = "Find in Workspace", .id = "edit.find", .shortcut = "Ctrl+F" },
};

const help_actions = [_]tui.MenuItem{
    .{ .label = "Documentation", .id = "help.docs", .shortcut = "F1" },
    .{ .label = "About tui.zig", .id = "help.about", .shortcut = "F2" },
};

const State = struct {
    menu: tui.MenuState = .{ .active_group = 0, .depth = 1 },
    show_sidebar: bool = true,
    word_wrap: bool = true,
    confirm: tui.ConfirmState = .{ .open = false },
    status: []const u8 = "Choose an action from the cascading menu",
};

const quit_dialog = tui.ConfirmDialog{
    .title = "Quit Application",
    .message = "Close Interactive Menu session?",
    .confirm_label = "Quit",
    .cancel_label = "Stay",
    .backdrop_dismiss = true,
};

fn buildGroups(state: *const State, view_buf: *[3]tui.MenuItem) [4]tui.MenuGroup {
    view_buf.* = .{
        .{ .label = "Show Sidebar", .id = "view.sidebar", .checked = state.show_sidebar, .shortcut = "Ctrl+B" },
        .{ .label = "Word Wrap", .id = "view.wrap", .checked = state.word_wrap, .shortcut = "Alt+Z" },
        .{ .label = "Reset Layout", .id = "view.reset", .shortcut = "Ctrl+0" },
    };
    return .{
        .{ .label = "File", .items = &file_actions },
        .{ .label = "Edit", .items = &edit_actions },
        .{ .label = "View", .items = view_buf },
        .{ .label = "Help", .items = &help_actions },
    };
}

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isCtrlC()) {
        app.quit();
        return false;
    }
    if (state.confirm.open) {
        switch (state.confirm.handleEventAt(event, app.area(), quit_dialog)) {
            .confirmed => {
                app.quit();
                return false;
            },
            .cancelled => {
                state.status = "Exit cancelled";
                return true;
            },
            .pending => return true,
        }
    }
    if (event.isChar('q')) {
        state.confirm.open = true;
        return true;
    }

    var view_buf: [3]tui.MenuItem = undefined;
    const groups = buildGroups(state, &view_buf);
    const bar_area = tui.Rect.init(0, 0, app.area().width, 1);

    switch (state.menu.handleEvent(&groups, event, bar_area, app.area(), 2)) {
        .triggered => {
            if (state.menu.triggered) |item| {
                const aid = item.actionId();
                if (std.mem.eql(u8, aid, "file.quit")) {
                    state.confirm.open = true;
                } else if (std.mem.eql(u8, aid, "view.sidebar")) {
                    state.show_sidebar = !state.show_sidebar;
                    state.status = "Toggled Sidebar";
                } else if (std.mem.eql(u8, aid, "view.wrap")) {
                    state.word_wrap = !state.word_wrap;
                    state.status = "Toggled Word Wrap";
                } else {
                    state.status = item.label;
                }
            }
            return true;
        },
        .moved, .opened, .closed => return true,
        .none => {},
    }

    if (event.isEscape()) {
        state.confirm.open = true;
        return true;
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var view_buf: [3]tui.MenuItem = undefined;
    const groups = buildGroups(state, &view_buf);

    var body = layout[1].margin(tui.Margin.uniform(1));
    try body.panel(.{ .title = "Command Workspace", .padding = tui.Padding.uniform(1) }, body.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            try p.paragraph(.{
                .raw = "Use Left/Right/Up/Down or click menus. Enter/Right opens nested submenus (`Export As ▸`). View menu toggles checkmarks.",
            }, null);
            p.space(1);
            try p.text(st.status, .{ .style = p.theme.accent }, null);
            p.space(1);
            p.checkbox(.{ .label = "Sidebar Visible", .checked = st.show_sidebar }, null);
            p.checkbox(.{ .label = "Word Wrap", .checked = st.word_wrap }, null);
        }
    }.draw);

    // Render DropdownMenu bar + cascading submenus above workspace
    try ui.dropdownMenu(.{ .groups = &groups }, &state.menu, layout[0].area, ui.area);

    if (state.confirm.open) {
        try ui.confirmDialog(quit_dialog, &state.confirm, null);
    }

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{ .{ .text = "MENU", .badge = true }, .{ .text = state.status } },
        .right = &.{.{ .text = "Arrows Navigate  Enter/Right Submenu  q Quit" }},
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
        // Navigate down to "Export As" and open nested submenu
        _ = try onEvent(&state, .{ .key = .{ .code = .down } }, &app);
        _ = try onEvent(&state, .{ .key = .{ .code = .down } }, &app);
        _ = try onEvent(&state, .{ .key = .{ .code = .right } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Plain Text (.txt)") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
