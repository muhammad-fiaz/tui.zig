const std = @import("std");
const tui = @import("tui");

const State = struct {
    env_radio: tui.RadioState = .{ .selected = 1 },
    region_select: tui.SelectState = .{ .selected = 0 },
    focus_select: bool = false,
    radio_rect: tui.Rect = tui.Rect.zero,
    select_rect: tui.Rect = tui.Rect.zero,
};

const env_items = [_][]const u8{ "Development", "Staging", "Production" };
const regions = [_][]const u8{ "us-east-1", "eu-central-1", "ap-southeast-1", "us-west-2" };

fn radioWidget(focused: bool) tui.RadioGroup {
    return .{
        .items = &env_items,
        .block = .{
            .title = "Deployment Target",
            .focused = focused,
            .padding = tui.Padding.uniform(1),
        },
        .focused = focused,
    };
}

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() and !state.region_select.open) {
        app.quit();
        return false;
    }
    if (event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    if (event == .key and event.key.kind != .release and event.key.code == .tab) {
        state.focus_select = !state.focus_select;
        return true;
    }
    if (event == .mouse and event.mouse.kind == .down and event.mouse.button == .left) {
        if (event.mouse.isInside(state.radio_rect)) {
            state.focus_select = false;
        } else if (event.mouse.isInside(state.select_rect) or state.region_select.open) {
            state.focus_select = true;
        }
    }
    if (state.focus_select) {
        _ = state.region_select.handleEvent(event, regions.len, state.select_rect, true);
    } else {
        _ = radioWidget(true).handleEvent(&state.env_radio, event, state.radio_rect);
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});
    var hdr = layout[0];
    hdr.header(.{ .title = "Radio & Select", .right = "Tab Switch  Enter/Space Toggle Dropdown" }, hdr.area);

    var left: tui.Ui = undefined;
    var right: tui.Ui = undefined;
    if (layout[1].isCompact(56)) {
        const stacked = layout[1].rows(2, .{ .{ .length = 7 }, .{ .fill = 1 } }, .{ .margin = tui.Margin.uniform(1), .spacing = .{ .space = 1 } });
        left = stacked[0];
        right = stacked[1];
    } else {
        const cols = layout[1].cols(2, .{ .{ .percentage = 50 }, .{ .fill = 1 } }, .{ .margin = tui.Margin.uniform(1), .spacing = .{ .space = 2 } });
        left = cols[0];
        right = cols[1];
    }

    state.radio_rect = left.area;
    try left.radio(radioWidget(!state.focus_select), &state.env_radio, left.area);

    state.select_rect = right.allocateRows(3);
    try right.select(.{
        .items = &regions,
        .label = "Cloud Region",
        .focused = state.focus_select,
    }, &state.region_select, state.select_rect);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{
            .{ .text = env_items[state.env_radio.selected], .badge = true },
            .{ .text = regions[state.region_select.selected] },
        },
        .right = &.{.{ .text = "Tab Switch  Arrows Move  q Quit" }},
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
        _ = try onEvent(&state, .{ .key = .{ .code = .down } }, &app);
        state.focus_select = true;
        // Expand dropdown
        _ = try onEvent(&state, .{ .key = .{ .code = .enter } }, &app);
        std.debug.assert(state.region_select.open);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Production") != null);
        std.debug.assert(std.mem.indexOf(u8, snap, "eu-central-1") != null);
        // Select next item and collapse dropdown
        _ = try onEvent(&state, .{ .key = .{ .code = .down } }, &app);
        _ = try onEvent(&state, .{ .key = .{ .code = .enter } }, &app);
        std.debug.assert(!state.region_select.open);
        std.debug.assert(state.region_select.selected == 1);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
