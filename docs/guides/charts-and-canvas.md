---
title: Charts, Sparklines & Canvas
description: Visualize metrics with Sparkline, BarChart, multi-series XY Chart, and Braille/HalfBlock/Quadrant Canvas vector drawing.
keywords: tui chart, sparkline zig, barchart terminal, braille canvas, Painter polygon dashedLine
---

# Charts, Sparklines & Canvas

Build high-density telemetry dashboards using four visualization widgets backed by per-frame scratch buffers.

## `Sparkline` & `BarChart`

- `Sparkline`: compact 9-level vertical block trends (`▁▂▃▄▅▆▇█`) supporting nullable gaps (`data: []const ?u64`) and left-to-right or right-to-left growth.
- `BarChart`: grouped vertical or horizontal categorical bars (`Bar`, `BarGroup`) with automatic value scaling and custom labels.

## Multi-Series XY `Chart`

Combine `.scatter`, `.line`, `.area`, `.step`, and `.bar` datasets with optional `.show_grid_lines = true`, custom `Axis` bounds, labels, and automatic corner legends:

```zig
const pts = [_]tui.Point{
    .{ .x = 0, .y = 12 },
    .{ .x = 50, .y = 78 },
    .{ .x = 100, .y = 64 },
};
try ui.chart(.{
    .datasets = &.{
        .{ .name = "Throughput", .data = &pts, .style = .{ .foreground = tui.palette.sky.c400 }, .marker = .braille },
    },
    .x_axis = .{ .title = "Seconds", .labels = &.{ "0", "50", "100" } },
    .y_axis = .{ .title = "MB/s", .labels = &.{ "0", "50", "100" } },
    .show_grid_lines = true,
    .block = .{ .title = "Traffic", .border_type = .rounded },
}, chart_area);
```

## Sub-Cell Vector `Canvas`

`Canvas` and `Painter` render world-space lines, dashed lines, rectangles, circles, polygons, points, polylines, and labels over four marker grids:

| Marker | Sub-Cell Resolution | Best For |
|---|---|---|
| `.braille` | 2�, 4 dots per cell | Smooth plots, waveforms, vector shapes |
| `.half_block` | 1�, 2 dual-color pixels | Density maps, two-tone bars |
| `.quadrant` | 2�, 2 blocks | Sharp geometric fills |
| `.dot` / `.block` | 1�, 1 | Bold low-res plots or ASCII compatibility |

## `PieChart` & `Heatmap`

- **`PieChart`, `PieStyle`, `PieLegendPosition`, `PieLegendLayout`** (`ui.pieChart`): Renders circular solid pies (`donut_ratio = 0`), hollow donuts (`donut_ratio = 0.5`), segmented rings (`.segmented`), dial instruments (`.hud`), and polar-area charts (`.rose`) with true 1:2 cell aspect compensation, `.half_block`/`.braille`/`.quadrant` or custom `.pie_char` glyphs, `gap`, `explode`, `start_angle_deg`, `center_label`, and configurable `.legend_position` (`.right`, `.left`, `.top`, `.bottom`, `.none`), `.legend_layout` (`.vertical`, `.horizontal`), `.legend_alignment`, `.legend_marker`, and percentages.
- **`Heatmap`** (`ui.heatmap`): Renders 2D numeric matrices (`rows`, `cols`, `values`) with row/column headers, configurable cell width, smooth 3-stop gradient interpolation (`low_color`, `mid_color`, `high_color`), inline values, and a min-to-max gradient legend.
