const std = @import("std");
const tui = @import("tui");

const State = struct {
    table: tui.TableState = .{ .selected = 0 },
    table_rect: tui.Rect = tui.Rect.zero,
};

const table_rows = [_]tui.TableRow{
    tui.TableRow.fromStrings(&.{ "nginx-gateway", "Running", "1.8%", "42 MB", "99.99%" }),
    tui.TableRow.fromStrings(&.{ "postgres-primary", "Running", "12.4%", "512 MB", "99.95%" }),
    tui.TableRow.fromStrings(&.{ "redis-cache", "Running", "0.4%", "28 MB", "100.0%" }),
    tui.TableRow.fromStrings(&.{ "worker-queue", "Degraded", "48.2%", "290 MB", "96.40%" }),
    tui.TableRow.fromStrings(&.{ "metrics-sink", "Running", "3.1%", "110 MB", "99.90%" }),
    tui.TableRow.fromStrings(&.{ "tls-terminator", "Stopped", "0.0%", "0 MB", "98.10%" }),
};

const widths = [_]tui.Constraint{
    .{ .length = 18 },
    .{ .length = 11 },
    .{ .length = 8 },
    .{ .length = 10 },
    .{ .fill = 1 },
};

const cluster_table = tui.Table{
    .header = tui.TableRow.fromStrings(&.{ "Service", "Status", "CPU", "Memory", "Uptime" }),
    .footer = tui.TableRow.fromStrings(&.{ "Total: 6", "4 Healthy", "65.9%", "982 MB", "avg 98.9%" }),
    .rows = &table_rows,
    .widths = &widths,
    .block = .{ .title = "Cluster Services", .focused = true },
    .show_header_separator = true,
    .empty_message = "No matching services",
    .striped_style = .{ .dim = true },
    .column_highlight_style = .{ .underline = true },
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    _ = cluster_table.handleEvent(&state.table, event, state.table_rect);
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});
    var hdr = layout[0];
    hdr.header(.{ .title = "Table Widget", .right = "Up/Down Row  Left/Right Col" }, hdr.area);

    var body = layout[1].margin(tui.Margin.uniform(1));
    state.table_rect = body.area;
    try body.table(cluster_table, &state.table, body.area);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = "TABLE", .badge = true }},
        .right = &.{.{ .text = "Arrows / Click Navigate  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 80, .height = 20 } } else .auto,
        .settings = .{ .mouse = true },
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        try app.draw(&state, render);
        _ = try onEvent(&state, .{ .key = .{ .code = .down } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "postgres-primary") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
