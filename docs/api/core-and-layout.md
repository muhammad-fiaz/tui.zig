---
title: Ui, Buffer & Layout Core API
description: Complete API reference for Ui/Frame, Rect, Size, Position, Margin, Padding, Constraint, Layout, Cell, Buffer, and BufferDiff.
keywords: tui.Ui, tui.Buffer, tui.Cell, tui.Layout, tui.Rect, isCompact, renderWidget, renderStateful
---

# Ui, Buffer & Layout Core

## `Ui` (`Frame` alias)

Passed to draw callbacks and custom widgets. Provides zero-allocation splitting, responsive breakpoint checks, automatic flow allocation, hardware cursor requests, and compile-time widget dispatch.

### Region & Layout Methods

- `scratchAllocator(self: *Ui) std.mem.Allocator` — per-frame reset arena allocator
- `available(self: *const Ui) Rect` — remaining vertical flow area
- `size(self: *const Ui) Size` / `isCompact(self: *const Ui, threshold: u16) bool` — current dimensions and responsive width breakpoint check
- `allocateRows(self: *Ui, height: u16) Rect` / `space(self: *Ui, rows_count: u16) void`
- `resolveArea(self: *Ui, explicit: ?Rect, default_height: ?u16) Rect`
- `region(self: *const Ui, sub_area: Rect) Ui` / `inset(self: *const Ui, pad: Padding) Ui` / `margin(self: *const Ui, m: Margin) Ui`
- `cols(self: *const Ui, comptime N: usize, constraints: [N]Constraint, options: LayoutOptions) [N]Ui`
- `rows(self: *const Ui, comptime N: usize, constraints: [N]Constraint, options: LayoutOptions) [N]Ui`
- `splitFixed(self: *const Ui, comptime N: usize, constraints: [N]Constraint, options: LayoutOptions) [N]Rect`
- `splitScratch(self: *Ui, constraints: []const Constraint, options: LayoutOptions) ![]Rect`
- `setCursor(self: *Ui, x: u16, y: u16) void` / `fillThemeSurface(self: *Ui) void`
- `contextMenu(self: *Ui, opts: ContextMenu, target_area: ?Rect) !void`
- `renderWidget(self: *Ui, widget: anytype, target_area: ?Rect) !void`
- `renderStateful(self: *Ui, widget: anytype, state: anytype, target_area: ?Rect) !void`

## Geometry Primitives

- `Position { x: u16, y: u16 }`
- `Size { width: u16, height: u16 }`
- `Margin { horizontal: u16 = 0, vertical: u16 = 0 }` (`Margin.uniform`, `Margin.symmetric`)
- `Padding { left: u16 = 0, right: u16 = 0, top: u16 = 0, bottom: u16 = 0 }` (`Padding.uniform`, `Padding.symmetric`, `Padding.horizontal`, `Padding.vertical`)
- `Rect { x, y, width, height }` (`init`, `intersection`, `unionWith`, `inner`, `inset`, `containsXY`, `clampPos`, `isEmpty`)

## `Buffer` & `Cell`

- `Buffer.init(allocator, area) !Buffer` / `deinit()` / `resize(area) !void` / `clear()`
- `get(x, y) ?*const Cell` / `getMut(x, y) ?*Cell`
- `setStringClipped(x, y, text, max_w, style, clip) Position`
- `setStyle(area, style)` / `fill(area, sym, style)` / `merge(other)` / `toPlainTextAlloc(alloc)`
- `Cell`: `.empty`, `.symbol()`, `.setSymbol`, `.mergeSymbol`, `.setStyle`, `.style()`, `.cellWidth()`, `.hyperlink`
