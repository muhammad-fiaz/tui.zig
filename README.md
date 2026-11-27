<div align="center">
    
# TUI.zig

<a href="https://muhammad-fiaz.github.io/tui.zig/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io-blue" alt="Documentation"></a>
<a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.17.0%2B-orange.svg?logo=zig" alt="Zig Version"></a>
<a href="https://github.com/muhammad-fiaz/tui.zig"><img src="https://img.shields.io/github/stars/muhammad-fiaz/tui.zig" alt="GitHub stars"></a>
<a href="https://github.com/muhammad-fiaz/tui.zig/issues"><img src="https://img.shields.io/github/issues/muhammad-fiaz/tui.zig" alt="GitHub issues"></a>
<a href="https://github.com/muhammad-fiaz/tui.zig/pulls"><img src="https://img.shields.io/github/issues-pr/muhammad-fiaz/tui.zig" alt="GitHub pull requests"></a>
<a href="https://github.com/muhammad-fiaz/tui.zig"><img src="https://img.shields.io/github/last-commit/muhammad-fiaz/tui.zig" alt="GitHub last commit"></a>
<a href="https://github.com/muhammad-fiaz/tui.zig"><img src="https://img.shields.io/github/license/muhammad-fiaz/tui.zig" alt="License"></a>
<a href="https://github.com/muhammad-fiaz/tui.zig/actions/workflows/ci.yml"><img src="https://github.com/muhammad-fiaz/tui.zig/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<img src="https://img.shields.io/badge/platforms-linux%20%7C%20windows%20%7C%20macos-blue" alt="Supported Platforms">
<a href="https://github.com/muhammad-fiaz/tui.zig/actions/workflows/github-code-scanning/codeql"><img src="https://github.com/muhammad-fiaz/tui.zig/actions/workflows/github-code-scanning/codeql/badge.svg" alt="CodeQL"></a>
<a href="https://github.com/muhammad-fiaz/tui.zig/releases/latest"><img src="https://img.shields.io/github/v/release/muhammad-fiaz/tui.zig?label=Latest%20Release&style=flat-square" alt="Latest Release"></a>
<a href="https://pay.muhammadfiaz.com"><img src="https://img.shields.io/badge/Sponsor-pay.muhammadfiaz.com-ff69b4?style=flat&logo=heart" alt="Sponsor"></a>
<a href="https://github.com/sponsors/muhammad-fiaz"><img src="https://img.shields.io/badge/Sponsor-GitHub-pink?style=social&logo=github" alt="GitHub Sponsors"></a>
<a href="https://hits.sh/muhammad-fiaz/tui.zig/"><img src="https://hits.sh/muhammad-fiaz/tui.zig.svg?label=Visitors&extraCount=0&color=green" alt="Repo Visitors"></a>

<p><em>A Fast, Native Terminal User Interface Library for Zig.</em></p>

<b><a href="https://muhammad-fiaz.github.io/tui.zig/">Documentation</a> |
<a href="https://muhammad-fiaz.github.io/tui.zig/api/">API Reference</a> |
<a href="https://muhammad-fiaz.github.io/tui.zig/guides/getting-started">Quick Start</a> |
<a href="CONTRIBUTING.md">Contributing</a></b>

</div>

`tui.zig` is a native Terminal User Interface (TUI) framework for Zig **0.17.0+**, built for terminal applications, interactive dashboards, form workflows, system monitors, and terminal graphics without C dependencies.

> [!TIP]
> If you build with tui.zig, make sure to give it a ⭐ star.

---

<details>
<summary><strong>Table of Contents</strong> (click to expand)</summary>

- [Why Use tui.zig?](#why-use-tuizig)
- [Prerequisites](#prerequisites)
- [Supported Platforms](#supported-platforms)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Contributing](#contributing)
- [License](#license)

</details>

---

## Why Use tui.zig?

**A zero-dependency native Zig library for terminal rendering, layout, input handling, and custom interfaces.**

- **Zero C dependencies on Zig 0.17.0+:** Communicates directly with Win32 Console APIs on Windows and native POSIX interfaces (`termios`, `poll`, `TIOCGWINSZ`, `SIGWINCH`) on Linux, macOS, and BSD—supporting both 32-bit and 64-bit targets without linking `ncurses` or `libc`.
- **Flicker-free double-buffered rendering:** Diffs front and back cell grids each frame, emits only changed spans with minimal SGR transitions, preserves column alignment for wide CJK and emoji clusters, supports OSC 8 clickable links, and brackets updates with synchronized output (`CSI ? 2026 h/l`).
- **Explicit allocator ownership, `AppInfo` & live window controls:** Pass a `std.mem.Allocator` once to `tui.init(allocator, .{ .app = .{ .name = "...", .version = "...", .title = "..." } })`, reuse it across `app.textInput()`, `app.treeState()`, `app.commandPalette()`, and zero-churn `app.snapshot()`, access metadata inside frames via `ui.app`, update terminal titles dynamically with `app.setTitle(...)`, and guarantee clean terminal restoration via `defer app.deinit()`.
- **Constraint-based & responsive layout engine:** Partitions viewports on the stack using `rows`, `cols`, and `splitFixed` with fixed sizes, percentages, ratios, min/max bounds, weighted `.fill`, flex spacing, edge-merged borders, and responsive breakpoint helpers (`ui.isCompact`).
- **OKLCH color palettes & 17 built-in themes:** Supports 24-bit RGB, HSL, HSV, Hex, CSS named colors, and native OKLCH (`Color.oklch`), alongside 26 OKLCH color families (`slate`, `stone`, `sky`, `lime`, `fuchsia`, `mauve`, `olive`, `mist`, `taupe`, etc.), automatic degradation to ANSI-256 and ANSI-16 terminals, JSON theme loading, and 17 built-in presets.
- **40+ widgets, shell navigation, plots, i18n & VT emulation:**
  - *Navigation & Layout:* `Navbar`, `Sidebar` (LTR/RTL), cascading `DropdownMenu`, `StatusBar`, `Block` panels, `Tabs`, `Accordion`, `Stepper`, `Pagination`, `Popup`, and overflow-safe `ToastManager`.
  - *Text, Inputs & Data:* Wrapping paragraphs, Markdown viewer, tables, lists, collapsible trees, live-validated `TextInput`, multi-line `TextArea`, switches, sliders, calendars, command palettes, `KeyValueList`, `LogViewer` (with `EWIDT` target matrix), `DiffViewer`, and an embedded `TerminalView` (`VtScreen`).
  - *Charts, Motion & Extensibility:* Gauges, sparklines, bar charts, XY charts (`.area`, `.step`, `.line`, `.scatter`, `.bar`), `PieChart`, `Heatmap`, vector canvases, custom `BitmapFont` and client-owned `Locale`/RTL support, `Tween`/`Spring`/`Transition` motion primitives, `Skeleton` shimmers, `tui.fx` buffer effects, and zero-vtable custom widget dispatch (`ui.renderWidget` and `ui.renderStateful`).
- **Inline scrollback & headless CI testing:** Supports fullscreen alternate screens, fixed sub-rectangles, `.inline_height` viewports that append to terminal scrollback via `insertBefore`, and an in-memory backend for deterministic unit and `--headless` snapshot testing.

> [!NOTE]
> `tui.zig` is under active development, and public APIs may change across releases as widget ergonomics and defaults evolve. Review the release notes and documentation before upgrading between versions.
>
> **Contributions are welcome.** Bug reports, feature requests, documentation improvements, and pull requests are appreciated.

---

<details>
<summary><strong>Similar Zig Projects</strong> (click to expand)</summary>

- For **HTTP client, server, and web applications**, check out [httpx.zig](https://github.com/muhammad-fiaz/httpx.zig).
- For **environment variables and `.env` parsing**, check out [env.zig](https://github.com/muhammad-fiaz/env.zig).
- For **ZON file format** support, check out [zon.zig](https://github.com/muhammad-fiaz/zon.zig).
- For **spinners, loading indicators, and progress bars**, check out [loaders.zig](https://github.com/muhammad-fiaz/loaders.zig).
- For **Model Context Protocol (MCP)** support, check out [mcp.zig](https://github.com/muhammad-fiaz/mcp.zig).
- For **API framework** support, check out [api.zig](https://github.com/muhammad-fiaz/api.zig).
- For **web framework** support, check out [zix](https://github.com/muhammad-fiaz/zix).
- For **archive handling and compression**, check out [archive.zig](https://github.com/muhammad-fiaz/archive.zig).
- For **compression file formats**, check out [zigx](https://github.com/muhammad-fiaz/zigx).
- For **CUDA** support, check out [cuda.zig](https://github.com/muhammad-fiaz/cuda.zig).
- For **simplified `build.zig` configuration**, check out [buildx.zig](https://github.com/muhammad-fiaz/buildx.zig).
- For **SQLite with a Zig-native implementation**, check out [sqlite.zig](https://github.com/muhammad-fiaz/sqlite.zig).
- For **file downloading**, check out [downloader.zig](https://github.com/muhammad-fiaz/downloader.zig).
- For **update checking and automatic updates**, check out [updater.zig](https://github.com/muhammad-fiaz/updater.zig).
- For **numerical computing**, check out [num.zig](https://github.com/muhammad-fiaz/num.zig).
- For **logging**, check out [logly.zig](https://github.com/muhammad-fiaz/logly.zig).
- For **UUID** support, check out [uuid.zig](https://github.com/muhammad-fiaz/uuid.zig).
- For **key-value database** support, check out [zkv.zig](https://github.com/muhammad-fiaz/zkv.zig).
- For **terminal colors and text styling**, check out [hint.zig](https://github.com/muhammad-fiaz/hint.zig).
- For **Brotli compression**, check out [brotli.zig](https://github.com/muhammad-fiaz/brotli.zig).
- For **Zstandard (Zstd) compression**, check out [zstd.zig](https://github.com/muhammad-fiaz/zstd.zig).
- For **Tree-sitter** integration, check out [tree-sitter.zig](https://github.com/muhammad-fiaz/tree-sitter.zig).
- For **regular expressions**, check out [regex.zig](https://github.com/muhammad-fiaz/regex.zig).

</details>

---

<details>
<summary><strong>Features</strong> (click to expand)</summary>

| Feature | Description |
|---|---|
| **Backends & Lifecycle** | Cross-platform `WindowsBackend` (Win32 Console API + `ReadConsoleInputW` + UTF-8 CP 65001 + ConPTY pipe fallback), `PosixBackend` (`termios`, `TIOCGWINSZ`, `SIGWINCH`, `poll`), `AnsiBackend`, and `MemoryBackend`; automatic terminal restoration via `defer app.deinit()`. |
| **Viewports & Inline Logs** | Fullscreen alternate screen, fixed sub-rectangle viewports, and `.inline_height` layouts supporting dynamic `setViewportHeight` and scrollback `insertBefore` output. |
| **Rendering & Cell Grid** | Double-buffered 32-byte inline UTF-8 `Cell` storage, wide-character leader protection, `BufferDiff` run coalescing, synchronized updates (`CSI ? 2026 h/l`), and OSC 8 hyperlinks. |
| **Layout Engine** | Zero-allocation `rows`, `cols`, and `splitFixed` constraint solver supporting `length`, `percentage`, `ratio`, `min`, `max`, `fill`, `Flex` alignment, overlap border merging, and `ui.isCompact` breakpoints. |
| **OKLCH Color & Themes** | 24-bit RGB/HSL/HSV/Hex, CSS colors, direct `Color.oklch`, all 26 OKLCH Color families (`c50`..`c950`), perceptual ANSI-256/16 degradation, curly/dotted underlines, 17 theme presets, and JSON themes (`parseThemeJson`). |
| **Unicode, Fonts & i18n** | Grapheme cluster width measurement, multi-script CJK/Arabic/Indic/Cyrillic/emoji column alignment, word/character wrapping (`WrapIterator`), RTL visual ordering (`visualOrderInto`), `Locale` translations & decimals, client `BitmapFont` glyphs (`BitmapGlyph`, `FontRenderMode`), `symbols.icons` presets, multi-span `Line`/`Text`, and `Masked` helpers. |
| **Event & Input Parser** | Normalized `KeyEvent` (press/repeat/release, Ctrl/Alt/Shift/Super modifiers, Kitty CSI-u, legacy VT/SS3), `MouseEvent` (SGR/X10/Win32 clicks, drag, scroll wheel), focus tracking, resize, and bracketed paste. |
| **Containers & Chrome** | `Block` (16 border sets, edge collapsing, shadows, multi-title support), `Clear`, `Fill`, `Divider`, `Header`, `Navbar` (LTR/RTL), `Sidebar` (Left/Right & RTL/LTR), `StatusBar`, `MenuBar`, `ContextMenu`, `Breadcrumbs`, `SplitPane`, `ScrollView`, `Accordion`, `Stepper`, `Pagination`, `KeyValueList`. |
| **Forms & Validation** | `TextInput` (UTF-8, click/drag selection, masking, hardware cursor tracking, schema rules), `TextArea` (multi-line selection, tab expansion, read-only, gutter & scroll), `Button`, `Checkbox` (tri-state), `RadioGroup` (vertical & wrapped horizontal), `Select` / `Dropdown`, `Switch`, `Slider`, `FocusGroup`. |
| **Collections & Navigation** | `Paragraph`, `List` (multi-line items, auto-scroll), `Table` (sticky header/footer, constraint columns, striping, cell highlights), `Tabs`, `Tree` (path-hashed `TreeState`), `Scrollbar`, `Calendar` (localized month/weekday labels, event highlights), `LogViewer`, `DiffViewer`. |
| **Telemetry & Plots** | `Gauge` (1/8th Unicode blocks), `LineGauge`, `ProgressBar` (determinate & indeterminate), `Spinner`, `Sparkline`, `BarChart`, multi-series XY `Chart` (`.scatter`, `.line`, `.area`, `.step`, `.bar`), `PieChart` (`.solid`, `.segmented`, `.hud`, `.rose`), `Heatmap`, `Canvas` (`Braille`, `Quadrant`, `HalfBlock`, `Dot`, `Painter`), and `TerminalView` (`VtScreen`). |
| **Overlays & Productivity** | `Popup` (backdrop dim & centering), `ConfirmDialog`, overflow-safe `Toast` & `ToastManager` stacked banners, `Tooltip`, `CommandPalette` (live filter + shortcuts + mouse), `BigText` banners, and `Markdown` viewer. |
| **Animations & Visual Effects** | Zero-allocation `Tween`, `Easing`, `Spring` physics, `Transition`, `Skeleton` loading shimmers, `tui.fx` buffer effects (`fade`, `dimBackdrop`, `dissolve`, `sweepWipe`, `shimmer`, `pulseHighlight`), and monotonic `.tick` timing for both `App.run()` and custom client event loops. |
| **Custom Client UIs** | Compile-time `ui.renderWidget` and `ui.renderStateful` dispatch targeting `*tui.Ui` or `*tui.Buffer` directly with zero heap vtables. |

</details>

---

<details>
<summary><strong>Prerequisites and Supported Platforms</strong> (click to expand)</summary>

<br>

## Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| **Zig** | **0.17.0+** (minimum) | Download from [ziglang.org](https://ziglang.org/download/) |
| **Operating System** | Windows, Linux, macOS, BSD | 32-bit and 64-bit targets without external C libraries |

> [!IMPORTANT]
> **Zig 0.17.0+ is required.** This library targets Zig **0.17.0+** and tracks its `std.Io`, `std.process`, and standard library interfaces directly.

---

## Supported Platforms

| Platform | x86_64 (64-bit) | aarch64 (ARM64) | 32-bit (`x86` / `arm` / `thumb` / `riscv32`) |
|---|---|---|---|
| **Linux** | Yes | Yes | Yes |
| **Windows** | Yes | Yes | Yes (`x86-windows`) |
| **macOS** | Yes | Yes (Apple Silicon) | No |

32-bit macOS (`x86-macos`) is not supported because Zig's standard library does not implement that target. Use `x86_64-macos` or `aarch64-macos`. Freestanding targets also compile cleanly when driven by custom byte/memory streams.

### Cross-Compilation

```bash
# Build for Linux x86_64 from Windows/macOS
zig build -Dtarget=x86_64-linux-gnu

# Build for 32-bit Linux / ARM / RISC-V
zig build -Dtarget=x86-linux-musl
zig build -Dtarget=arm-linux-musleabihf
zig build -Dtarget=riscv32-linux-musl

# Build for macOS Apple Silicon
zig build -Dtarget=aarch64-macos

# Build for Windows (64-bit / 32-bit / ARM64)
zig build -Dtarget=x86_64-windows
zig build -Dtarget=x86-windows
zig build -Dtarget=aarch64-windows
```

</details>

---

## Installation

Choose either pinned stable release tarballs for reproducible builds or track the `main` branch directly.

### Method 1: Stable Version Pinning (Recommended)

**Latest Release (`v0.1.0`)**

```bash
zig fetch --save https://github.com/muhammad-fiaz/tui.zig/archive/refs/tags/0.1.0.tar.gz
```

### Method 2: Main Branch / Development Install

Install directly from the latest `main` branch commit:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/tui.zig.git#main
```

> [!NOTE]
> **tui.zig** requires Zig **0.17.0+**.
>
> To generate API HTML docs locally from any checkout, run `zig build docs` to output into `zig-out/docs/`.

---

<details>
<summary><strong>Method 3: Manual `build.zig.zon` Configuration</strong> (click to expand)</summary>

Pin a stable release tarball OR track `main` explicitly in `build.zig.zon`:

```zig
// Option A: Stable release version pinning (v0.1.0)
.dependencies = .{
    .tui = .{
        .url = "https://github.com/muhammad-fiaz/tui.zig/archive/refs/tags/0.1.0.tar.gz",
        .hash = "...", // Run `zig fetch --save <url>` to populate hash
    },
},

// Option B: Direct main branch tracking
.dependencies = .{
    .tui = .{
        .url = "git+https://github.com/muhammad-fiaz/tui.zig.git#main",
        .hash = "...", // Run `zig fetch --save git+https://github.com/muhammad-fiaz/tui.zig.git#main`
    },
},
```

</details>

---

<details>
<summary><strong>Method 4: Local Source Checkout</strong> (click to expand)</summary>

```bash
git clone https://github.com/muhammad-fiaz/tui.zig.git
cd tui.zig
zig build
zig build test
zig build run-all-examples
```

To depend on a local checkout from another project:

```zig
.dependencies = .{
    .tui = .{
        .path = "../tui.zig",
    },
},
```

</details>

---

### Wire into `build.zig`

```zig
const tui_dep = b.dependency("tui", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("tui", tui_dep.module("tui"));
```

---

## Quick Start

A complete interactive terminal app with header, bordered card, animated spinner, progress gauge, and status bar:

```zig
const std = @import("std");
const tui = @import("tui");

const State = struct {
    ticks: u64 = 0,
    ratio: f64 = 0.65,
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    switch (event) {
        .key => |k| if (k.isChar('q') or event.isEscape() or event.isCtrlC()) {
            app.quit();
            return false;
        },
        .tick => state.ticks +%= 1,
        else => {},
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "tui.zig", .subtitle = "Quick Start", .right = "v" ++ tui.version }, hdr.area);

    var center = layout[1].margin(tui.Margin.symmetric(4, 2));
    try center.panel(.{
        .title = "Welcome",
        .focused = true,
        .padding = tui.Padding.uniform(1),
    }, center.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            try p.paragraph(.{
                .raw = "Native Zig 0.17.0+ terminal rendering with double buffering and explicit allocators.",
                .wrap = .word,
            }, null);
            p.space(1);
            try p.gauge(.{ .ratio = st.ratio, .label = "Build 65%" }, null);
            p.space(1);
            p.spinner(.{ .tick = st.ticks, .label = "Event loop running" }, null);
        }
    }.draw);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = "READY", .badge = true }},
        .right = &.{.{ .text = "q / Esc Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    var app = try tui.init(init.gpa, .{
        .io = init.io,
        .settings = .{ .title = "tui.zig Quick Start" },
    });
    defer app.deinit();

    var state = State{};
    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
```

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests and `--headless` example assertions for new functionality
4. Ensure all checks pass: `zig build test`, `zig build run-all-examples`, and `zig build docs`
5. Submit a pull request (see [CONTRIBUTING.md](CONTRIBUTING.md))

---

## License

MIT License — see [LICENSE](LICENSE) for details. Copyright (c) 2026 Muhammad Fiaz.
