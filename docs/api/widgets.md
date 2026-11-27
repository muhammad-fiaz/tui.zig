---
title: All Widgets & State Types API
description: Complete reference for every built-in widget, state struct, event handler, and flat Ui method in tui.zig.
keywords: tui.zig widgets, Block, Table, List, Tree, TextInput, TextArea, Calendar, CommandPalette, Chart, Canvas
---

# All Widgets & State Types

All widgets accept `.{}` defaults and expose `render(ui, area)` or `renderStateful(ui, area, state)`. Matching flat helpers live directly on `*tui.Ui`.

## Layout, Containers & Chrome

- **`Block`** (`ui.block`, `ui.panel`): `.title`, `.title_alignment`, `.title_bottom`, `.titles`, `.borders`, `.border_type`, `.custom_border_set`, `.focused`, `.padding`, `.merge_borders`, `.shadow`
- **`Clear` / `Fill` / `Spacer` / `Divider`** (`ui.clear`, `ui.fill`, `ui.divider`)
- **`Header`** (`ui.header`): `.title`, `.subtitle`, `.right`, `.style`
- **`Navbar`** (`ui.navbar`): `.brand`, `.items`, `.active`, `.right_text`, `.direction` (`.ltr`/`.rtl`), `Navbar.handleEvent`
- **`Sidebar`, `SidebarItem`, `SidebarSide`** (`ui.sidebar`): `.items`, `.selected`, `.title`, `.footer`, `.side` (`.left`, `.right`, `.auto`), `.direction`, `.width`, `.collapsed`, `.splitLayout`, `Sidebar.handleEvent`
- **`StatusBar`** (`ui.statusBar`): `.left: []const StatusSegment`, `.right: []const StatusSegment`, `.separator`
- **`MenuBar`** (`ui.menuBar`, `MenuBar.handleEvent`) & **`ContextMenu`** (`ui.contextMenu`, `ContextMenu.popupRect`, `ContextMenu.handleEvent` -> `ContextMenuOutcome`): anchored popup action lists with shortcuts, hover, and separators
- **`Breadcrumbs`** (`ui.breadcrumbs`): `.segments`, `.separator`
- **`ScrollView` & `ScrollViewState`** (`ui.scrollView`): combined viewport + proportional `Scrollbar`
- **`SplitPane`** (`ui.splitPane`): `.direction`, `.ratio_percent`, `.min_first`, `.show_divider`, and `SplitPane.handleEvent` for interactive mouse divider dragging
- **`Accordion`** (`ui.accordion`): expandable/collapsible header + callback body (`Accordion.handleEvent`)
- **`Badge`** (`ui.badge`): `.label`, `.variant` (`.accent`, `.neutral`, `.success`, `.warning`, `.danger`, `.info`)
- **`Skeleton`** (`ui.skeleton`): animated shimmer placeholder (`rows`, `phase`, `block`, `base_color`, `highlight_color`, `bar_glyph`)

## Text, Calendar & Collections

- **`Paragraph`** (`ui.paragraph`, `ui.text`): `.raw`, `.text`, `.block`, `.wrap`, `.truncation`, `.alignment`, `.scroll`, and `.tab_size` (expanding `\t` to aligned tab stops)
- **`Markdown`** (`ui.markdown`): formatted terminal Markdown with headings, lists, blockquotes, fenced code, and bold/code inline spans
- **`BigText`** (`ui.bigText`): Unicode banner renderer with `BitmapFont` (`.block_3x5`, `.sans_5x7`, custom `BitmapGlyph` / `lookup_fn` with mixed-height fallback measurement and Latin accent folding), `FontRenderMode` (`.full_block`, `.half_block`, `.quadrant`, `.braille`), `.direction` (`.ltr`, `.rtl`, `.auto`), `scale_x`, and `scale_y`
- **`Calendar`, `Date`, `CalendarEvent`, `CalendarState`** (`ui.calendar`): monthly schedule view, localized `.month_names` & `.weekday_names`, `.direction` (`.ltr`/`.rtl` column mirroring + localized header ordering), start-of-week choice, keyboard & wheel/click navigation (`handleEventAt`), and event highlights
- **`List` & `ListState`** (`ui.list`): `.raw_items` or `.items`, `.highlight_symbol`, `.highlight_spacing`, `.direction`
- **`Table`, `TableRow`, `TableCell`, `TableState`** (`ui.table`): `.header`, `.footer`, `.rows`, `.widths`, `.column_spacing`, `.striped_style`, `.show_header_separator`, `.empty_message`, and `Table.handleEvent`
- **`Tabs`** (`ui.tabs`): `.titles`, `.lines`, `.selected`, `.divider`, `Tabs.handleEvent`
- **`Stepper`, `StepItem`, `StepStatus`** (`ui.stepper`): horizontal/vertical pipeline status steps (`.completed`, `.active`, `.pending`, `.err`)
- **`Pagination`** (`ui.pagination`): interactive numbered page navigator with `handleEvent` (arrows & mouse clicks)
- **`LogViewer`, `LogEntry`, `LogLevel`, `LogViewerState`** (`ui.logViewer`): level-filtered structured log viewer with `.follow_tail` and scrolling
- **`DiffViewer`, `DiffLine`, `DiffKind`, `DiffViewerState`** (`ui.diffViewer`): unified added/removed/hunk diff viewer with old/new line numbers
- **`KeyValueList`, `KeyValueEntry`** (`ui.keyValueList`): aligned key/value summary inspector with custom value styling
- **`Tree`, `TreeNode`, `TreeState`** (`ui.tree`): immutable borrowed nodes + path-hashed `TreeState` (`init`, `deinit`, `expandAll`, `collapseAll`, `toggle`, `handleEvent`)
- **`Scrollbar` & `ScrollbarState`** (`ui.scrollbar`): vertical/horizontal proportional tracks, arrow caps, and `Scrollbar.handleEvent` (wheel & track click/drag)

## Forms & Controls

- **`Button`** (`ui.button`): `.label`, `.variant`, `.compact`, `.icon`, `.shortcut`, `.focused`, `.disabled`, `Button.isActivated`, `Button.handleEvent` (guards `.disabled`)
- **`Checkbox`** (`ui.checkbox`): `.label`, `.checked`, `.tristate`, `.symbols_set`, `Checkbox.handleEvent`
- **`Switch`** (`ui.switchToggle`): binary ON/OFF toggle pill (`Switch.handleEvent`)
- **`Slider` & `SliderState`** (`ui.slider`): continuous numeric slider with `.disabled`, `.precision`, `.unit`, step navigation, wheel adjustment, and label-aware track click/drag (`Slider.trackRect`, `Slider.handleEvent`)
- **`RadioGroup` & `RadioState`** (`ui.radio`): vertical/horizontal radio groups with optional `.wrap` row wrapping and `RadioGroup.handleEvent`
- **`Select` / `Dropdown` & `SelectState` / `DropdownState`** (`ui.select`): combobox with `.disabled`, type-ahead selection, above/below auto-flipped floating option menu (`Select.popupRect`, `SelectState.handleEventIn`)
- **`TextInput` & `TextInputState`** (`ui.textInput`): UTF-8 line editing, mouse click/drag selection, `.disabled`, tab/newline normalization, `Ctrl+Left/Right` word jumps, `Shift` selection highlights, `TextInput.search`, `TextInput.command`, `TextInput.secret`, `validateWithSchema`
- **`TextArea` & `TextAreaState`** (`ui.textArea`): multi-line editing, line numbers, `.read_only`, `.tab_size` expansion (`visualWidthWithTabs`), `selection_anchor`, `selectAll`, `selectedText`, `deleteSelection`, `Ctrl+A`/`U`/`K`, wheel & drag selection (`TextArea.handleEvent`), bracketed paste
- **`FocusGroup`**: `.count`, `.active`, `.next()`, `.prev()`, `.handleEvent(event)`

## Progress, Telemetry & Plots

- **`Gauge`**, **`LineGauge`**, **`ProgressBar`**, **`Spinner`** (`ui.gauge`, `ui.lineGauge`, `ui.progress`, `ui.spinner`)
- **`Sparkline`** (`ui.sparkline`), **`BarChart`** (`ui.barChart`)
- **`Chart`**, **`Dataset`**, **`Axis`**, **`LegendPosition`** (`ui.chart`): `.show_grid_lines`, `.scatter`, `.line`, `.area`, `.step`, and `.bar` datasets
- **`PieChart`, `PieSlice`, `PieStyle`, `PieLegendPosition`, `PieLegendLayout`** (`ui.pieChart`): `.solid`, `.segmented`, `.hud`, and `.rose` modes, `.donut_ratio`, `.center_label`, `.start_angle_deg`, `.gap`, `.explode`, `.pie_char`, `.marker`, `.legend_position`, `.legend_layout`, `.legend_alignment`, `.legend_marker`, and `.show_percentages`
- **`Heatmap`** (`ui.heatmap`): 2D numeric matrix with row/col headers, 3-stop gradient interpolation & scale legend
- **`Canvas`**, **`Painter`**, **`Shape`**, **`PixelGrid`**, **`Point`**, **`Bounds`** (`ui.canvas`): `line`, `dashedLine`, `rectangle`, `circle`, `polyline`, `polygon`, `text`
- **`TerminalView` & `VtScreen`** (`ui.terminalView`): pure-Zig VT100/ANSI screen buffer (`feed`, `resize`, `clear`, SGR colors/modifiers, cursor tracking) rendered inside an optional `Block`
- **`DropdownMenu`, `MenuState`, `MenuGroup`, `MenuItem`** (`ui.dropdownMenu`): horizontal menu bar with cascading nested submenus, checkmarks, shortcuts & mouse/keyboard navigation

## Modal Overlays & Productivity

- **`Popup`** (`ui.popup`): `.title`, `.footer_hint`, `.width`, `.height`, `.width_percent`, `.height_percent`, `.anchor`, `.dim_backdrop`, `.shadow`
- **`ConfirmDialog` & `ConfirmState`** (`ui.confirmDialog`): interactive `ConfirmOutcome` modal with optional `.backdrop_dismiss`, hover focus, keyboard, and button clicks (`handleEventAt`)
- **`CommandPalette` & `CommandPaletteState`** (`ui.commandPalette`): filterable command launcher modal with empty-filter guard, shortcuts, categories, mouse click, wheel, and backdrop dismissal (`handleEventAt`)
- **`Tooltip`** (`ui.tooltip`): contextual floating hint anchored next to a `Rect`
- **`Toast`, `ToastState` & `ToastManager(capacity)`** (`ui.toast`): overflow-clamped multi-line corner/center banners with `.info`, `.success`, `.warning`, `.err` accents, word wrapping, `Toast.computeRect`, and non-overlapping stacked managers

## Animations & Visual Effects (`tui.fx` / `tui.effects`)

- **`Easing`**: `.linear`, `.ease_in_quad`, `.ease_out_quad`, `.ease_in_out_quad`, `.ease_in_cubic`, `.ease_out_cubic`, `.ease_in_out_cubic`, `.ease_in_out_sine`, `.ease_out_back`, `.ease_out_bounce`
- **`Tween`** & **`LoopMode`**: bounded interpolation (`Tween.init`, `advance(dt_ms)`, `value()`, `progress()`, `reset()`, `restart()`, `retarget()`) with `.once`, `.loop`, and `.ping_pong` modes
- **`Spring`**: critically/under-damped spring physics (`Spring.init`, `setTarget()`, `snap()`, `step(dt_ms)`, `isSettled()`)
- **`Transition`**: open/close drawer & modal progress controller (`open()`, `close()`, `toggle()`, `update(dt_ms)`, `animatedRect(target, RevealOrigin)`)
- **Buffer Effects**: `fx.fade`, `fx.dimBackdrop`, `fx.dissolve`, `fx.sweepWipe`, `fx.shimmer`, `fx.pulseHighlight`, `fx.typewriterSlice`, `fx.marqueeSlice`
