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

## Striped Data Table (`examples/table.zig`)

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

## Confirmation Modals & Toasts (`examples/popup.zig`)

Render overlays last on the root `Ui` so backdrop dimming, shadowed rounded borders, buttons, and corner toasts paint cleanly over any background layout.
