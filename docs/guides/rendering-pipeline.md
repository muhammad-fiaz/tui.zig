---
title: Rendering Pipeline & Buffer Diffing
description: Explore Cell representation, inline UTF-8 grapheme storage, wide character handling, OSC 8 hyperlinks, and BufferDiff emissions.
keywords: BufferDiff, double buffered tui, inline cell storage, wide characters unicode, osc 8 hyperlink
---

# Rendering Pipeline & Buffer Diffing

At the heart of **tui.zig** is a two-dimensional grid of `Cell` structs paired with an incremental diffing algorithm (`BufferDiff`).

## Inline `Cell` Design

Each `Cell` embeds a fixed **32-byte inline UTF-8 grapheme buffer**, covering ASCII, CJK double-width glyphs, box-drawing characters, Braille cells, and most multi-codepoint emoji clusters without heap indirection. Only rare >32-byte grapheme clusters spill into the buffer's symbol arena.

Key attributes stored per cell:

- **Foreground, Background, Underline Color** (`tui.Color`)
- **Hyperlinks**: Optional OSC 8 link URLs (`hyperlink: ?[]const u8`)
- **Text Modifiers**: `bold`, `dim`, `italic`, `underline`, `blink`, `rapid_blink`, `reverse`, `hidden`, `strikethrough`, `overline`, and `UnderlineStyle` (`.single`, `.double_line`, `.curly`, `.dotted`, `.dashed`)
- **`diff_option`**: `.none` or `.skip` (used automatically on trailing columns of 2-column wide CJK/emoji graphemes so cursor advances and clears don't split wide glyphs)

## Safe Multi-Column & Clipped Writes

Always write through `buffer.setStringClipped(...)` (used by all built-in widgets):

```zig
const label = "Status: 漢字 🚀";
_ = ui.buffer.setStringClipped(area.left(), area.top(), label, area.width, ui.theme.accent, area);
```

- Clips cleanly against arbitrary sub-rectangles (`Rect.intersection`)
- Computes grapheme widths via `GraphemeIterator`
- Clears damaged leader cells if you overwrite the second column of a pre-existing wide glyph
- Marks trailing columns as `.skip` automatically

## Incremental `BufferDiff`

During `endFrame()`, `BufferDiff.init(prev, next)` skips unchanged positions, coalesces contiguous modified horizontal spans into minimal cursor moves, and emits delta SGR and OSC 8 transitions via `ansi.writeDiff`. Synchronized Update markers (`CSI ? 2026 h` / `l`) wrap each flush on compatible terminals to prevent screen tearing.

```zig
// Manual transaction pattern when driving frames outside app.run():
var ui = try app.beginFrame();
try render(&state, &ui);
try app.endFrame(&ui);
```
