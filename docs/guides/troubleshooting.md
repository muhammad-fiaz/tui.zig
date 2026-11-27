---
title: Troubleshooting
description: Resolve common terminal rendering, raw mode, Windows UTF-8, cursor visibility, or TrueColor capability issues in tui.zig.
keywords: tui troubleshooting, raw mode restore zig, utf8 windows console, terminal truecolor, cursor position
---

# Troubleshooting

## Terminal displays broken Unicode borders (`???` or misaligned width)

- Ensure your terminal emulator uses a UTF-8 locale (`LANG=en_US.UTF-8`) and monospace Unicode font.
- On Windows, `tui.zig` sets console output & input code pages to UTF-8 (`CP 65001`) automatically during `app.enter()`.
- Check if `NO_COLOR` or `TERM=dumb` is exported in your environment, which intentionally degrades rendering capabilities.

## Hardware cursor appears in the wrong place or stays visible after exit

- Ensure `defer app.deinit();` appears immediately after `tui.init(...)` so normal exits and error paths restore raw mode, alternate screen, mouse tracking, and cursor visibility.
- When focused on a custom input widget, call `ui.setCursor(x, y)` using coordinates inside `ui.area`; `App` automatically shows the hardware cursor on frames with a cursor request and hides it otherwise.

```zig
var app = try tui.init(alloc, .{ .io = init.io });
defer app.deinit(); // Always place immediately after tui.init()
```

## Mouse clicks miss bordered widgets by 1 row

- Pass the exact rendered `Rect` from `render` into `onEvent`, or use the widget's `.handleEvent(...)` helper which subtracts `Block` borders (`b.inner(bounds)`) automatically:

```zig
// Store exact rendered area during render():
state.log_rect = lv_ui.area;

// Handle clicks/scrolls in onEvent() via the widget struct:
_ = (tui.LogViewer{ .entries = &logs, .block = .{ .title = "Logs" } }).handleEvent(&state.logs, event, state.log_rect);
```

## Colors look quantized to 16 or 256 colors

- Some multiplexers (`tmux`, `screen`) omit TrueColor flags unless `COLORTERM=truecolor` is exported or `TERM=tmux-256color` / `-direct` is configured.
- Force TrueColor in automated checks via `.capability = .trueColor`:

```zig
var app = try tui.init(alloc, .{
    .io = init.io,
    .capability = .trueColor,
});
```
