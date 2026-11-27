---
title: Events, Mouse & Resize Examples
description: Live normalized event inspection, layout-derived mouse hitboxes, wheel events, and responsive layout breakpoints.
keywords: tui mouse events example, terminal resize responsive zig, tui Event inspector, hitboxes
---

# Events, Mouse & Resize Examples

```sh
zig build run-events
zig build run-mouse
zig build run-terminal-resize
```

## 1. Normalized Event Inspector (`examples/events.zig`)

Captures and formats `.key` (with `ctrl`/`alt`/`shift` modifiers and press/repeat/release kind), `.mouse`, `.resize`, `.paste`, and `.focus` events in real time:

```zig
switch (event) {
    .key => |k| {
        // Inspect k.code, k.modifiers.ctrl, k.modifiers.alt, k.kind
    },
    .mouse => |m| {
        // Inspect m.kind (.down, .up, .drag, .move, .scroll_up, .scroll_down), m.x, m.y
    },
    .resize => |sz| {
        // Inspect sz.width, sz.height
    },
    else => {},
}
```

## 2. Layout-Derived Mouse Hitboxes (`examples/mouse.zig`)

Record rendered `Rect` bounds during `render` and test `m.isInside(rect)` or `m.isLeftClickInside(rect)` in `onEvent` so hitboxes stay aligned across resizes:

```text
┌─ Zone A (Clicks: 3) ──────┐  ┌─ Wheel Meter ──────────────┐
│ Click or hover here       │  │ ████████████░░░░░░░  62%   │
└───────────────────────────┘  └────────────────────────────┘
```

## 3. Responsive Breakpoints (`examples/terminal_resize.zig`)

`ui.area.width` and `ui.isCompact(cols)` adapt automatically on `.resize` or `app.resizeTest(size)`:

- **`w < 50`**: stacked single-column layout
- **`50 <= w < 90`**: 2-column navigation + main pane
- **`w >= 90`**: 3-column sidebar + workspace + inspector

```zig
if (ui.isCompact(50)) {
    const stacked = ui.rows(3, .{ .{ .length = 4 }, .{ .fill = 1 }, .{ .length = 4 } }, .{});
    // Render compact vertical stack
} else if (ui.isCompact(90)) {
    const two_col = ui.cols(2, .{ .{ .length = 22 }, .{ .fill = 1 } }, .{});
    // Render 2-column layout
} else {
    const three_col = ui.cols(3, .{ .{ .length = 22 }, .{ .fill = 1 }, .{ .length = 26 } }, .{});
    // Render full 3-column layout
}
```
