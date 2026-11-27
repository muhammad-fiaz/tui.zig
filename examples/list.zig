const std = @import("std");
const tui = @import("tui");

const tasks = [_][]const u8{
    "01. Parse terminal capability database",
    "02. Initialize double-buffered cell grid",
    "03. Compute differential SGR sequences",
    "04. Build core layout solver",
    "05. Implement UTF-8 grapheme width table",
    "06. Assemble interactive form widgets",
    "07. Implement Braille high-res canvas",
    "08. Verify cross-platform backend targets",
    "09. Document public Zig API surface",
    "10. Release v0.1.0 open-source library",
};

const State = struct {
    list: tui.ListState = .{ .selected = 0 },
    inner_rect: tui.Rect = tui.Rect.zero,
    scrollbar_rect: tui.Rect = tui.Rect.zero,
    visible_rows: u16 = 12,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    var sb_state = tui.ScrollbarState{
        .content_length = tasks.len,
        .viewport_content_length = state.visible_rows,
        .position = state.list.offset,
    };
    if ((tui.Scrollbar{ .orientation = .vertical_right }).handleEvent(&sb_state, event, state.scrollbar_rect)) {
        state.list.offset = sb_state.position;
        if (state.list.selected) |sel| {
            if (sel < state.list.offset) state.list.selected = state.list.offset;
            if (sel >= state.list.offset + state.visible_rows) {
                state.list.selected = state.list.offset +| state.visible_rows -| 1;
            }
        }
        return true;
    }
    _ = state.list.handleEvent(event, tasks.len, @max(@as(u16, 1), state.visible_rows), state.inner_rect, true);
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const rows = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = rows[0];
    hdr.header(.{ .title = "List Widget", .right = "j/k, Arrows, Wheel or Click" }, hdr.area);

    const body = rows[1].margin(tui.Margin.uniform(1));
    const list_blk = tui.Block{
        .title = "Release Checklist",
        .focused = true,
        .padding = tui.Padding.symmetric(1, 0),
    };
    state.inner_rect = list_blk.inner(body.area);
    state.visible_rows = state.inner_rect.height;

    var list_ui = body;
    try list_ui.list(.{
        .raw_items = &tasks,
        .block = list_blk,
        .highlight_symbol = "▶ ",
    }, &state.list, body.area);

    var sb_state = tui.ScrollbarState{
        .content_length = tasks.len,
        .viewport_content_length = state.visible_rows,
        .position = state.list.offset,
    };
    var sb_ui = body;
    const sb_rect = body.area.inner(tui.Margin.symmetric(0, 1));
    state.scrollbar_rect = tui.Rect.init(sb_rect.right() -| 1, sb_rect.top(), 1, sb_rect.height);
    try sb_ui.scrollbar(.{ .orientation = .vertical_right }, &sb_state, sb_rect);

    var ft = rows[2];
    const sel_label = if (state.list.selected) |s| tasks[s] else "None";
    ft.statusBar(.{
        .left = &.{ .{ .text = "LIST", .badge = true }, .{ .text = sel_label } },
        .right = &.{.{ .text = "Home/End/PageUp/Down  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 80, .height = 16 } } else .auto,
        .settings = .{ .mouse = true },
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        try app.draw(&state, render);
        _ = try onEvent(&state, .{ .key = .{ .code = .down } }, &app);
        _ = try onEvent(&state, .{ .key = .{ .code = .down } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Release Checklist") != null);
        std.debug.assert(std.mem.indexOf(u8, snap, "03. Compute differential") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
