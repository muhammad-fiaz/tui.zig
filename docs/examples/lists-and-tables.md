---
title: Lists, Tables, Tabs & Popups
description: Self-contained examples for striped Tables, ScrollView + Scrollbar, Tabs + Breadcrumbs, Calendar, CommandPalette, and ConfirmDialog + Toast.
keywords: tui list table example, Calendar CommandPalette example, Popup ConfirmDialog zig, ScrollView
---

# Lists, Tables, Tabs & Popups

## 1. Striped Data `Table` with Sticky Header & Footer

**Use case:** Service monitors, inventory tables, and metric grids with fixed summary rows and active row/column selection.

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
const rows = [_]tui.TableRow{
    tui.TableRow.fromStrings(&.{ "api-gateway", "Healthy", "18.2%", "240 MB", "99.98%" }),
    tui.TableRow.fromStrings(&.{ "auth-worker", "Healthy", "12.4%", "164 MB", "99.95%" }),
};

try ui.table(.{
    .header = tui.TableRow.fromStrings(&.{ "Service", "Status", "CPU", "Memory", "Uptime" }),
    .footer = tui.TableRow.fromStrings(&.{ "Total: 2", "2 Healthy", "30.6%", "404 MB", "avg 99.9%" }),
    .rows = &rows,
    .widths = &.{ .{ .length = 18 }, .{ .length = 11 }, .{ .length = 8 }, .{ .length = 10 }, .{ .fill = 1 } },
    .block = .{ .title = "Cluster Services", .focused = true },
    .show_header_separator = true,
    .striped_style = .{ .dim = true },
    .column_highlight_style = .{ .underline = true },
}, &state.table, area);
```

## 2. `ConfirmDialog` Modal & `Toast` Banner

**Use case:** Destructive-action confirmation overlays with dimmed backdrops and auto-expiring status notifications.

```zig
const dialog = tui.ConfirmDialog{
    .title = "Deploy Release",
    .message = "Roll out build v0.1.0 to production?",
    .confirm_label = "Deploy",
    .cancel_label = "Cancel",
    .backdrop_dismiss = true,
};

if (state.confirm.open) {
    try ui.confirmDialog(dialog, &state.confirm, null);
}
try state.toasts.render(ui, ui.area);
```

## 3. `Calendar` Grid & `CommandPalette`

**Use case:** Date pickers with event highlights and fuzzy-filtered quick-action launchers (`Ctrl+K` / `p`).

```zig
try ui.calendar(.{
    .events = &.{
        .{ .date = tui.Date.init(2026, 11, 27), .style = ui.theme.accent },
    },
    .first_weekday = .monday,
    .block = .{ .title = "Release Schedule", .focused = true },
}, &state.cal, cal_area);

if (state.palette.open) {
    try ui.commandPalette(.{ .commands = &commands }, &state.palette, null);
}
```
