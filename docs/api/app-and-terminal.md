---
title: App, Metadata & Backends API
description: API reference for tui.init, App, AppInfo, AppOptions, AppSettingsSchema, EnterOptionsSchema, Backend, and TerminalCapabilities.
keywords: tui.init, tui.App, AppInfo, AppOptions, AppSettings, setTitle, snapshot, BackendMode, inline_height, insertBefore
---

# App, Metadata & Backends

`App` is the single unified session and double-buffered terminal runtime returned by `tui.init(...)`. All rendering buffers, scratch arenas, snapshot caches, window titles, and stateful widget factories associate directly with that `App` instance and release cleanly in `defer app.deinit()`.

## `tui.init(allocator: std.mem.Allocator, options: AppOptions) !App`

Initializes an `App`, validates `options.settings` against `AppSettingsSchema` on stack memory, allocates double buffers, applies `options.app` metadata, and returns an owning `App`. Always pair with `defer app.deinit();`.

### `AppInfo`

| Field | Type | Default | Description |
|---|---|---|---|
| `name` | `[]const u8` | `"tui.zig"` | Client application display name (`ui.app.name`) |
| `version` | `[]const u8` | `"0.1.0"` | Client application version string (`ui.app.version`) |
| `description` | `[]const u8` | `""` | Short description exposed on `ui.app` |
| `author` | `[]const u8` | `""` | Maintainer or organization name |
| `title` | `?[]const u8` | `null` | Initial terminal window/tab title (`null` uses `name` via `effectiveTitle()`) |

### `AppOptions` & `AppSettings`

| Field | Type | Default | Description |
|---|---|---|---|
| `app` | `AppInfo` | `.{}` | Client application identity and window metadata bound to this `App` instance |
| `io` | `?std.Io` | `null` | `std.Io` handle (falls back to `std.Options.debug_io`) |
| `backend` | `BackendMode` | `.auto` | `.auto`, `.posix`, `.windows`, `.ansi`, or `.{ .memory = size }` |
| `viewport` | `Viewport` | `.fullscreen` | `.fullscreen`, `.{ .inline_height = n }`, or `.{ .fixed = Rect }` |
| `capability` | `?Capability` | `null` | Overrides automatic color detection (`.trueColor`, `.ansi256`, `.ansi16`, `.none`) |
| `theme` | `Theme` | `Theme.dark` | Active semantic `Theme` |
| `cursor_shape` | `?CursorShape` | `null` | Optional `DECSCUSR` hardware cursor shape (`.blinking_bar`, `.steady_bar`, `.blinking_block`, `.steady_block`, `.blinking_underline`, `.steady_underline`) restored automatically on exit |
| `settings` | `AppSettings` | `.{}` | Validated runtime flags |

Inside `settings` (`AppSettings`):
- `alternate_screen: bool = true`, `raw_mode: bool = true`, `mouse: bool = false`, `bracketed_paste: bool = true`, `focus_events: bool = false`, `hide_cursor: bool = true`, `synchronized_output: bool = true`, `title: ?[]const u8 = null`, `fps: u16 = 60` (`1..240`), `tab_size: u8 = 4` (`1..16`).
- Parse settings from JSON via `try AppOptions.parseSettingsJson(alloc, json_bytes)` (omitted keys inherit schema defaults automatically).

## `App` Methods

### Lifecycle, Title & Instance State

- `enter(self: *App) !void` / `restore(self: *App) void` / `deinit(self: *App) void` / `isEntered(self: *const App) bool`
- `quit(self: *App) void` / `isRunning(self: *const App) bool`
- `info(self: *const App) AppInfo` / `setInfo(self: *App, info: AppInfo) !void`
- `title(self: *const App) []const u8` / `setTitle(self: *App, title: []const u8) !void` (updates `OSC 0` + Win32 `SetConsoleTitleW` + headless record; Windows console titles restore automatically on exit)
- `capabilities(self: *const App) TerminalCapabilities`
- `setTheme(self: *App, theme: Theme) void`
- `setCursorShape(self: *App, shape: CursorShape) !void`
- `writeGraphicsSequence(self: *App, bytes: []const u8) !void` (writes Kitty/iTerm2/Sixel image payloads directly; `restore()` automatically clears active native graphics planes)
- `clearNativeGraphics(self: *App) void` / `clear(self: *App) !void`
- `area(self: *const App) Rect` / `size(self: *const App) Size` / `cursorPos(self: *const App) ?Position` / `frameCount(self: *const App) u64`

### Rendering, Events & Timing

- `beginFrame(self: *App) !Ui` / `endFrame(self: *App, ui: *Ui) !void` (automatically passes `AppInfo` into `ui.app`)
- `draw(self: *App, ctx: anytype, comptime render_fn: anytype) !void`
- `insertBefore(self: *App, height: u16, ctx: anytype, comptime draw_fn: anytype) !void`
- `setViewportHeight(self: *App, height: u16) !void`
- `pollEvent(self: *App, timeout_ms: i32) !Event` / `nextEvent(self: *App) !Event`
- `run(self: *App, state: anytype, comptime callbacks: anytype) !void` (paces frames at `settings.fps` and emits `.tick` events both when idle and during continuous input bursts)
- Custom Event Loop Helpers:
  - `advanceTimer(self: *App) u32` / `deltaMs(self: *const App) u32` / `deltaSeconds(self: *const App) f64`
  - `elapsedMs(self: *const App) u64` / `elapsedSeconds(self: *const App) f64` / `tickCount(self: *const App) u64`
  - `targetFrameMs(self: *const App) u32` / `sleepFrame(self: *const App) void`

### Allocator-Reusing Widget Factories

Reuse the `Allocator` bound in `tui.init(allocator, ...)` without repeating `allocator` at call sites (each returned state still owns its dynamic buffer and releases via `.deinit()`):

- `app.textInput()` / `app.textInputWith(initial)`
- `app.textArea()` / `app.textAreaWith(initial)`
- `app.treeState()` / `app.commandPalette()`

### Testing & Reusable Snapshots

- `pushTestEvent(self: *App, ev: Event) !void`
- `resizeTest(self: *App, size: Size) !void`
- `scrollback(self: *const App) []const u8` (recorded `insertBefore` lines on `.memory` backend)
- `snapshot(self: *App) ![]const u8`: renders the current screen into a capacity-retaining buffer owned by `App` (`deinit()` frees it automatically; slice remains valid until the next `snapshot()` call or `deinit()`)
