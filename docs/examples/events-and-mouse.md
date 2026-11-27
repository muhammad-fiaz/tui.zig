---
title: Events, Mouse & Responsive Resize
description: Self-contained examples for normalized keyboard/mouse event handling, layout-derived hitboxes, and responsive terminal breakpoints.
keywords: tui mouse events example, terminal resize responsive zig, tui Event inspector, hitboxes
---

# Events, Mouse & Responsive Resize

## 1. Normalized Keyboard, Mouse & Resize Events

**Use case:** Handling cross-platform key modifiers, mouse clicks, wheel events, bracketed paste, and terminal resize signals uniformly.

```zig
fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    switch (event) {
        .key => |k| {
            if (k.kind == .release) return true;
            if (k.isChar('q') or event.isEscape() or event.isCtrlC()) {
                app.quit();
                return false;
            }
            if (k.modifiers.ctrl and k.isChar('s')) {
                state.saved_count += 1;
            }
        },
        .mouse => |m| {
            if (m.isLeftClickInside(state.button_rect)) {
                state.clicks += 1;
            } else if (m.isInside(state.meter_rect)) {
                if (m.kind == .scroll_up) state.level = @min(100, state.level + 5);
                if (m.kind == .scroll_down) state.level -|= 5;
            }
        },
        .resize => |sz| {
            state.last_width = sz.width;
            state.last_height = sz.height;
        },
        else => {},
    }
    return true;
}
```

## 2. Layout-Derived Mouse Hitboxes

**Use case:** Keeping clickable zones and wheel targets synchronized with dynamic split layouts across terminal resizes.

```text
┌─ Zone A (Clicks: 3) ──────┐  ┌─ Wheel Meter ──────────────┐
│ Click or hover here       │  │ ████████████░░░░░░░  62%   │
└───────────────────────────┘  └────────────────────────────┘
```

Record each child `Ui.area` during `render` into `State`, then test `m.isInside(rect)` or `m.isLeftClickInside(rect)` in `onEvent`.

## 3. Responsive Breakpoints (`ui.isCompact`)

**Use case:** Adapting 3-column desktop terminal layouts cleanly down to 2-column and stacked 1-column views on narrow splits or phones.

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
