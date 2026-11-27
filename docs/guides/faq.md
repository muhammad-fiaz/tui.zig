---
title: Frequently Asked Questions
description: Common questions about Zig version support, platform targets, widgets, OKLCH Color colors, custom UIs, cursor control, inline viewports, and testing in tui.zig.
keywords: tui.zig faq, zig 0.17.0, custom widgets, headless tui testing, OKLCH oklch, zig tui library
---

# Frequently Asked Questions

## What minimum Zig version does tui.zig require?

**tui.zig 0.1.0** requires **Zig 0.17.0+** (`zig version`). It targets Zig 0.17's current `std.Io`, `std.process`, `std.unicode`, and OS interfaces directly.

## Does tui.zig depend on ncurses or libc?

No. **tui.zig** links **zero external C libraries**. On Windows it calls native Win32 Console APIs (`kernel32`) for raw input records, UTF-8 (`CP 65001`), VT enabling, and restoration. On Linux, macOS, and BSD it uses native `std.posix` / `termios` / `poll` / `TIOCGWINSZ` / `SIGWINCH` and ANSI/VT escape sequences.

## Which platforms and architectures are supported?

All major desktop and embedded OS targets across both **32-bit and 64-bit** architectures:

- **Linux**: `x86_64`, `aarch64`, `x86`, `arm`, `thumb`, `riscv32`
- **Windows**: `x86_64`, `x86`, `aarch64`
- **macOS**: `aarch64` (Apple Silicon), `x86_64`

Freestanding targets (`x86-freestanding`) also compile cleanly when driven through buffer/ANSI streams or custom backends. Note that `x86-macos` (32-bit x86 macOS) is not implemented in Zig's standard library.

## How do I organize a real client application?

Keep your application state in a plain Zig struct (`State`), pass client metadata in `tui.init(allocator, .{ .app = .{ .name = "...", .version = "..." } })`, pair `defer app.deinit();`, reuse `app.allocator` for stateful widgets (`app.textInput()`, `app.treeState()`), and split logic cleanly into two functions:

- `onEvent(state: *State, event: tui.Event, app: *tui.App) !bool` updates state on `.key`, `.mouse`, `.paste`, `.resize`, or `.tick` events, updates window titles with `try app.setTitle(...)`, and calls `app.quit()` when exiting.
- `render(state: *State, ui: *tui.Ui) !void` reads `ui.app` (`name`, `version`, `effectiveTitle()`) and declares responsive layouts (`Navbar`, Left/Right/RTL `Sidebar`, `StatusBar`) and widgets.

See [Getting Started](/guides/getting-started) and [Custom Widgets & Client UIs](/guides/custom-widgets), or run `zig build run-app-shell`.

## Can I mix flat `ui.<widget>` methods and standalone widget structs?

Yes. Every flat helper (`ui.button`, `ui.table`, `ui.paragraph`, `ui.chart`, `ui.calendar`, etc.) wraps the corresponding struct in `tui.widgets`. Both share identical theme resolution, viewport clipping, and buffer diffing.

## How do I write reusable custom widgets without heap vtables?

Implement either method on any Zig struct:

- **Stateless widget**: `pub fn render(self: MyWidget, ui: *tui.Ui, area: tui.Rect) !void` (or targeting `*tui.Buffer`)
- **Stateful widget**: `pub fn renderStateful(self: MyWidget, ui: *tui.Ui, area: tui.Rect, state: *MyState) !void`

Render them with `try ui.renderWidget(my_widget, area)` or `try ui.renderStateful(my_widget, &my_state, area)`, resolved completely at compile time. Run `zig build run-custom-ui`, `zig build run-custom-widget`, and `zig build run-custom-stateful-widget` to see full patterns.

## How do I make layouts responsive when the terminal resizes?

Use constraint weights (`.{ .fill = 1 }`, `.{ .percentage = 40 }`, `.{ .min = 24 }`) inside `ui.rows` / `ui.cols`, and inspect `ui.isCompact(min_cols)` or `ui.size()` during `render` to switch between multi-column splits on wide windows and stacked panes on narrow terminals.

## How should mouse hit-testing work with responsive layouts?

Record rendered bounding `tui.Rect` fields onto your `State` struct during `render`, then test `event.mouse.isInside(state.my_button_rect)` or `event.mouse.isLeftClickInside(...)` inside `onEvent`. Because `render` recalculates every `Rect` on resize, mouse hitboxes automatically track resizes without hardcoded coordinates.

## How does hardware cursor positioning work in inputs and custom widgets?

Call `ui.setCursor(x, y)` inside `render` or `renderStateful` while your text input or custom editor is focused (`TextInput` and `TextArea` do this automatically). When a frame requests a cursor position, **tui.zig** moves and shows the terminal cursor after flushing; when no cursor is requested, it hides the cursor cleanly.

## How do colors work on older 16-color or 256-color terminals?

Use TrueColor RGB, Hex, HSL, HSV, `tui.Color.oklch(l, c, h)`, or OKLCH Color palettes (`tui.palette.sky.c400`) anywhere in styles and themes. Output automatically detects terminal capability (`TrueColor`, `ANSI-256`, `ANSI-16`, or monochrome) and degrades colors cleanly per cell.

## Can I build CLI progress bars without entering alternate screen?

Yes. Configure `.viewport = .{ .inline_height = 4 }` and `.settings = .{ .alternate_screen = false }` in `tui.init`, then call `try app.insertBefore(height, data, draw_fn)` to print completed log rows into normal shell scrollback above your live widget.

## How do I test interactive UIs in CI without a TTY?

Pass `.backend = .{ .memory = .{ .width = 80, .height = 24 } }` in `tui.init`, inject synthetic events with `try app.pushTestEvent(...)`, simulate resizes via `try app.resizeTest(...)`, run `try app.draw(&state, render)`, and assert against `try app.snapshot()`.

## What versions are supported for security updates?

Version `0.1.x` (`0.1.0+`) is actively supported. Versions below `0.1.0` are unsupported and deprecated, see the [Security Policy](/security).
