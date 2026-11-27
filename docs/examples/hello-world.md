---
title: Hello World & Quickstart
description: Self-contained quickstart showing App initialization, constraint layout, Panel, Spinner, StatusBar, and headless snapshot testing.
keywords: tui hello world, zig tui quickstart example, tui.init, tui.Ui
---

# Hello World & Quickstart

**Use case:** Starting any terminal application with managed raw mode, alternate screen, a 3-row header/body/footer layout, and clean terminal restoration on exit.

## Output Preview

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

## Complete Example

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

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    var app = try tui.init(alloc, .{
        .app = .{ .name = "Hello World", .version = tui.version },
        .io = init.io,
        .settings = .{ .fps = 12 },
    });
    defer app.deinit();

    var state = State{};
    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
```

## Key Takeaways

- `tui.init(alloc, ...)` binds one explicit allocator for buffers, scratch arena, and event parsing.
- `defer app.deinit()` guarantees terminal mode and alternate screen restoration even if an error is returned.
- `ui.rows` splits the frame into fixed (`length = 1`) chrome bars and a flexible (`fill = 1`) workspace.
