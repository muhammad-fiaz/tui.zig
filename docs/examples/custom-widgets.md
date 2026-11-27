---
title: Custom & Stateful Widgets Examples
description: Client-side custom stateless widgets, custom stateful widgets, responsive custom UI architecture, animations, custom loops, and i18n.
keywords: tui.zig custom widgets example, zig custom ui, renderStateful example, renderWidget example
---

# Custom & Stateful Widgets Examples

```sh
zig build run-custom-widget
zig build run-custom-ui
zig build run-custom-stateful-widget
zig build run-animations-effects
zig build run-custom-loop
zig build run-custom-fonts-i18n
zig build run-stateful-widgets
```

## 1. Custom Stateless & Stateful Widgets (`examples/custom_widget.zig`, `examples/custom_stateful_widget.zig`)

Any Zig struct declaring `render` or `renderStateful` works directly with `ui.renderWidget` and `ui.renderStateful`:

```zig
const MetricBadge = struct {
    label: []const u8,
    value: []const u8,
    accent: tui.Color,

    pub fn render(self: MetricBadge, ui: *tui.Ui, area: tui.Rect) !void {
        try ui.block(.{ .title = self.label, .border_type = .rounded }, area);
        const inner = (tui.Block{ .border_type = .rounded }).inner(area);
        _ = ui.buffer.setStringClipped(inner.left(), inner.top(), self.value, inner.width, .{ .foreground = self.accent, .bold = true }, inner);
    }
};
```

## 2. Tree Expand/Collapse & SplitPanes (`examples/stateful_widgets.zig`)

Combines `SplitPane`, `Tree` (`expandAll` with `e`, `collapseAll` with `c`, node toggle with `Enter`/`Space`), and `List`:

```text
┌─ Module Tree ─────────────┐│┌─ Quick Actions ────────────┐
│ ▾ src                     │││> Inspect symbols            │
│   ▾ core                  │││  Run unit tests             │
│       buffer.zig          │││  Format module              │
│       layout.zig          │││  Generate docs              │
└───────────────────────────┘│└─────────────────────────────┘
```

## 3. Animations, Custom Event Loops & i18n

- **`examples/custom_ui.zig`** (`custom-ui`): Responsive breakpoints, clickable `FilterPills`, `ServiceCard` components, and live search filtering.
- **`examples/animations_and_effects.zig`** (`animations-effects`): `Tween` easing curves, `Spring` physics, `Transition` modals, `Skeleton` shimmers, `ToastState` timers, and `tui.fx` cell effects.
- **`examples/custom_event_loop.zig`** (`custom-loop`): Client-owned loop using `app.advanceTimer()`, non-blocking `app.pollEvent(0)`, manual `app.draw()`, and `app.sleepFrame()`.
- **`examples/custom_fonts_and_i18n.zig`** (`custom-fonts-i18n`): Client `BitmapFont` glyphs, `symbols.icons`, `RTL` reordering via `visualOrderInto`, client-owned `Locale` tables, and localized `Calendar` grids.
