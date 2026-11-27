---
title: Widgets Overview
description: Survey all 40+ built-in widgets in tui.zig, comparing flat Ui helpers and standalone composable structs.
keywords: tui.zig widgets, zig ui widgets, Switch, Slider, Accordion, Calendar, PieChart, Heatmap, LogViewer, DiffViewer, TerminalView, DropdownMenu
---

# Widgets Overview

**tui.zig** includes 40+ reusable widgets across containers, text, forms, collections, charts, application chrome, media rendering, and overlays. Every built-in widget supports both **flat `Ui` calls** and **struct-based rendering**.

## Container & Utility Widgets

| Widget | `Ui` Method | Purpose |
|---|---|---|
| `Block` | `ui.block` / `ui.panel` | Rounded, plain, double, thick, dashed, or quadrant borders, collapsing edges, shadows, titles |
| `Clear` / `Fill` | `ui.clear` / `ui.fill` | Reset cells or fill solid surface colors |
| `Divider` | `ui.divider` | Horizontal or vertical hairline with optional label |
| `SplitPane` | `ui.splitPane` | Two-pane split with optional divider |
| `ScrollView` | `ui.scrollView` | Bordered viewport paired with proportional `Scrollbar` |
| `Accordion` | `ui.accordion` | Collapsible header with nested child body callback |
| `Badge` | `ui.badge` | Compact semantic status pill |
| `Skeleton` | `ui.skeleton` | Shimmering loading placeholder (`rows`, `phase`) |

## Text & Form Controls

| Widget | State Type | `Ui` Method |
|---|---|---|
| `Paragraph` | Stateless | `ui.paragraph` / `ui.text` |
| `Markdown` | Stateless | `ui.markdown` |
| `BigText` | Stateless | `ui.bigText` |
| `Button` | Stateless | `ui.button` |
| `Checkbox` | `bool` / `CheckState` | `ui.checkbox` |
| `Switch` | `bool` | `ui.switchToggle` |
| `Slider` | `SliderState` | `ui.slider` |
| `RadioGroup` | `RadioState` | `ui.radio` |
| `TextInput` | `TextInputState` | `ui.textInput` |
| `TextArea` | `TextAreaState` | `ui.textArea` |
| `Select` / `Dropdown` | `SelectState` / `DropdownState` | `ui.select` |

## Navigation, Collections, Charts & Overlays

| Category | Widgets |
|---|---|
| Navigation & Shell | `Header`, `Navbar`, `Sidebar` (Left/Right & RTL/LTR), `MenuBar`, `DropdownMenu` (`MenuState`), `ContextMenu`, `Breadcrumbs`, `Tabs`, `Stepper`, `Pagination`, `StatusBar`, `FocusGroup` |
| Collections, Logs & Terminal | `List` (`ListState`), `Table` (`TableState`), `Tree` (`TreeState`), `LogViewer` (`LogViewerState` + `EWIDT` target filter), `DiffViewer` (`DiffViewerState`), `TerminalView` (`VtScreen`), `KeyValueList`, `Scrollbar` (`ScrollbarState`), `Calendar` (`CalendarState`) |
| Indicators & Plots | `Gauge`, `LineGauge`, `ProgressBar`, `Spinner`, `Sparkline`, `BarChart`, `Chart`, `PieChart`, `Heatmap`, `Canvas` |
| Overlays | `Popup`, `ConfirmDialog`, `CommandPalette`, `Tooltip`, `Toast` (`ToastState`, `ToastManager`) |
| Animations & Effects | `Tween`, `Spring`, `Easing`, `Transition`, `tui.fx` (`fade`, `dimBackdrop`, `dissolve`, `sweepWipe`, `shimmer`, `pulseHighlight`, `typewriterSlice`, `marqueeSlice`) |

## Choosing Flat Helpers vs Widget Structs

```zig
// Option 1: Flat automatic flow inside a panel
try ui.button(.{ .label = "Deploy", .focused = true }, null);

// Option 2: Standalone widget struct targeting an explicit Rect
const btn = tui.Button{ .label = "Deploy", .focused = true };
try ui.renderWidget(btn, button_rect);
```
