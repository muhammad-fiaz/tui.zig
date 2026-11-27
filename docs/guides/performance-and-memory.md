---
title: Memory Management & Zero-Churn Design
description: Design zero-allocation per-frame UIs using Cell inline buffers, capacity-retaining arenas, and delta SGR emission.
keywords: tui memory management, explicit allocator zig, arena retain capacity, zero frame allocations
---

# Memory Management & Zero-Churn Design

Terminal UI loops often run 30–120 times per second. **tui.zig** avoids allocator pressure across redraws by keeping persistent buffers bounded and resetting only O(1) arena pointers between frames.

## Allocation Lifecycle

1. **`tui.init` & Resizes**: Allocates `App`'s `front`/`back` `Cell` slices (`width * height`), ANSI staging buffers, and reusable snapshot cache. Resizes grow in place when capacity suffices (`Allocator` passed once to `tui.init`).
2. **`App.scratch_arena` (`ui.scratchAllocator()`)**: Stores transient per-frame data (table column rects, `Canvas`/`Chart` grids, dynamic filtered labels). Cleared each `beginFrame()` reusing existing capacity—eliminating repeated `alloc`/`free` calls after the first frame.
3. **Reusable `app.snapshot()`**: Serializes the current screen into `App`'s capacity-retaining buffer (released in `app.deinit()`), avoiding allocate/free churn across tests and inspections.
4. **Inline 32-Byte Cell Storage**: `Cell` avoids heap indirection for ASCII, box-drawing, Braille, and typical multi-byte emoji clusters.
5. **Owned Widget States & `App` Factories**: `app.textInput()`, `app.textArea()`, `app.treeState()`, and `app.commandPalette()` reuse `app.allocator` cleanly and release via explicit `.deinit()`.
6. **Diff-Minimized ANSI Output**: Only modified cells emit escapes, skipping redundant CSI cursor moves across contiguous runs and redundant SGR attributes across identical styles.
