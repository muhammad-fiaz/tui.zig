---
title: Events & VT Parser API
description: Normalized input events (Event, KeyEvent, KeyCode, MouseEvent, EventParser) across Windows, POSIX, and Headless backends.
keywords: tui.Event, KeyEvent, MouseEvent, EventParser, Kitty keyboard, SGR mouse, bracketed paste
---

# Events & VT Parser

## `Event`

Union variants: `.key: KeyEvent`, `.mouse: MouseEvent`, `.resize: Size`, `.focus_gained`, `.focus_lost`, `.paste: []const u8`, `.tick`, `.none`.

### Predicates on `Event`

- `isEscape() bool`
- `isCtrlC() bool`
- `isChar(cp: u21) bool`
- `isResize() bool`
- `isKeyPress() bool`

## `KeyEvent`

Fields: `.code: KeyCode`, `.modifiers: KeyModifiers`, `.kind: KeyEventKind` (`.press`, `.repeat`, `.release`).

Helper methods: `k.isChar('a')`, `k.isCtrl('s')`.

## `MouseEvent`

Fields: `.kind: MouseEventKind` (`.down`, `.up`, `.drag`, `.moved`, `.scroll_up`, `.scroll_down`, `.scroll_left`, `.scroll_right`), `.button: MouseButton`, `.x: u16`, `.y: u16`, `.modifiers: KeyModifiers`.

Helper methods: `m.position()`, `m.isInside(rect)`, `m.isLeftClickInside(rect)`.

## `EventParser`

Streaming incremental byte decoder (`init()`, `feed(bytes)`, `nextEvent(is_eof)`), decoding ASCII/UTF-8 scalars, Alt+key prefixes, SS3, CSI sequences, Kitty keyboard CSI-u frames, SGR/X10 mouse reports, and bracketed paste chunks with explicit cleanup (`deinit()`).
