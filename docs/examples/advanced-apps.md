---
title: Multi-Pane Applications
description: Self-contained blueprints for responsive App Shells, LTR/RTL Sidebars, cascading DropdownMenus, LogViewer/DiffViewer, and embedded TerminalView.
keywords: tui dashboard zig, file browser tui, system monitor zig, interactive menu terminal, TerminalView
---

# Multi-Pane Applications

## 1. Responsive App Shell (`Navbar`, LTR/RTL `Sidebar`, `LogViewer`, `DiffViewer`, `Pagination`)

**Use case:** Production workspace shells with dockable left/right navigation, responsive narrow-terminal stacking, structured logs with per-source `EWIDT` filtering, unified diffs, and sliding-window pagination.

```text
 Workspace   Overview   Logs & Diff   Controls                             v0.1.0
┌─ Navigation ───────┐┌─ Lint ✓ ── Build ✓ ── Deploy ● ── Verify ○ ──────────────┐
│ > ◈ Overview     3 │├─ Cost Breakdown ─────────┬─ Area & Step Chart ──────────┤
│   ≡ Logs & Diff 12 ││   ▄▄▄    ■ Compute 54%   │ 100 ┤                 ⡠⠊     │
│   ⚙ Controls       ││  █100%█  ■ Storage 28%   │  50 ┤       ⡠⠒⠉⠉⠉⠒⠤⠊        │
│                    ││   ▀▀▀    ■ Network 18%   │   0 ┼─────────┬─────────┬─── │
└────────────────────┘└──────────────────────────┴──────────────────────────────┘
```

```zig
const sb = tui.Sidebar{
    .title = if (state.direction == .rtl) "القائمة" else "Navigation",
    .items = &.{
        .{ .label = "Overview", .icon = "◈", .badge = "3" },
        .{ .label = "Logs & Diff", .icon = "≡", .badge = "12" },
        .{ .label = "Controls", .icon = "⚙" },
    },
    .selected = state.route,
    .side = .auto, // docks left on .ltr, mirrors right on .rtl
    .direction = state.direction,
    .collapsed = state.sidebar_collapsed,
    .focused = state.focus_sidebar,
};

const split = sb.splitLayout(body_area);
try ui.region(split.sidebar).sidebar(sb, split.sidebar);

var content = ui.region(split.content);
try content.logViewer(.{ .entries = &log_data, .show_line_numbers = true }, &state.logs, log_rect);
try content.diffViewer(.{ .lines = &diff_data, .show_line_numbers = true }, &state.diff, diff_rect);
try content.pagination(.{ .total_pages = 12, .focused = true }, &state.page, pg_rect);
```

## 2. Cascading `DropdownMenu` with Checkmarks & Submenus

**Use case:** Desktop-style top menu bars with nested submenus (`children`), toggleable checkmarks (`checked`), keyboard shortcuts, and automatic screen-edge clamping.

```text
  File   Edit   View   Help
╭─────────────────────────╮
│ New Project      Ctrl+N │
│ Open Workspace   Ctrl+O │╭──────────────────────╮
│ Export As             ▸ ││ Plain Text (.txt)  1 │
│ ─────────────────────── ││ ANSI Color (.ans)  2 │
│ Quit             Ctrl+Q ││ JSON Snapshot      3 │
╰─────────────────────────╯╰──────────────────────╯
```

```zig
const export_formats = [_]tui.MenuItem{
    .{ .label = "Plain Text (.txt)", .id = "export.txt", .shortcut = "1" },
    .{ .label = "ANSI Color (.ans)", .id = "export.ans", .shortcut = "2" },
    .{ .label = "JSON Snapshot", .id = "export.json", .shortcut = "3" },
};
const file_actions = [_]tui.MenuItem{
    .{ .label = "New Project", .id = "file.new", .shortcut = "Ctrl+N" },
    .{ .label = "Export As", .children = &export_formats },
    .{ .label = "", .separator = true },
    .{ .label = "Quit", .id = "file.quit", .shortcut = "Ctrl+Q" },
};
const groups = [_]tui.MenuGroup{
    .{ .label = "File", .items = &file_actions },
};

try ui.dropdownMenu(.{ .groups = &groups }, &state.menu, bar_area, ui.area);
```

## 3. Embedded VT100 Screen (`TerminalView` & `VtScreen`)

**Use case:** Rendering ANSI-colored build logs, test runners, or virtual terminal panes inside any TUI layout with zero external CLI dependencies.

```zig
var screen = try tui.VtScreen.init(alloc, 80, 24);
defer screen.deinit();

screen.feed("\x1b[1;32mOK\x1b[0m build passed\r\n");
try ui.terminalView(.{ .screen = &screen, .block = .{ .title = "Output" } }, area);
```
