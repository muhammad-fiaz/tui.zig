---
title: Custom & Stateful Widgets
description: Self-contained examples for custom stateless/stateful widgets, Tree expand/collapse, animations, custom event loops, and client-owned Locale i18n.
keywords: tui.zig custom widgets example, zig custom ui, renderStateful example, renderWidget example
---

# Custom & Stateful Widgets

## 1. Custom Stateless & Stateful Widgets

**Use case:** Building domain-specific cards, badges, or interactive pickers that compose with `ui.renderWidget` and `ui.renderStateful` without vtables.

```zig
const MetricBadge = struct {
    label: []const u8,
    value: []const u8,
    accent: tui.Color,

    pub fn render(self: MetricBadge, ui: *tui.Ui, area: tui.Rect) !void {
        try ui.block(.{ .title = self.label, .border_type = .rounded }, area);
        const inner = (tui.Block{ .border_type = .rounded }).inner(area);
        _ = ui.buffer.setStringClipped(
            inner.left(),
            inner.top(),
            self.value,
            inner.width,
            .{ .foreground = self.accent, .bold = true },
            inner,
        );
    }
};

// Render anywhere on a Ui region:
try ui.renderWidget(MetricBadge{ .label = "Latency", .value = "1.4 ms", .accent = tui.palette.emerald.c400 }, area);
```

## 2. Collapsible `Tree` & `SplitPane`

**Use case:** File explorers, AST inspectors, and hierarchical navigation with `expandAll`, `collapseAll`, and per-node toggling.

```text
┌─ Module Tree ─────────────┐│┌─ Quick Actions ────────────┐
│ ▾ src                     │││> Inspect symbols            │
│   ▾ core                  │││  Run unit tests             │
│       buffer.zig          │││  Format module              │
│       layout.zig          │││  Generate docs              │
└───────────────────────────┘│└─────────────────────────────┘
```

```zig
const tree_roots = [_]tui.TreeNode{
    tui.TreeNode.branch("src", &.{
        tui.TreeNode.branch("core", &.{
            tui.TreeNode.leaf("buffer.zig"),
            tui.TreeNode.leaf("layout.zig"),
        }),
    }),
};

// Expand all, collapse all, or handle Enter/Space/Arrows/Click:
try state.tree.expandAll(&tree_roots);
state.tree.collapseAll();
_ = try state.tree.handleEvent(event, &tree_roots, tree_inner, true);
```

## 3. Animations, Custom Event Loops & Client-Owned `Locale`

- **Animations & `tui.fx`**: Drive `Tween`, `Spring`, `Transition`, and `Skeleton` shimmers from `app.deltaMs()` and apply `tui.fx.pulseHighlight` or `tui.fx.sweepWipe` directly on `ui.buffer`.
- **Custom Event Loop**: Bypass `app.run(...)` with `app.advanceTimer()`, `app.pollEvent(0)`, `app.draw(...)`, and `app.sleepFrame()` when integrating async I/O or background tasks.
- **Client-Owned `Locale` & `BitmapFont`**: Define `tui.Locale` structs explicitly for every language (months, weekdays, decimal separators, translation entries, `.rtl`/`.ltr` direction) alongside custom `tui.BitmapGlyph` banners.
