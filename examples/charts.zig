const std = @import("std");
const tui = @import("tui");

const pie_styles = [_]tui.PieStyle{ .solid, .segmented, .hud, .rose };

const State = struct {
    pie_style_idx: usize = 0,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    switch (event) {
        .key => |k| {
            if (k.kind == .release) return true;
            if (k.isChar('q') or event.isEscape() or event.isCtrlC()) {
                app.quit();
                return false;
            }
            if (k.isChar('p')) {
                state.pie_style_idx = (state.pie_style_idx + 1) % pie_styles.len;
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
    hdr.header(.{ .title = "Charts, Sparklines, BarCharts & PieCharts", .subtitle = @tagName(pie_styles[state.pie_style_idx]), .right = "p Pie Style" }, hdr.area);

    const grid = layout[1].rows(2, .{ .{ .percentage = 52 }, .{ .fill = 1 } }, .{ .margin = tui.Margin.uniform(1), .spacing = .{ .space = 1 } });

    const series_a = [_]tui.Point{
        .{ .x = 0, .y = 18 },
        .{ .x = 20, .y = 42 },
        .{ .x = 40, .y = 35 },
        .{ .x = 60, .y = 74 },
        .{ .x = 80, .y = 66 },
        .{ .x = 100, .y = 92 },
    };
    const series_b = [_]tui.Point{
        .{ .x = 0, .y = 30 },
        .{ .x = 25, .y = 25 },
        .{ .x = 50, .y = 52 },
        .{ .x = 75, .y = 48 },
        .{ .x = 100, .y = 61 },
    };
    const datasets = [_]tui.Dataset{
        .{ .name = "Throughput", .data = &series_a, .style = .{ .foreground = .cyan }, .marker = .braille },
        .{ .name = "Baseline", .data = &series_b, .style = .{ .foreground = .magenta }, .marker = .dot },
    };

    const top_cols = grid[0].cols(2, .{ .{ .percentage = 58 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 1 } });
    var top_ui = top_cols[0];
    try top_ui.chart(.{
        .datasets = &datasets,
        .x_axis = .{ .title = "Time (s)", .labels = &.{ "0", "50", "100" } },
        .y_axis = .{ .title = "MB/s", .labels = &.{ "0", "50", "100" } },
        .block = .{ .title = "Network Throughput", .border_type = .rounded },
    }, top_ui.area);

    const ps = pie_styles[state.pie_style_idx];
    var pie_ui = top_cols[1];
    try pie_ui.pieChart(.{
        .slices = &.{
            .{ .label = "API", .value = 46, .color = tui.palette.sky.c400 },
            .{ .label = "Worker", .value = 31, .color = tui.palette.emerald.c400 },
            .{ .label = "Cache", .value = 23, .color = tui.palette.amber.c400 },
        },
        .pie_style = ps,
        .donut_ratio = if (ps == .solid) 0.45 else 0.0,
        .center_label = if (ps == .solid or ps == .segmented or ps == .hud) "100%" else null,
        .block = .{ .title = "Traffic Share", .border_type = .rounded },
    }, pie_ui.area);

    const bottom_cols = grid[1].cols(2, .{ .{ .percentage = 50 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 1 } });
    var b0 = bottom_cols[0];
    try b0.sparkline(.{
        .raw_data = &.{ 3, 7, 12, 9, 18, 22, 17, 29, 24, 31, 28, 35, 32, 39 },
        .block = .{ .title = "Latency Sparkline" },
        .style = b0.theme.success,
    }, b0.area);

    var b1 = bottom_cols[1];
    try b1.barChart(.{
        .bars = &.{
            tui.Bar.init("US", 78),
            tui.Bar.init("EU", 54),
            tui.Bar.init("AP", 42),
        },
        .direction = .horizontal,
        .block = .{ .title = "Regional Traffic" },
    }, b1.area);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{ .{ .text = "CHARTS", .badge = true }, .{ .text = @tagName(ps) } },
        .right = &.{.{ .text = "p Pie Style  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 96, .height = 26 } } else .auto,
    });
    defer app.deinit();

    var state = State{};
    if (headless) {
        for (0..pie_styles.len) |_| {
            try app.draw(&state, render);
            const snap = try app.snapshot();
            std.debug.assert(std.mem.indexOf(u8, snap, "Throughput") != null);
            std.debug.assert(std.mem.indexOf(u8, snap, "API 46%") != null);
            std.debug.assert(std.mem.indexOf(u8, snap, "Regional Traffic") != null);
            _ = try onEvent(&state, .{ .key = .{ .code = .{ .char = 'p' } } }, &app);
        }
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
