---
title: Getting Started
description: Build your first cross-platform terminal user interface application with tui.zig on Zig 0.17.0+.
keywords: tui.zig getting started, zig terminal ui tutorial, zig 0.17.0, tui.init, tui.App
---

# Getting Started

**tui.zig** provides an explicit-allocator terminal UI framework for Zig **0.17.0+**. Every frame renders into a double-buffered cell grid and writes only modified spans to the OS console or POSIX terminal.

## Minimal Interactive Application

1. Initialize an `App` via `tui.init(allocator, .{ ... })` with `defer app.deinit();`.
2. Call `try app.enter()` to switch cleanly into raw mode / alternate screen (restored automatically on `deinit()` or `restore()`).
3. Run your event and render loop with `app.run(&state, .{ .onEvent = onEvent, .render = render })`.

```zig
const std = @import("std");
const tui = @import("tui");

const State = struct {
    ticks: u64 = 0,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    switch (event) {
        .key => |k| if (k.isChar('q') or event.isEscape() or event.isCtrlC()) {
            app.quit();
            return false;
        },
        .tick => state.ticks +%= 1,
        else => {},
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();

    const layout = ui.rows(3, .{
        .{ .length = 1 },
        .{ .fill = 1 },
        .{ .length = 1 },
    }, .{});

    var top = layout[0];
    top.header(.{ .title = "tui.zig", .subtitle = "Starter", .right = "v" ++ tui.version }, top.area);

    var center = layout[1].margin(tui.Margin.symmetric(4, 2));
    try center.panel(.{ .title = "Welcome", .focused = true, .padding = tui.Padding.uniform(1) }, center.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            try p.paragraph(.{
                .raw = "Native Zig 0.17.0+ terminal rendering with double buffering and zero per-frame heap churn.",
                .wrap = .word,
            }, null);
            p.space(1);
            p.spinner(.{ .tick = st.ticks, .label = "Active event loop" }, null);
        }
    }.draw);

    var bottom = layout[2];
    bottom.statusBar(.{
        .left = &.{.{ .text = "READY", .badge = true }},
        .right = &.{.{ .text = "q / Esc Quit" }},
    }, bottom.area);
}

pub fn main(init: std.process.Init) !void {
    var app = try tui.init(init.gpa, .{
        .io = init.io,
        .settings = .{ .title = "tui.zig Quickstart" },
    });
    defer app.deinit();

    var state = State{};
    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
```

## Next Steps

- Run `zig build run-hello-world` to launch this starter interactively.
- Explore [Layout Engine & Constraints](/guides/layout-and-constraints) to build multi-pane interfaces.
- Read [Custom Widgets & Client UI Architecture](/guides/custom-widgets) to author reusable client components.
- Check [Headless Testing](/guides/testing-and-headless) to test interfaces inside `std.testing` without a terminal.
