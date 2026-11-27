---
title: Charts, Gauges & Canvas
description: Self-contained examples for XY Charts, PieCharts, Sparklines, BarCharts, sub-cell Gauges, and vector Canvas grids.
keywords: tui charts example, zig braille canvas, Sparkline BarChart example, Gauge Spinner zig, PieChart
---

# Charts, Gauges & Canvas

## 1. XY `Chart`, `PieChart`, `Sparkline` & `BarChart`

**Use case:** Telemetry dashboards displaying throughput curves, donut/pie resource shares, compact sparklines, and regional bar comparisons.

```text
╭─ Network Throughput ─────────────╮ ╭─ Traffic Share ─────────────╮
│ 100 ┤                       ⡠⠊  │ │   ▄▄███▄▄     ■ API 46%     │
│  50 ┤             ⡠⠒⠊⠉⠑⠒⠤⠊⠁     │ │  ██▀   ▀██    ■ Worker 31%  │
│   0 ┼──────┬──────┬──────┬────── │ │  ██▄ 100%██   ■ Cache 23%   │
│     0            50          100 │ │   ▀▀███▀▀                   │
╰──────────────────────────────────╯ ╰─────────────────────────────╯
```

```zig
const pts = [_]tui.Point{
    .{ .x = 0, .y = 18 },
    .{ .x = 50, .y = 64 },
    .{ .x = 100, .y = 92 },
};

try chart_ui.chart(.{
    .datasets = &.{
        .{ .name = "Throughput", .data = &pts, .graph_type = .area, .style = .{ .foreground = tui.palette.sky.c400 } },
    },
    .x_axis = .{ .title = "Time (s)", .labels = &.{ "0", "50", "100" } },
    .y_axis = .{ .title = "MB/s", .labels = &.{ "0", "50", "100" } },
    .block = .{ .title = "Network Throughput", .border_type = .rounded },
}, chart_ui.area);

try pie_ui.pieChart(.{
    .slices = &.{
        .{ .label = "API", .value = 46, .color = tui.palette.sky.c400 },
        .{ .label = "Worker", .value = 31, .color = tui.palette.emerald.c400 },
        .{ .label = "Cache", .value = 23, .color = tui.palette.amber.c400 },
    },
    .pie_style = .solid, // or .segmented, .hud, .rose
    .donut_ratio = 0.45,
    .center_label = "100%",
    .block = .{ .title = "Traffic Share", .border_type = .rounded },
}, pie_ui.area);
```

## 2. Procedural `Canvas` Painting

**Use case:** Custom vector graphics, waveforms, and orbital animations using Braille, HalfBlock, or Quadrant sub-cell resolution.

```zig
const canvas = tui.Canvas{
    .x_bounds = .{ .min = 0, .max = 100 },
    .y_bounds = .{ .min = 0, .max = 100 },
    .marker = .braille,
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

## 3. `Gauge`, `LineGauge` & `BarChart`

**Use case:** Capacity meters and horizontal category comparisons.

```zig
try ui.gauge(.{ .ratio = 0.72, .label = "CPU 72%", .block = .{ .title = "Usage" } }, gauge_area);
try ui.barChart(.{
    .bars = &.{ tui.Bar.init("US", 78), tui.Bar.init("EU", 54), tui.Bar.init("AP", 42) },
    .direction = .horizontal,
    .block = .{ .title = "Regional Traffic" },
}, bar_area);
```
