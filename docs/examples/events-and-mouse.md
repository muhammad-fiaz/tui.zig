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

## Responsive Breakpoints (`examples/terminal_resize.zig`)

`ui.area.width` and `ui.isCompact(cols)` update live whenever `.resize` arrives or when `app.resizeTest(size)` simulates a smaller viewport:

- `w < 50`: stacked single-column view
- `50 <= w < 90`: 2-column navigation + main pane
- `w >= 90`: 3-column sidebar + workspace + inspector
