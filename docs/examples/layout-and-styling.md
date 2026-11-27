---
title: Layout, Borders & Styling Examples
description: Constraints, flex alignment, border collapsing, 17 themes, OKLCH color palettes, and continuous 24-bit color gradients.
keywords: tui layout example, border collapsing zig, OKLCH tui colors, runtime theme switcher
---

# Layout, Borders & Styling Examples

Explore constraint layouts, overlapping border collapsing, OKLCH color scales, text wrapping, and runtime theme switching:

```sh
zig build run-basic-layout
zig build run-styling
zig build run-colors
zig build run-borders
zig build run-paragraph
```

## 1. Constraint Splits & Flex (`examples/basic_layout.zig`)

Demonstrates `cols`, `rows`, fixed lengths, percentages, ratios, and `Flex` alignment modes (`start`, `center`, `end`, `space_between`, `space_around`):

```text
┌─ Top Fixed (3 rows) ─────────────────────────────────────────────────┐
└──────────────────────────────────────────────────────────────────────┘
┌─ Left (30%) ──────┐ ┌─ Center (Fill) ──────────┐ ┌─ Right (16 cols) ─┐
│                   │ │                          │ │                   │
└───────────────────┘ └──────────────────────────┘ └───────────────────┘
```

```zig
const cols = body.cols(3, .{
    .{ .percentage = 30 },
    .{ .fill = 1 },
    .{ .length = 16 },
}, .{ .spacing = .{ .space = 1 } });
```

## 2. Adjacent Border Collapsing (`examples/borders.zig`)

When adjacent blocks share a boundary column or row, `.merge_borders = .fuzzy` merges overlapping edges into box junctions (`┬`, `┴`, `├`, `┤`, `┼`):

```text
┌─ Left Pane ───────────────┬─ Right Pane ──────────────────┐
│                           │                               │
│ Shared center border      │ Collapsed into ┬ and ┴        │
│                           │                               │
└───────────────────────────┴───────────────────────────────┘
```

```zig
const mid = a.left() + a.width / 2;
const left_r = tui.Rect.init(a.left(), a.top(), (mid - a.left()) + 1, a.height);
const right_r = tui.Rect.init(mid, a.top(), a.right() - mid, a.height);
try p.block(.{ .title = "Left Pane", .border_type = .plain, .merge_borders = .fuzzy }, left_r);
try p.block(.{ .title = "Right Pane", .border_type = .plain, .merge_borders = .fuzzy }, right_r);
```

## 3. Runtime Theme Switching & Rich Text (`examples/styling.zig`)

Cycle through built-in themes (`dark`, `nord`, `catppuccin`, `tokyo_night`, `gruvbox`, `dracula`, `solarized`) while inspecting bold, italic, curly underline, strikethrough, and OSC 8 hyperlinks:

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

## 4. OKLCH Color Palettes & Gradients (`examples/colors.zig`)

Displays ANSI-16 swatches, compile-time OKLCH shade ramps (`tui.palette.sky.c50` .. `c950`), and continuous 24-bit gradients via `tui.palette.gradientColors`.

## 5. Multi-Span Wrapping & Scroll (`examples/paragraph.zig`)

Demonstrates mixed `Span` styles, CJK/emoji display widths, `.word` and `.char` wrapping, and vertical scroll offsets.
