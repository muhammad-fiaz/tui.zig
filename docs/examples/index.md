---
title: Examples Gallery
description: Browse all 38 runnable native Zig examples covering layouts, forms, tables, charts, RTL/LTR sidebars, navbars, log/diff viewers, custom fonts/i18n, animations, and full applications.
keywords: tui.zig examples, zig tui examples, custom widget example, dashboard zig, file browser zig
---

# Examples Gallery

Every example compiles standalone via `zig build examples`, runs deterministically with `--headless` via `zig build run-all-examples`, and launches interactively via `zig build run-<name>`.

## Interactive & Core Widget Examples

| Command | Source | Highlights |
|---|---|---|
| `zig build run-hello-world` | `examples/hello_world.zig` | Minimal `tui.init`, centered `Panel`, `Header`, `StatusBar`, `Spinner` |
| `zig build run-basic-layout` | `examples/basic_layout.zig` | `cols`, `rows`, fixed/percentage/fill constraints & dynamic `Flex` switching |
| `zig build run-styling` | `examples/styling.zig` | Bold, italic, curly underline, strikethrough & runtime theme switcher |
| `zig build run-colors` | `examples/colors.zig` | ANSI-16 strip, OKLCH Color swatches & continuous 24-bit gradient |
| `zig build run-borders` | `examples/borders.zig` | Rounded/Plain/Double/Thick presets + adjacent border collapsing |
| `zig build run-paragraph` | `examples/paragraph.zig` | Multi-span styling, CJK/emoji widths, word/char wrapping & scroll |
| `zig build run-text-input` | `examples/text_input.zig` | `TextInput`, multi-line `TextArea`, `FocusGroup`, hardware cursor & validation |
| `zig build run-buttons` | `examples/buttons.zig` | Button variants (`primary`, `success`, `danger`, `outline`), icons & click hitboxes |
| `zig build run-checkbox` | `examples/checkbox.zig` | Boolean checkboxes, click toggling + aggregated tri-state summary |
| `zig build run-radio` | `examples/radio.zig` | Vertical `RadioGroup` paired with floating `Select` dropdown |
| `zig build run-list` | `examples/list.zig` | Stateful scrollable `List` paired with synchronized `Scrollbar` |
| `zig build run-table` | `examples/table.zig` | Sticky header/footer, constraint columns, striping & cell selection |
| `zig build run-tabs` | `examples/tabs.zig` | Horizontal tab switcher paired with `Breadcrumbs` |
| `zig build run-progress` | `examples/progress.zig` | Determinate & indeterminate `ProgressBar` + spinner presets |
| `zig build run-gauge` | `examples/gauge.zig` | Fractional 1/8th-cell `Gauge` and compact `LineGauge` meters |
| `zig build run-scrollbar` | `examples/scrollbar.zig` | Scrollable `ScrollView` log viewer with mouse wheel & PgUp/PgDn |
| `zig build run-popup` | `examples/popup.zig` | Dimmed backdrop, centered `ConfirmDialog` & `Toast` notification |
| `zig build run-events` | `examples/events.zig` | Live normalized keyboard modifier, mouse, resize & paste inspector |
| `zig build run-mouse` | `examples/mouse.zig` | Interactive click zones, hover focus & wheel meter using layout hitboxes |
| `zig build run-custom-widget` | `examples/custom_widget.zig` | Custom stateless (`MetricBadge`) & stateful (`StarRating`) widgets |
| `zig build run-custom-ui` | `examples/custom_ui.zig` | Client-side custom UI architecture with responsive breakpoints & filter pills |
| `zig build run-custom-stateful-widget` | `examples/custom_stateful_widget.zig` | Custom stateful `TagPicker` + direct-to-buffer `SparkMetricTile` |
| `zig build run-animations-effects` | `examples/animations_and_effects.zig` | Easing `Tween`, `Spring` gauge, animated `Transition` modal, `Skeleton` shimmer loading & `fx` wipes/dissolves |
| `zig build run-custom-loop` | `examples/custom_event_loop.zig` | Explicit client-owned loop with non-blocking `pollEvent(0)`, `advanceTimer()`, async job state & manual `draw()` |
| `zig build run-stateful-widgets` | `examples/stateful_widgets.zig` | Split-pane collapsible `Tree` + synchronized `List` |
| `zig build run-charts` | `examples/charts.zig` | Multi-series `Chart`, `PieChart` styles (`.solid`/`.segmented`/`.hud`/`.rose`), `Sparkline` & `BarChart` |
| `zig build run-canvas` | `examples/canvas.zig` | Vector circles, lines & rects across Braille, HalfBlock & Quadrant grids |
| `zig build run-terminal-resize` | `examples/terminal_resize.zig` | Responsive breakpoints collapsing from 3 columns -> 2 -> 1 |
| `zig build run-calendar` | `examples/calendar.zig` | Responsive monthly `Calendar` grid, date navigation & event highlights |
| `zig build run-controls` | `examples/controls.zig` | `Switch` toggle, `Slider` range control, `Accordion` & `Badge` |
| `zig build run-markdown-palette` | `examples/markdown_and_palette.zig` | `BigText` banner, scrollable `Markdown`, `Tooltip` & `CommandPalette` modal |
| `zig build run-inline-viewport` | `examples/inline_viewport.zig` | `.inline_height` viewport appending scrollback lines via `insertBefore` |
| `zig build run-app-shell` | `examples/app_shell.zig` | `Navbar`, Left (`LTR`) / Right (`RTL`) `Sidebar`, `StatusBar`, `PieChart`, `.area`/`.step` `Chart`, `Heatmap`, `LogViewer`, `DiffViewer`, `Stepper`, `Pagination`, `Dropdown`, `KeyValueList` & `ToastManager` |
| `zig build run-custom-fonts-i18n` | `examples/custom_fonts_and_i18n.zig` | Client `BitmapFont` glyphs, `FontRenderMode`, `symbols.icons`, `Locale` decimals, RTL ordering & localized `Calendar` |

## Complete Multi-Pane Applications

| Command | Source | Description |
|---|---|---|
| `zig build run-dashboard` | `examples/advanced/dashboard.zig` | Multi-tab operations dashboard with charts, table, workloads, gauge & toast |
| `zig build run-file-browser` | `examples/advanced/file_browser.zig` | Split-pane file tree explorer, filter bar, breadcrumbs & preview |
| `zig build run-system-monitor` | `examples/advanced/system_monitor.zig` | Live system CPU gauges, per-core bar chart & process table |
| `zig build run-interactive-menu` | `examples/advanced/interactive_menu.zig` | Application `MenuBar`, aligned `ContextMenu` & `ConfirmDialog` exit guard |
