---
title: Architecture Overview
description: Understand tui.zig module boundaries, data flow, explicit allocator model, and zero-churn frame lifecycle.
keywords: tui.zig architecture, zig terminal buffer, Ui frame, BufferDiff, cross-platform backend
---

# Architecture Overview

**tui.zig** separates terminal I/O, cell buffering, styling, Unicode measurement, event parsing, and widgets into clean, acyclic subsystems:

```text
src/
├── tui.zig           Public root module re-exporting core, widgets, style, events
├── style/            TrueColor/OKLCH colors, OKLCH Color palettes, borders, 17 Themes
├── text/             Grapheme widths, RTL BiDi ordering, Locale i18n, BitmapFont, wrapping
├── core/             Rect, Constraints, Layout solver, Cell, Buffer, BufferDiff, AppInfo, Ui
├── event/            Key/Mouse/Resize/Paste/Focus events & streaming VT parser
├── backend/          Capability detection, ANSI emitter, Windows, POSIX, Memory
├── terminal/         Unified double-buffered App runtime, window titles & snapshot cache
└── widgets/          40+ stateless & stateful built-in widgets (chart, log, chrome, vt, ...)
```

## Data Flow per Frame

1. **Begin Frame (`app.beginFrame()`)**
   - Queries the active `Backend` dimensions and synchronizes `Buffer` sizes without freeing capacity.
   - Resets per-frame scratch memory retaining capacity between redraws.
   - Returns a root `Ui` (`Frame`) covering the active `Viewport`.
2. **Compose UI**
   - Split regions using `ui.rows`, `ui.cols`, `ui.splitFixed`, or automatic flow allocation (`ui.allocateRows`).
   - Draw built-in widgets (`ui.table`, `ui.paragraph`, `ui.chart`) or custom components (`ui.renderWidget` / `ui.renderStateful`).
3. **End Frame (`app.endFrame(&ui)`)**
   - Computes minimal run differences between `front` and `back` cell grids via `BufferDiff`.
   - Emits SGR & cursor delta sequences through `ansi.writeDiff` (wrapped in synchronized output `CSI ? 2026 h/l` when supported).
   - Swaps buffers so the active `front` state matches the terminal screen.
4. **Poll & Handle Events (`app.pollEvent`)**
   - Normalizes Win32 `INPUT_RECORD`s, POSIX `poll` + VT sequences, or injected `MemoryBackend` events into unified `tui.Event` values.

## Why Both Flat Helpers and Widget Structs?

Many applications want concise vertical panels (`ui.checkbox`, `ui.button`, `ui.textInput`) while complex dashboards need explicit `Rect` precision or custom reusable components. Because every flat method on `Ui` forwards straight to its underlying widget struct (`Block`, `Paragraph`, `Table`, etc.), both idioms share identical clipping, theming, and rendering code paths.
