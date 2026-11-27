const std = @import("std");
const tui = @import("tui");

const State = struct {};

fn onEvent(_: *State, event: tui.Event, app: *tui.App) !bool {
    switch (event) {
        .key => |k| if (k.isChar('q') or event.isEscape() or event.isCtrlC()) {
            app.quit();
            return false;
        },
        else => {},
    }
    return true;
}

fn render(_: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const grid = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = grid[0];
    hdr.header(.{ .title = "Borders & Collapsing", .right = "Block Showcase" }, hdr.area);

    const top_row = grid[1].rows(2, .{ .{ .fill = 1 }, .{ .fill = 1 } }, .{ .margin = tui.Margin.uniform(1), .spacing = .{ .space = 1 } });
    const upper_cards = top_row[0].cols(4, .{ .{ .fill = 1 }, .{ .fill = 1 }, .{ .fill = 1 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 1 } });

    const presets = [_]struct { name: []const u8, btype: tui.BorderType }{
        .{ .name = "Rounded", .btype = .rounded },
        .{ .name = "Plain", .btype = .plain },
        .{ .name = "Double", .btype = .double },
        .{ .name = "Thick", .btype = .thick },
    };
    for (upper_cards, presets) |cell, preset| {
        var c = cell;
        try c.panel(.{ .title = preset.name, .border_type = preset.btype }, c.area, preset.name, struct {
            fn draw(nm: []const u8, p: *tui.Ui) !void {
                try p.text(nm, .{ .alignment = .center }, null);
            }
        }.draw);
    }

    // Collapsing adjacent blocks: overlapping edges automatically merge into clean box junctions!
    var lower = top_row[1];
    try lower.panel(.{ .title = "Collapsed Adjacent Grid", .borders = tui.BorderSides.none }, lower.area, {}, struct {
        fn draw(_: void, p: *tui.Ui) !void {
            const a = p.area;
            if (a.width < 12 or a.height < 4) return;
            const mid = a.left() + a.width / 2;
            const left_r = tui.Rect.init(a.left(), a.top(), (mid - a.left()) + 1, a.height);
            const right_r = tui.Rect.init(mid, a.top(), a.right() - mid, a.height);
            try p.block(.{ .title = "Left Pane", .border_type = .plain, .merge_borders = .fuzzy }, left_r);
            try p.block(.{ .title = "Right Pane", .border_type = .plain, .merge_borders = .fuzzy }, right_r);
        }
    }.draw);

    var ft = grid[2];
    ft.statusBar(.{
        .left = &.{ .{ .text = "BORDERS", .badge = true }, .{ .text = "16 built-in sets + collapsing merge" } },
        .right = &.{.{ .text = "q Quit" }},
    }, ft.area);
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
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "Rounded") != null);
        std.debug.assert(std.mem.indexOf(u8, snap, "┬") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
