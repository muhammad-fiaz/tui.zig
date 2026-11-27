---
title: Complete Multi-Pane Applications
description: "Realistic application blueprints: multi-tab Dashboard, File Browser, System Monitor, App Shell, and Interactive Menu."
keywords: tui dashboard zig, file browser tui, system monitor zig, interactive menu terminal
---

# Complete Multi-Pane Applications

Examine `examples/app_shell.zig` and `examples/advanced/` for full multi-screen TUI patterns:

## 1. Responsive App Shell (`examples/app_shell.zig`)

```sh
zig build run-app-shell
```

```text
 Workspace   Overview   Logs & Diff   Controls                             v0.1.0
┌─ Navigation ───────┐┌─ Lint ✓ ── Build ✓ ── Deploy ● ── Verify ○ ──────────────┐
│ > ◈ Overview     3 │├─ Cost Breakdown ─────────┬─ Area & Step Chart ──────────┤
│   ≡ Logs & Diff 12 ││   ▄▄▄    ■ Compute 54%   │ 100 ┤                 ⡠⠊     │
│   ⚙ Controls       ││  █100%█  ■ Storage 28%   │  50 ┤       ⡠⠒⠉⠉⠉⠒⠤⠊        │
│                    ││   ▀▀▀    ■ Network 18%   │   0 ┼─────────┬─────────┬─── │
└────────────────────┘└──────────────────────────┴──────────────────────────────┘
```

- Combines `Navbar`, Left (`LTR`) / Right (`RTL`) dockable `Sidebar` (`d` toggles direction, `s` toggles dock, `c` collapses), `Stepper`, `PieChart`, `Chart`, `Heatmap`, `LogViewer` (with `h` `EWIDT` target matrix), `DiffViewer`, sliding-window `Pagination`, and `ToastManager`.

## 2. Cascading `DropdownMenu` (`examples/advanced/interactive_menu.zig`)

```sh
zig build run-interactive-menu
```

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

## 3. Embedded VT100 Screen (`TerminalView` & `VtScreen`)

Embed an ANSI/VT100 terminal buffer inside any split pane or panel with zero external CLI dependencies:

```zig
var screen = try tui.VtScreen.init(alloc, 80, 24);
defer screen.deinit();

screen.feed("\x1b[1;32mOK\x1b[0m build passed\r\n");
try ui.terminalView(.{ .screen = &screen, .block = .{ .title = "Output" } }, area);
```

## 4. Operations Apps (`examples/advanced/`)

- **`zig build run-dashboard`** (`examples/advanced/dashboard.zig`): Header + 3 `Tabs` (`Overview`, `Workloads`, `Telemetry`), `Chart`, `Sparkline`, `Table`, `BarChart`, `Gauge`, `Toast`, and live theme switcher (`t`).
- **`zig build run-file-browser`** (`examples/advanced/file_browser.zig`): Filter `TextInput` + collapsible `Tree` + `SplitPane` + `Breadcrumbs` + `Paragraph` file preview.
- **`zig build run-system-monitor`** (`examples/advanced/system_monitor.zig`): Real-time CPU `Gauge`, `LineGauge`, per-core `BarChart`, and process `Table`.
