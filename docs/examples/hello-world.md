---
title: Hello World Example
description: Annotated walkthrough of examples/hello_world.zig showing App initialization, layout, panel, and headless testing.
keywords: tui hello world, zig tui quickstart example, tui.init, tui.Ui
---

# Hello World & Quickstart

Run interactively:

```sh
zig build run-hello-world
```

## Highlights

- Uses `tui.init(alloc, .{ .io = init.io, .backend = if (headless) .{ .memory = ... } else .auto })`
- Automatically tears down raw mode and alternate screen via `defer app.deinit();`
- Demonstrates flat `Ui` composition (`header`, `panel`, `paragraph`, `spinner`, `statusBar`)

## Source (`examples/hello_world.zig`)

```zig
const std = @import("std");
const tui = @import("tui");

const State = struct {
    ticks: u64 = 0,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    switch (event) {
        .key => |k| {
            if (k.isChar('q') or event.isEscape() or event.isCtrlC()) {
                app.quit();
                return false;
            }
        },
        .tick => state.ticks +%= 1,
        else => {},
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var top = layout[0];
    top.header(.{ .title = "tui.zig", .subtitle = "Hello World", .right = "v" ++ tui.version }, top.area);

    var center = layout[1].margin(tui.Margin.symmetric(4, 2));
    try center.panel(.{ .title = "Welcome", .focused = true, .padding = tui.Padding.uniform(1) }, center.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            try p.paragraph(.{
                .raw = "Hello from native Zig terminal UI!",
                .wrap = .word,
                .alignment = .center,
            }, null);
            p.space(1);
            p.spinner(.{ .tick = st.ticks, .label = "Running event loop smoothly" }, null);
        }
    }.draw);

    var bottom = layout[2];
    bottom.statusBar(.{
        .left = &.{ .{ .text = "READY", .badge = true }, .{ .text = "Hello World Example" } },
        .right = &.{.{ .text = "q / Esc Quit" }},
    }, bottom.area);
}
```
