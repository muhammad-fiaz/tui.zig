---
title: Hello World Example
description: Annotated walkthrough of examples/hello_world.zig showing App initialization, layout, panel, and headless testing.
keywords: tui hello world, zig tui quickstart example, tui.init, tui.Ui
---

# Hello World & Quickstart

Run interactively or in headless mode:

```sh
zig build run-hello-world
zig build run-hello-world -- --headless
```

## Expected Terminal Output

```text
tui.zig  Hello World                                                      v0.1.0

    ┌─ Welcome ────────────────────────────────────────────────────────────┐
    │                                                                      │
    │                  Hello from native Zig terminal UI!                  │
    │                                                                      │
    │  ⠋ Running event loop smoothly                                       │
    │                                                                      │
    └──────────────────────────────────────────────────────────────────────┘

 READY   Hello World Example                                        q / Esc Quit
```

## How It Works

- **`tui.init`**: Binds a single `std.mem.Allocator` and selects `.auto` (native Win32/POSIX) or `.memory` when `--headless` is passed.
- **`defer app.deinit()`**: Restores terminal mode, alternate screen, and mouse tracking even on early return.
- **`Ui.rows` & `panel`**: Splits the viewport into a 1-row `Header`, a filling body `Panel` with symmetric margin, and a 1-row `StatusBar`.

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
