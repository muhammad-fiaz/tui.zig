---
title: Charts, Gauges & Canvas Examples
description: Visualize metrics with XY Charts, Sparklines, BarCharts, sub-cell Gauges, Spinners, and vector Canvas grids.
keywords: tui charts example, zig braille canvas, Sparkline BarChart example, Gauge Spinner zig
---

# Charts, Gauges & Canvas Examples

```sh
zig build run-charts
zig build run-canvas
zig build run-gauge
zig build run-progress
zig build run-app-shell
```

## Procedural `Canvas` Painting (`examples/canvas.zig`)

```zig
const canvas = tui.Canvas{
    .x_bounds = .{ .min = 0, .max = 100 },
    .y_bounds = .{ .min = 0, .max = 100 },
    .marker = .braille,
    .shapes = &shapes,
    .block = .{ .title = "Vector Primitives", .focused = true },
};
try canvas.paintWith(&body, body.area, state.tick, struct {
    fn draw(tk: u64, painter: *tui.Painter) void {
        const phase = @as(f64, @floatFromInt(tk % 60)) * 0.1;
        painter.circle(50.0 + @cos(phase) * 20.0, 50.0 + @sin(phase) * 20.0, 6.0, .green);
        painter.text(44, 50, "Origin", .{ .foreground = .white, .bold = true });
    }
}.draw);
```

## App Shell Plots

- **`examples/charts.zig`** (`charts`): Multi-series `Chart`, interactive `PieChart` (press `p` to switch `.solid`, `.segmented`, `.hud`, and `.rose`), `Sparkline`, and horizontal `BarChart`.
- **`examples/app_shell.zig`** (`app-shell`): Pairs `Navbar`, Left (`LTR`) / Right (`RTL`) toggleable `Sidebar`, bottom `StatusBar`, `AppInfo` window title sync, donut `PieChart` with centered percentage label, filled `.area` + `.step` `Chart` datasets, gradient `Heatmap`, filterable `LogViewer`, `DiffViewer`, `Stepper`, `Pagination`, `Dropdown`, `KeyValueList`, and stacked `ToastManager(3)`.
