---
title: Embedded Terminal, Logs & Diff Viewers
description: Render ANSI/VT100 terminal streams with VtScreen and TerminalView, filter structured logs with EWIDT target matrices, and inspect unified diffs.
keywords: TerminalView, VtScreen, LogViewer EWIDT, DiffViewer, zig vt100 widget
---

# Embedded Terminal, Logs & Diff Viewers

## `TerminalView` & `VtScreen`

`VtScreen` is a pure-Zig VT100/ANSI screen state machine with zero external CLI dependencies. Feed raw ANSI byte streams (`\r`, `\n`, `\t`, `\x08`, `CSI` cursor movement, `CSI J`/`K` erases, SGR 16/256/TrueColor RGB, bold/dim/italic/underline/reverse/strikethrough, `?25h/l` cursor visibility, and `DECSCUSR` cursor shape) and render into any `Ui` pane via `ui.terminalView(...)`.

```zig
var screen = try tui.VtScreen.init(alloc, 80, 24);
defer screen.deinit();

screen.feed("\x1b[1;32mPASS\x1b[0m 91/91 unit tests\r\n");
screen.feed("\x1b[38;2;56;189;248mReady.\x1b[0m");

try ui.terminalView(.{
    .screen = &screen,
    .block = .{ .title = "Build Output", .focused = true },
    .show_cursor = true,
}, term_area);
```

## `LogViewer` with `EWIDT` Target Matrix

`LogViewer` filters entries by global `min_level`, substring `filter` (with match highlighting), and per-source `SourceFilter` overrides (`setSourceLevel`, `toggleSourceEnabled`). Press `h` to toggle the left-hand `EWIDT` target selector pane, `Tab` to switch focus between targets and log rows, `Left`/`Right` to adjust per-source level, `Space` to mute/unmute a source, and `s` to solo-focus a single source:

```zig
var logs = tui.LogViewerState{ .min_level = .info, .follow_tail = true };
logs.setSourceLevel("db", .warn);

const viewer = tui.LogViewer{
    .entries = &log_entries,
    .show_line_numbers = true,
    .show_status_line = true,
    .block = .{ .title = "Structured Logs", .focused = true },
};
_ = viewer.handleEvent(&logs, event, log_rect);
try ui.logViewer(viewer, &logs, log_rect);
```

## `DiffViewer`

`DiffViewer` renders unified hunks (`@@`), additions (`+`), removals (`-`), and context lines with old/new line numbers (`{d:>4}`), keyboard/mouse scrolling (`Up`/`Down`/`j`/`k`/`PgUp`/`PgDn`/`Home`/`End`), and row selection:

```zig
const dv = tui.DiffViewer{
    .lines = &diff_lines,
    .show_line_numbers = true,
    .block = .{ .title = "Unified Diff", .focused = true },
};
_ = dv.handleEvent(&state.diff, event, diff_rect);
try ui.diffViewer(dv, &state.diff, diff_rect);
```
