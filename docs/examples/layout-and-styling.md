---
title: Layout, Borders & Styling Examples
description: Constraints, flex alignment, border collapsing, 17 themes, OKLCH Color palettes, and continuous 24-bit color gradients.
keywords: tui layout example, border collapsing zig, OKLCH tui colors, runtime theme switcher
---

# Layout, Borders & Styling Examples

Explore constraints, overlapping borders, OKLCH Color palettes, and runtime themes:

```sh
zig build run-basic-layout
zig build run-styling
zig build run-colors
zig build run-borders
zig build run-paragraph
```

## Adjacent Border Collapsing (`examples/borders.zig`)

When adjacent blocks share a boundary column or row, `.merge_borders = .fuzzy` combines overlapping edges into crisp box junctions (`┬`, `┴`, `├`, `┤`, `┼`):

```zig
const mid = a.left() + a.width / 2;
const left_r = tui.Rect.init(a.left(), a.top(), (mid - a.left()) + 1, a.height);
const right_r = tui.Rect.init(mid, a.top(), a.right() - mid, a.height);
try p.block(.{ .title = "Left Pane", .border_type = .plain, .merge_borders = .fuzzy }, left_r);
try p.block(.{ .title = "Right Pane", .border_type = .plain, .merge_borders = .fuzzy }, right_r);
```

## Runtime Theme Switching (`examples/styling.zig`)

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
app.setTheme(presets[idx]);
```
