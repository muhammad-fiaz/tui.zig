---
title: Layout Engine & Constraints
description: Divide regions deterministically with Constraint types, zero-alloc fixed splits, flex spacing, margins, and automatic flow panes.
keywords: tui layout engine, zig constraints, splitFixed, rows cols tui, flex spacing border merge
---

# Layout Engine & Constraints

**tui.zig** provides **explicit zero-allocation splits** (`ui.rows`, `ui.cols`, `ui.splitFixed`), **responsive checks** (`ui.isCompact`, `ui.size`), and **automatic vertical flow panes** (`ui.allocateRows`, `ui.space`, `ui.paragraph(..., null)`).

## Supported `Constraint` Variants

| Variant | Behavior |
|---|---|
| `.{ .length = n }` | Exact fixed `n` cells |
| `.{ .percentage = p }` | `p%` of available axis size |
| `.{ .ratio = .{ .num = a, .den = b } }` | Fractional `a / b` share |
| `.{ .min = n }` | At least `n` cells |
| `.{ .max = n }` | At most `n` cells |
| `.{ .fill = weight }` | Distributes leftover cells proportionally after fixed/min constraints |

## Flex & Spacing Options

`LayoutOptions` customizes whitespace inside `rows`, `cols`, or `Layout.init`:

- `flex`: `.start`, `.center`, `.end`, `.space_between`, `.space_around`
- `spacing`: `.none`, `.{ .space = n }`, or `.{ .overlap = n }` (overlap by `1` allows clean shared-edge border collapsing)
- `margin` & `padding`: outer/inner rectangular insets

## Zero-Alloc Fixed Splits Example

```zig
const shell = ui.rows(3, .{
    .{ .length = 1 },  // Top Header
    .{ .fill = 1 },    // Responsive Body
    .{ .length = 1 },  // Bottom StatusBar
}, .{});

if (shell[1].isCompact(64)) {
    // Narrow terminal fallback
} else {
    const cols = shell[1].cols(2, .{
        .{ .length = 28 }, // Sidebar
        .{ .fill = 1 },    // Content
    }, .{ .margin = tui.Margin.uniform(1), .spacing = .{ .space = 1 } });
    _ = cols;
}
```

Need a runtime-length split without leaking? Call `try ui.splitScratch(constraints_slice, .{})` to allocate from the per-frame scratch arena.
