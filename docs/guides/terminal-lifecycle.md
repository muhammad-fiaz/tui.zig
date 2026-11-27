---
title: Terminal Lifecycle & Inline Viewports
description: Raw mode, alternate screen, schema-validated AppSettings, dynamic inline viewports, insertBefore scrollback printing, and restoration.
keywords: tui terminal lifecycle, AppOptions, inline_height, insertBefore, raw mode, alternate screen
---

# Terminal Lifecycle & Restoration

Improperly restored raw terminals leave user shells broken after exits or errors. **tui.zig** centralizes terminal state, window titles, double buffers, and restoration directly on `App` with deterministic `defer` guards and validated settings.

## Initialization Options (`AppOptions`)

Pass configuration via anonymous struct defaults in `tui.init(allocator, .{ ... })`:

- `app`: `AppInfo` (`.name`, `.version`, `.description`, `.author`, `.title`): accessible anywhere inside frames via `ui.app` and updatable live with `try app.setTitle(...)` / `try app.setInfo(...)`
- `backend`: `.auto` (default), `.posix`, `.windows`, `.ansi`, or `.{ .memory = .{ .width = 80, .height = 24 } }`
- `viewport`: `.fullscreen` (default), `.{ .inline_height = 8 }`, or `.{ .fixed = rect }`
- `theme`: `Theme` (defaults to `Theme.dark`)
- `cursor_shape`: `?CursorShape` (`null`, `.blinking_bar`, `.steady_bar`, `.blinking_block`, `.steady_block`, `.blinking_underline`, `.steady_underline`: automatically restored on exit)
- `capability`: `?Capability` override (`null` enables environment detection)
- `settings`: `AppSettings` with validated defaults:
  - `alternate_screen`: `true`
  - `raw_mode`: `true`
  - `mouse`: `false`
  - `bracketed_paste`: `true`
  - `focus_events`: `false`
  - `hide_cursor`: `true`
  - `synchronized_output`: `true`
  - `title`: `?[]const u8 = null`
  - `fps`: `60` (`1..240`)
  - `tab_size`: `4` (`1..16`)

## Safe Enter & Restore Pattern

```zig
var app = try tui.init(allocator, .{
    .io = init.io,
    .settings = .{
        .mouse = true,
        .alternate_screen = true,
    },
});
defer app.deinit(); // Restores saved console/termios state cleanly

try app.enter();
```

## Inline Viewports & `insertBefore`

CLI progress bars and live runners can dock below normal scrollback history while appending log lines above without clearing the widget area:

```zig
var app = try tui.init(allocator, .{
    .io = init.io,
    .viewport = .{ .inline_height = 4 },
    .settings = .{ .alternate_screen = false },
});
defer app.deinit();

try app.insertBefore(1, "Compiled 42/42 modules", struct {
    fn log(msg: []const u8, buf: *tui.Buffer) void {
        _ = buf.setStringClipped(0, 0, msg, buf.area.width, .{ .foreground = .green }, buf.area);
    }
}.log);
try app.draw(&state, render);
```
