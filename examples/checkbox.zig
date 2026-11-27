const std = @import("std");
const tui = @import("tui");

const State = struct {
    items: [4]bool = .{ true, false, true, false },
    focus: tui.FocusGroup = .{ .count = 4 },
    row_rects: [4]tui.Rect = @splat(tui.Rect.zero),
};

const labels = [_][]const u8{
    "Enable TLS encryption",
    "Verbose diagnostic logging",
    "Auto-save workspace drafts",
    "Emit synchronized output frames",
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    if (state.focus.handleEvent(event)) return true;
    switch (event) {
        .mouse => |m| {
            if (m.kind == .down and m.button == .left) {
                for (state.row_rects, 0..) |r, i| {
                    if (m.isInside(r)) {
                        state.focus.active = i;
                        state.items[i] = !state.items[i];
                        break;
                    }
                }
            }
        },
        .key => |k| {
            if (k.kind == .release) return true;
            if (k.code == .down) state.focus.next();
            if (k.code == .up) state.focus.prev();
            if (k.isChar(' ') or k.code == .enter) {
                state.items[state.focus.active] = !state.items[state.focus.active];
            }
        },
        else => {},
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});
    var hdr = layout[0];
    hdr.header(.{ .title = "Checkboxes", .right = "Space / Enter / Click Toggle" }, hdr.area);

    var body = layout[1].margin(tui.Margin.uniform(1));
    try body.panel(.{ .title = "Preferences", .padding = tui.Padding.uniform(1) }, body.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            for (labels, 0..) |lbl, i| {
                const row = p.allocateRows(1);
                st.row_rects[i] = row;
                p.checkbox(.{
                    .label = lbl,
                    .checked = st.items[i],
                    .focused = st.focus.isFocused(i),
                }, row);
                p.space(1);
            }
            const all_on = st.items[0] and st.items[1] and st.items[2] and st.items[3];
            const none_on = !st.items[0] and !st.items[1] and !st.items[2] and !st.items[3];
            const tri: tui.CheckState = if (all_on) .checked else if (none_on) .unchecked else .indeterminate;
            try p.divider(.{ .label = "Aggregate" }, null);
            p.space(1);
            p.checkbox(.{ .label = "Select All Summary", .tristate = tri }, null);
        }
    }.draw);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = "CHECKBOX", .badge = true }},
        .right = &.{.{ .text = "Up/Down Navigate  Space Toggle  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 72, .height = 20 } } else .auto,
        .settings = .{ .mouse = true },
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        try app.draw(&state, render);
        _ = try onEvent(&state, .{ .key = .{ .code = .{ .char = ' ' } } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Preferences") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
