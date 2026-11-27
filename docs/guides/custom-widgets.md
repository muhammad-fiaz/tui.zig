---
title: Custom Widgets & Client UI Architecture
description: Build stateless and stateful custom widgets, client UI modules, responsive breakpoints, hardware cursor inputs, and mouse hitboxes in tui.zig.
keywords: custom widgets zig, tui custom component, renderStateful, renderWidget, zig client ui architecture, mouse hitbox tui
---

# Custom Widgets & Client UI Architecture

**tui.zig** dispatches custom widgets completely at compile time via `ui.renderWidget` and `ui.renderStateful`—requiring zero heap allocations, trait boxing, or dynamic vtables. Any Zig struct exposing `render` or `renderStateful` composes seamlessly with built-in containers, constraints, themes, and diffing.

Run all custom UI & widget examples interactively:

```sh
zig build run-custom-ui
zig build run-custom-widget
zig build run-custom-stateful-widget
```

## 1. Stateless Custom Widget (`*tui.Ui`)

Implement `pub fn render(self: Self, ui: *tui.Ui, area: tui.Rect) !void` (or `void`) to compose `Block`, theme roles, OKLCH Color colors, and child flow widgets:

```zig
const StatCard = struct {
    label: []const u8,
    value: []const u8,
    positive: bool = true,

    pub fn render(self: StatCard, ui: *tui.Ui, area: tui.Rect) !void {
        const blk = tui.Block{
            .title = self.label,
            .border_type = .rounded,
            .border_style = .{
                .foreground = if (self.positive)
                    tui.palette.sky.c500
                else
                    tui.palette.rose.c500,
            },
            .padding = tui.Padding.symmetric(1, 0),
        };
        try blk.render(ui, area);
        const inner = blk.inner(area);
        if (inner.isEmpty()) return;

        _ = ui.buffer.setStringClipped(
            inner.left(),
            inner.top(),
            self.value,
            inner.width,
            .{ .foreground = tui.palette.slate.c50, .bold = true },
            inner,
        );
    }
};

// Render inside any panel or region:
try ui.renderWidget(StatCard{ .label = "Uptime", .value = "99.98%" }, card_rect);
```

## 2. Direct Buffer Custom Widget (`*tui.Buffer`)

When drawing custom visualizations, sparklines, or high-density tables cell-by-cell, accept `*tui.Buffer` instead of `*tui.Ui`:

```zig
const SparkTile = struct {
    label: []const u8,
    values: []const u8,

    pub fn render(self: SparkTile, buf: *tui.Buffer, area: tui.Rect) void {
        const bounds = area.intersection(buf.area);
        if (bounds.isEmpty()) return;

        const bars = [_][]const u8{ " ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" };
        var pos = buf.setStringClipped(bounds.left(), bounds.top(), self.label, bounds.width, .{ .bold = true }, bounds);
        var x = pos.x +| 1;
        for (self.values) |v| {
            if (x >= bounds.right()) break;
            const idx: usize = @min(bars.len - 1, v / 32);
            x = buf.setStringClipped(x, bounds.top(), bars[idx], 1, .{ .foreground = tui.palette.teal.c400 }, bounds).x;
        }
    }
};
```

## 3. Stateful Custom Widget with Cursor & Mouse Hitboxes

Keep mutable interaction state cleanly in a caller-owned `State` struct, record rendered `tui.Rect` regions during `renderStateful` for accurate mouse hit-testing, and place the terminal cursor with `ui.setCursor(x, y)`:

```zig
const TagPickerState = struct {
    selected: [4]bool = .{ true, false, false, false },
    cursor_idx: usize = 0,
    chip_rects: [4]tui.Rect = @splat(tui.Rect.zero),

    pub fn handleEvent(self: *TagPickerState, event: tui.Event, focused: bool) bool {
        switch (event) {
            .mouse => |m| if (m.kind == .down and m.button == .left) {
                for (self.chip_rects, 0..) |rect, i| {
                    if (m.isInside(rect)) {
                        self.cursor_idx = i;
                        self.selected[i] = !self.selected[i];
                        return true;
                    }
                }
            },
            .key => |k| if (focused and k.kind != .release) {
                switch (k.code) {
                    .right => self.cursor_idx = (self.cursor_idx + 1) % 4,
                    .left => self.cursor_idx = if (self.cursor_idx == 0) 3 else self.cursor_idx - 1,
                    .enter => self.selected[self.cursor_idx] = !self.selected[self.cursor_idx],
                    else => return false,
                }
                return true;
            },
            else => {},
        }
        return false;
    }
};

const TagPicker = struct {
    tags: []const []const u8,
    focused: bool = true,

    pub fn renderStateful(self: TagPicker, ui: *tui.Ui, area: tui.Rect, st: *TagPickerState) void {
        var x = area.left();
        var y = area.top();
        for (self.tags, 0..) |tag, i| {
            const w = tui.text.displayWidth(tag) +| 4;
            if (x > area.left() and x + w > area.right()) {
                x = area.left();
                y += 1;
            }
            if (y >= area.bottom()) break;

            const start_x = x;
            const prefix = if (st.selected[i]) "[x " else "[+ ";
            x = ui.buffer.setStringClipped(x, y, prefix, area.right() -| x, ui.theme.accent, area).x;
            x = ui.buffer.setStringClipped(x, y, tag, area.right() -| x, ui.theme.text, area).x;
            x = ui.buffer.setStringClipped(x, y, "]", area.right() -| x, ui.theme.text, area).x;
            st.chip_rects[i] = tui.Rect.init(start_x, y, x -| start_x, 1);

            if (self.focused and st.cursor_idx == i) ui.setCursor(start_x + 1, y);
            x +|= 1;
        }
    }
};
```

## 4. Responsive Client UI Composition

In larger applications (`examples/custom_ui.zig`), organize screens as reusable view structs and inspect `ui.isCompact(min_cols)` during `render` to adapt seamlessly across wide and narrow terminals:

```zig
if (body.isCompact(72)) {
    // Stacked vertical cards on narrow terminals
    try body.renderWidget(ServiceCard{ .svc = selected, .focused = true }, body.allocateRows(4));
} else {
    // Master-detail 2-column split on desktop terminals
    const panes = body.cols(2, .{ .{ .percentage = 60 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 2 } });
    var left = panes[0];
    try left.renderWidget(ServiceCard{ .svc = selected, .focused = true }, left.allocateRows(4));
    var right = panes[1];
    try right.panel(.{ .title = "Inspector" }, right.area, selected, drawInspector);
}
```
