---
title: Custom & Stateful Widgets Examples
description: Client-side custom stateless widgets, custom stateful widgets, responsive custom UI architecture, and split-pane state orchestration.
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

- **`examples/custom_widget.zig`** (`custom-widget`): Stateless `MetricBadge` cards styled with OKLCH Color colors alongside stateful `StarRating` supporting both arrow-key and mouse-click rating updates.
- **`examples/custom_ui.zig`** (`custom-ui`): Full client-side UI composition blueprint combining responsive `ui.isCompact(...)` breakpoints, custom clickable `FilterPills`, `ServiceCard` components, live search input with hardware cursor, and layout-recorded mouse hitboxes.
- **`examples/custom_stateful_widget.zig`** (`custom-stateful-widget`): Reusable `TagPicker` stateful chip widget (`renderStateful`) paired with a direct-to-buffer `SparkMetricTile` widget (`fn render(self, buf: *tui.Buffer, area: tui.Rect)`), hardware cursor tracking (`ui.setCursor`), and automatic narrow-width chip wrapping.
- **`examples/animations_and_effects.zig`** (`animations-effects`): Demonstrates easing curves (`Tween`), critically damped `Spring` physics, animated drawer/popup `Transition`, loading `Skeleton` shimmer, `ToastState` auto-dismiss timers, and direct `tui.fx` cell effects.
- **`examples/custom_event_loop.zig`** (`custom-loop`): Shows how to bypass `App.run()` with a custom client-side loop calling `app.advanceTimer()`, non-blocking `app.pollEvent(0)`, background async work state, manual `app.draw()`, and `app.sleepFrame()`.
- **`examples/custom_fonts_and_i18n.zig`** (`custom-fonts-i18n`): Demonstrates client-defined `BitmapFont` glyphs (`★`, `Ω`, Arabic glyphs) with `BigText` raster modes and `.direction` support, `symbols.icons`, multi-script UTF-8 with single/double/curly underlines and reverse highlights, `RTL` reordering via `visualOrderInto`, `Locale` decimals, and RTL/LTR localized `Calendar` grids.
- **`examples/stateful_widgets.zig`** (`stateful-widgets`): Connects `SplitPane`, `TreeState`, and `ListState` using `Tab` and mouse focus switching with `defer state.deinit()`.
