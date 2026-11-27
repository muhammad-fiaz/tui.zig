const std = @import("std");
const tui = @import("tui");

const State = struct {
    flex_mode: usize = 0,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    switch (event) {
        .key => |k| {
            if (k.isChar('q') or event.isEscape() or event.isCtrlC()) {
                app.quit();
                return false;
            }
            if (k.isChar('f')) {
                state.flex_mode = (state.flex_mode + 1) % 3;
            }
        },
        else => {},
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const flex: tui.Flex = switch (state.flex_mode) {
        0 => .start,
        1 => .center,
        else => .space_between,
    };

    const outer = ui.rows(3, .{
        .{ .length = 1 },
        .{ .fill = 1 },
        .{ .length = 1 },
    }, .{});

    var hdr = outer[0];
    hdr.header(.{ .title = "Basic Layout", .subtitle = @tagName(flex), .right = "f cycle flex" }, hdr.area);

    const body_cols = outer[1].cols(3, .{
        .{ .length = 22 },
        .{ .percentage = 45 },
        .{ .fill = 1 },
    }, .{ .margin = tui.Margin.uniform(1), .spacing = .{ .space = 1 } });

    var sidebar = body_cols[0];
    try sidebar.panel(.{ .title = "Fixed 22", .border_type = .plain }, sidebar.area, {}, struct {
        fn draw(_: void, p: *tui.Ui) !void {
            try p.paragraph(.{ .raw = "Left sidebar pinned to 22 columns.", .wrap = .word }, null);
        }
    }.draw);

    var middle = body_cols[1];
    try middle.panel(.{ .title = "Nested Flex Rows", .focused = true }, middle.area, flex, struct {
        fn draw(fl: tui.Flex, p: *tui.Ui) !void {
            const sub = p.rows(3, .{
                .{ .length = 3 },
                .{ .length = 3 },
                .{ .length = 3 },
            }, .{ .flex = fl, .spacing = .{ .space = 1 } });
            for (sub, 0..) |cell_ui, idx| {
                var c = cell_ui;
                var title_buf: [24]u8 = undefined;
                const ttl = std.fmt.bufPrint(&title_buf, "Card {d}", .{idx + 1}) catch "Card";
                try c.block(.{ .title = ttl, .border_type = .rounded }, c.area);
            }
        }
    }.draw);

    var right = body_cols[2];
    try right.panel(.{ .title = "Fill Remainder" }, right.area, {}, struct {
        fn draw(_: void, p: *tui.Ui) !void {
            try p.paragraph(.{
                .raw = "Right column automatically expands with `.fill = 1` across remaining horizontal space.",
                .wrap = .word,
            }, null);
        }
    }.draw);

    var st = outer[2];
    st.statusBar(.{
        .left = &.{ .{ .text = "LAYOUT", .badge = true }, .{ .text = @tagName(flex) } },
        .right = &.{.{ .text = "f Flex  q Quit" }},
    }, st.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 80, .height = 24 } } else .auto,
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        try app.draw(&state, render);
        _ = try onEvent(&state, .{ .key = .{ .code = .{ .char = 'f' } } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Fixed 22") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
