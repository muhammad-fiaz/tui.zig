---
title: Charts, Gauges & Canvas Examples
description: Visualize metrics with XY Charts, PieCharts, Sparklines, BarCharts, sub-cell Gauges, Spinners, and vector Canvas grids.
keywords: tui charts example, zig braille canvas, Sparkline BarChart example, Gauge Spinner zig, PieChart
---

# Charts, Gauges & Canvas Examples

```sh
zig build run-charts
zig build run-canvas
zig build run-gauge
zig build run-progress
zig build run-app-shell
```

## 1. XY Charts, PieCharts, Sparklines & BarCharts (`examples/charts.zig`)

Pairs multi-series XY `Chart` plots, interactive `PieChart` presets (press `p` to cycle `.solid`, `.segmented`, `.hud`, and `.rose`), `Sparkline`, and horizontal `BarChart`:

```text
╭─ Network Throughput ─────────────╮ ╭─ Traffic Share ─────────────╮
│ 100 ┤                       ⡠⠊  │ │   ▄▄███▄▄     ■ API 46%     │
│  50 ┤             ⡠⠒⠊⠉⠑⠒⠤⠊⠁     │ │  ██▀   ▀██    ■ Worker 31%  │
│   0 ┼──────┬──────┬──────┬────── │ │  ██▄ 100%██   ■ Cache 23%   │
│     0            50          100 │ │   ▀▀███▀▀                   │
╰──────────────────────────────────╯ ╰─────────────────────────────╯
```

```zig
try pie_ui.pieChart(.{
    .slices = &.{
        .{ .label = "API", .value = 46, .color = tui.palette.sky.c400 },
        .{ .label = "Worker", .value = 31, .color = tui.palette.emerald.c400 },
        .{ .label = "Cache", .value = 23, .color = tui.palette.amber.c400 },
    },
    .pie_style = .solid,
    .donut_ratio = 0.45,
    .center_label = "100%",
    .block = .{ .title = "Traffic Share", .border_type = .rounded },
}, pie_ui.area);
```

## 2. Procedural `Canvas` Painting (`examples/canvas.zig`)

Draw vector circles, lines, rectangles, polygons, and text labels on Braille, HalfBlock, or Quadrant sub-cell grids:

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

## 3. Gauges & Progress (`examples/gauge.zig`, `examples/progress.zig`)

- **`Gauge` & `LineGauge`**: 1/8th-cell fractional block meters with custom label styles.
- **`ProgressBar` & `Spinner`**: Determinate/indeterminate progress bars paired with animated frame spinners.
