---
title: Lists, Tables, Tabs & Popups Examples
description: Scrollable collections, structured tables with sticky headers/footers, tabs, calendar grids, command palettes, scroll views, and modal popups.
keywords: tui list table example, Calendar CommandPalette example, Popup ConfirmDialog zig, ScrollView
---

# Lists, Tables, Tabs & Popups Examples

```sh
zig build run-list
zig build run-table
zig build run-tabs
zig build run-scrollbar
zig build run-popup
zig build run-calendar
zig build run-markdown-palette
zig build run-inline-viewport
```

## 1. Striped Data Table (`examples/table.zig`)

Renders a scrollable `Table` with sticky header and footer rows, constraint-sized columns, alternating row striping, and active cell highlighting:

```text
┌─ Cluster Services ───────────────────────────────────────────────────┐
│ Service            Status      CPU      Memory     Uptime            │
│ ──────────────────────────────────────────────────────────────────── │
│ api-gateway        Healthy     18.2%    240 MB     99.98%            │
│>auth-worker        Healthy     12.4%    164 MB     99.95%            │
│ ──────────────────────────────────────────────────────────────────── │
│ Total: 6           4 Healthy   65.9%    982 MB     avg 98.9%         │
└──────────────────────────────────────────────────────────────────────┘
```

```zig
try body.table(.{
    .header = tui.TableRow.fromStrings(&.{ "Service", "Status", "CPU", "Memory", "Uptime" }),
    .footer = tui.TableRow.fromStrings(&.{ "Total: 6", "4 Healthy", "65.9%", "982 MB", "avg 98.9%" }),
    .rows = &table_rows,
    .widths = &.{ .{ .length = 18 }, .{ .length = 11 }, .{ .length = 8 }, .{ .length = 10 }, .{ .fill = 1 } },
    .block = .{ .title = "Cluster Services", .focused = true },
    .show_header_separator = true,
    .striped_style = .{ .dim = true },
    .column_highlight_style = .{ .underline = true },
}, &state.table, body.area);
```

## 2. Lists, Tabs, ScrollViews & Inline Viewports

- **`examples/list.zig`** (`list`): Stateful scrollable `List` synchronized with a proportional `Scrollbar`.
- **`examples/tabs.zig`** (`tabs`): Keyboard/mouse `Tabs` switcher paired with `Breadcrumbs`.
- **`examples/scrollbar.zig`** (`scrollbar`): `ScrollView` wrapping long log content with mouse wheel and `PgUp`/`PgDn` scrolling.
- **`examples/inline_viewport.zig`** (`inline-viewport`): `.inline_height` viewport appending scrollback history above the active UI via `app.insertBefore(...)`.

## 3. Calendar, Markdown, CommandPalette & Popups

- **`examples/calendar.zig`** (`calendar`): Responsive monthly `Calendar` grid with date navigation, `PgUp`/`PgDn` month paging, Monday/Sunday first-day toggle (`m`), and event highlights.
- **`examples/markdown_and_palette.zig`** (`markdown-palette`): `BigText` banner, scrollable `Markdown`, `Tooltip`, and fuzzy-filtered `CommandPalette` (`app.commandPalette()`).
- **`examples/popup.zig`** (`popup`): Dimmed backdrop, centered `ConfirmDialog` modal, and corner `Toast` notification.
