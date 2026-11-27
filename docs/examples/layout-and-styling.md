---
title: Layout, Borders & Styling
description: Self-contained examples for constraint splits, adjacent border collapsing, runtime theme switching, OKLCH palettes, and text wrapping.
keywords: tui layout example, border collapsing zig, OKLCH tui colors, runtime theme switcher
---

# Layout, Borders & Styling

## 1. Constraint Splits & Collapsed Borders

**Use case:** Multi-pane IDE or dashboard grids where adjacent boxes share a border without doubling line thickness.

```text
┌─ Top Fixed (3 rows) ─────────────────────────────────────────────────┐
└──────────────────────────────────────────────────────────────────────┘
┌─ Left Pane ───────────────┬─ Right Pane ─────────────────────────────┐
│ 35% width                 │ Remaining fill width                     │
│ Shared border merges cleanly into ┬ and ┴                            │
└───────────────────────────┴──────────────────────────────────────────┘
```

```zig
fn renderLayout(ui: *tui.Ui) !void {
    const rows = ui.rows(2, .{ .{ .length = 3 }, .{ .fill = 1 } }, .{});
    try ui.block(.{ .title = "Top Fixed (3 rows)", .border_type = .plain }, rows[0].area);

    const a = rows[1].area;
    const mid = a.left() + (a.width * 35) / 100;
    const left_r = tui.Rect.init(a.left(), a.top(), (mid - a.left()) + 1, a.height);
    const right_r = tui.Rect.init(mid, a.top(), a.right() - mid, a.height);

    try ui.block(.{ .title = "Left Pane", .border_type = .plain, .merge_borders = .fuzzy }, left_r);
    try ui.block(.{ .title = "Right Pane", .border_type = .plain, .merge_borders = .fuzzy }, right_r);
}
```

## 2. Runtime Theme Switching & Rich Text

**Use case:** User-selectable color themes paired with semantic underlines, bold/italic attributes, and OSC 8 clickable links.

```zig
const presets = [_]tui.Theme{
    tui.Theme.dark,
    tui.Theme.nord,
    tui.Theme.catppuccin,
    tui.Theme.tokyo_night,
    tui.Theme.gruvbox,
    tui.Theme.dracula,
    tui.Theme.solarized,
};

// Inside onEvent:
if (event.isChar('t')) {
    state.theme_idx = (state.theme_idx + 1) % presets.len;
    app.setTheme(presets[state.theme_idx]);
}

// Inside render:
const spans = [_]tui.Span{
    tui.Span.styled("Warning", ui.theme.warning.withUnderlineStyle(.curly)),
    tui.Span.raw("  "),
    tui.Span.link("Docs", "https://muhammad-fiaz.github.io/tui.zig/"),
};
const lines = [_]tui.Line{tui.Line.fromSpans(&spans)};
try ui.paragraph(.{ .text = tui.Text.fromLines(&lines), .wrap = .word }, area);
```

## 3. OKLCH Color Palettes & Continuous Gradients

**Use case:** Heat strips, status badges, and smooth 24-bit color ramps that automatically downgrade on ANSI-256 or ANSI-16 terminals.

```zig
var ramp: [16]tui.Color = undefined;
tui.palette.gradientColors(&ramp, &.{ tui.palette.sky.c400, tui.palette.emerald.c400 });

for (ramp, 0..) |c, i| {
    _ = ui.buffer.setStringClipped(area.left() + @as(u16, @intCast(i)), area.top(), "█", 1, .{ .foreground = c }, area);
}
```
