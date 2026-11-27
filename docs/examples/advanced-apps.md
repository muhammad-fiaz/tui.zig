---
title: Complete Multi-Pane Applications
description: "Realistic application blueprints: multi-tab Dashboard, File Browser, System Monitor, and Interactive Menu."
keywords: tui dashboard zig, file browser tui, system monitor zig, interactive menu terminal
---

# Complete Multi-Pane Applications

Examine `examples/advanced/` for complete multi-screen TUI patterns:

- **`zig build run-app-shell`** (`examples/app_shell.zig`): Full client shell featuring `Navbar`, dockable `Sidebar` supporting both Left (`LTR`) and Right (`RTL`) edges + collapsed mode, bottom `StatusBar`, live `app.setTitle` / `AppInfo`, `Stepper`, `PieChart`, `Chart`, `Heatmap`, `LogViewer`, `DiffViewer`, forms, and `ToastManager`.
- **`zig build run-dashboard`** (`examples/advanced/dashboard.zig`): Header + 3 functional `Tabs` (`Overview`, `Workloads`, `Telemetry`) + Chart + Sparkline + Table + BarChart + Capacity Gauge + Toast notifications + live theme cycler (`t`).
- **`zig build run-file-browser`** (`examples/advanced/file_browser.zig`): Filter `TextInput` (`🔍 `) + collapsible `Tree` + `SplitPane` + `Breadcrumbs` + dynamic `Paragraph` file preview.
- **`zig build run-system-monitor`** (`examples/advanced/system_monitor.zig`): Real-time host telemetry combining animated `Gauge`, `LineGauge`, `BarChart`, and process `Table`.
- **`zig build run-interactive-menu`** (`examples/advanced/interactive_menu.zig`): Top `MenuBar`, anchored `ContextMenu` with separator skipping and shortcuts, and `ConfirmDialog` exit guard.
