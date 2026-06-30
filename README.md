<div align="center">


# TUI.zig

<a href="https://muhammad-fiaz.github.io/tui.zig/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io-blue" alt="Documentation"></a>
<a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.16.0+-orange.svg?logo=zig" alt="Zig Version"></a>
<a href="https://github.com/muhammad-fiaz/tui.zig"><img src="https://img.shields.io/github/stars/muhammad-fiaz/tui.zig" alt="GitHub stars"></a>
<a href="https://github.com/muhammad-fiaz/tui.zig/issues"><img src="https://img.shields.io/github/issues/muhammad-fiaz/tui.zig" alt="GitHub issues"></a>
<a href="https://github.com/muhammad-fiaz/tui.zig/pulls"><img src="https://img.shields.io/github/issues-pr/muhammad-fiaz/tui.zig" alt="GitHub pull requests"></a>
<a href="https://github.com/muhammad-fiaz/tui.zig"><img src="https://img.shields.io/github/last-commit/muhammad-fiaz/tui.zig" alt="GitHub last commit"></a>
<a href="https://github.com/muhammad-fiaz/tui.zig/blob/main/LICENSE"><img src="https://img.shields.io/github/license/muhammad-fiaz/tui.zig" alt="License"></a>
<a href="https://github.com/muhammad-fiaz/tui.zig/actions/workflows/ci.yml"><img src="https://github.com/muhammad-fiaz/tui.zig/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<a href="https://github.com/muhammad-fiaz/tui.zig/actions/workflows/deploy-docs.yml"><img src="https://github.com/muhammad-fiaz/tui.zig/actions/workflows/deploy-docs.yml/badge.svg" alt="Docs"></a>
<img src="https://img.shields.io/badge/platforms-linux%20%7C%20windows%20%7C%20macos-blue" alt="Supported Platforms">
<a href="https://github.com/muhammad-fiaz/tui.zig/releases/latest"><img src="https://img.shields.io/github/v/release/muhammad-fiaz/tui.zig?label=Latest%20Release&style=flat-square" alt="Latest Release"></a>
<a href="https://pay.muhammadfiaz.com"><img src="https://img.shields.io/badge/Sponsor-pay.muhammadfiaz.com-ff69b4?style=flat&logo=heart" alt="Sponsor"></a>
<a href="https://github.com/sponsors/muhammad-fiaz"><img src="https://img.shields.io/badge/Sponsor-GitHub-pink?style=social&logo=github" alt="GitHub Sponsors"></a>
<a href="https://hits.sh/github.com/muhammad-fiaz/tui.zig/"><img src="https://hits.sh/github.com/muhammad-fiaz/tui.zig.svg?label=Visitors&extraCount=0&color=green" alt="Repo Visitors"></a>

<p><em>A modern, feature-rich Terminal User Interface library for Zig</em></p>

<b><a href="https://muhammad-fiaz.github.io/tui.zig/">Documentation</a> |
<a href="https://muhammad-fiaz.github.io/tui.zig/api/">API Reference</a> |
<a href="https://muhammad-fiaz.github.io/tui.zig/guide/getting-started">Quick Start</a> |
<a href="https://muhammad-fiaz.github.io/tui.zig/contributing">Contributing</a></b>

</div>

---
TUI.zig is a Modern and easy-to-use Terminal User Interface (TUI) library for the Zig programming language. It provides a rich set of features to create modern, responsive, and visually appealing terminal applications with minimal effort.

> [!NOTE]
> This project is actively maintained and contributions are welcome. See our [Contributing Guide](https://muhammad-fiaz.github.io/tui.zig/contributing) for details.

---

<details>
<summary><strong>Features</strong> (click to expand)</summary>

| Feature | Description | Documentation |
|---------|-------------|---------------|
| **True Color (24-bit RGB)** | Full spectrum color support for modern terminals. | https://muhammad-fiaz.github.io/tui.zig/guide/styling |
| **256 Color Palette** | Fallback color support for older terminals. | https://muhammad-fiaz.github.io/tui.zig/guide/styling |
| **16 ANSI Colors** | Universal compatibility with basic terminal colors. | https://muhammad-fiaz.github.io/tui.zig/guide/styling |
| **Double Buffering** | Flicker-free rendering by buffering entire screen. | https://muhammad-fiaz.github.io/tui.zig/api/renderer |
| **Diff-Based Updates** | Only redraw changed cells for optimal performance. | https://muhammad-fiaz.github.io/tui.zig/api/renderer |
| **Unicode Support** | Full grapheme cluster handling for international text. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets |
| **Wide Character Support** | CJK and emoji rendering with proper width calculation. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets |
| **Keyboard Events** | Full key detection with modifiers (Ctrl, Alt, Shift). | https://muhammad-fiaz.github.io/tui.zig/guide/events |
| **Mouse Support** | Click, drag, scroll, and hover event handling. | https://muhammad-fiaz.github.io/tui.zig/guide/events |
| **Bracketed Paste** | Safe paste mode to distinguish typed vs pasted input. | https://muhammad-fiaz.github.io/tui.zig/guide/events |
| **Focus Events** | Window focus detection for responsive applications. | https://muhammad-fiaz.github.io/tui.zig/guide/events |
| **Raw Mode** | Direct terminal control for real-time input. | https://muhammad-fiaz.github.io/tui.zig/api/terminal |
| **Text Widget** | Styled text with alignment and wrapping. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#text |
| **Button Widget** | Clickable buttons with hover states and callbacks. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#button |
| **Input Field** | Single-line text input with cursor navigation. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#input-field |
| **Text Area** | Multi-line text editing with scrolling. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#text-area |
| **Checkbox** | Toggle checkboxes with state management. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#checkbox |
| **Radio Button** | Single selection groups for mutually exclusive options. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#radio-button |
| **Progress Bar** | Visual progress indicators with customizable styles. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#progress-bar |
| **Spinner** | Animated loading indicators with multiple presets. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#spinner |
| **List View** | Scrollable item lists with selection support. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#list-view |
| **Table** | Data tables with columns, rows, and sorting. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#table |
| **Tabs** | Tabbed navigation for organizing content. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#tabs |
| **Modal** | Dialog overlays for focused interactions. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#modal |
| **Scroll View** | Scrollable containers for overflow content. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#scroll-view |
| **Split View** | Resizable panes for multi-panel layouts. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#split-view |
| **Badge** | Status indicators with variants and sizes. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#badge |
| **Card** | Container widgets with titles and content. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#card |
| **Tooltip** | Contextual information on hover. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#tooltip |
| **Accordion** | Collapsible content sections. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#accordion |
| **Breadcrumb** | Navigation path indicators. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#breadcrumb |
| **Sidebar** | Navigation sidebars with items. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#sidebar |
| **Status Bar** | Application status displays. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#status-bar |
| **Toast** | Notification messages with auto-dismiss. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#toast |
| **Skeleton** | Loading placeholders with animations. | https://muhammad-fiaz.github.io/tui.zig/guide/widgets#skeleton |
| **Rich Text Styling** | Bold, italic, underline, strikethrough formatting. | https://muhammad-fiaz.github.io/tui.zig/guide/styling |
| **Built-in Themes** | Default, Dark, Light, Nord, Dracula, Gruvbox themes. | https://muhammad-fiaz.github.io/tui.zig/guide/styling#themes |
| **Custom Themes** | Create your own color schemes with theme builder. | https://muhammad-fiaz.github.io/tui.zig/guide/styling#custom-themes |
| **Border Styles** | Single, double, rounded, thick, ASCII border styles. | https://muhammad-fiaz.github.io/tui.zig/guide/styling#borders |
| **Flex Layout** | Flexible row/column layouts with constraints. | https://muhammad-fiaz.github.io/tui.zig/guide/layout |
| **Box Model** | Padding, margin, and border support. | https://muhammad-fiaz.github.io/tui.zig/guide/layout#box-model |
| **Constraints** | Min/max sizing for responsive layouts. | https://muhammad-fiaz.github.io/tui.zig/guide/layout#constraints |
| **Alignment** | Start, center, end, stretch alignment options. | https://muhammad-fiaz.github.io/tui.zig/guide/layout#alignment |
| **Easing Functions** | Linear, ease-in, ease-out, bounce, elastic curves. | https://muhammad-fiaz.github.io/tui.zig/guide/animation |
| **Tween Animations** | Smooth value interpolation for transitions. | https://muhammad-fiaz.github.io/tui.zig/guide/animation#tween |
| **Timer System** | Scheduled callbacks for timed operations. | https://muhammad-fiaz.github.io/tui.zig/guide/animation#timers |
| **FPS Counter** | Performance monitoring for optimization. | https://muhammad-fiaz.github.io/tui.zig/api/renderer#fps |

</details>

---

<details>
<summary><strong>Prerequisites and Supported Platforms</strong> (click to expand)</summary>

<br>

## Prerequisites

Before using `TUI.zig`, ensure you have the following:

| Requirement | Version | Notes |
|-------------|---------|-------|
| **Zig** | 0.16.0+ | Download from [ziglang.org](https://ziglang.org/download/) |
| **Operating System** | Windows 10+, Linux, macOS | Cross-platform terminal support |

---

## Supported Platforms

`TUI.zig` is validated on these architectures:

| Platform | x86_64 (64-bit) | aarch64 (ARM64) | x86 (32-bit) |
|----------|-----------------|-----------------|--------------|
| **Linux** | Yes | Yes | Yes |
| **Windows** | Yes | Yes | Yes |
| **macOS** | Yes | Yes (Apple Silicon) | No |

### Cross-Compilation

Zig makes cross-compilation easy. Build for any target from any host:

```bash
# Build for Linux ARM64 from Windows
zig build -Dtarget=aarch64-linux

# Build for Windows from Linux  
zig build -Dtarget=x86_64-windows

# Build for macOS Apple Silicon from Linux
zig build -Dtarget=aarch64-macos

# Build for 32-bit Windows
zig build -Dtarget=x86-windows
```

</details>

---

## Quick Start

### Installation

#### Stable Release (Recommended)

Install the latest stable release using a specific version tag:

```bash
zig fetch --save "git+https://github.com/muhammad-fiaz/tui.zig.git#0.0.2"
```

#### Development (Latest)

Install the latest development version from the main branch:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/tui.zig.git
```

Then add to your `build.zig`:

```zig
const tui_dep = b.dependency("tui", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("tui", tui_dep.module("tui"));
```

### Hello World

```zig
const std = @import("std");
const tui = @import("tui");

pub fn main() !void {
    // Create application
    var app = try tui.App.init(.{});
    defer app.deinit();

    // Create a simple widget
    var hello = HelloWidget{};
    try app.setRoot(&hello);

    // Run the event loop
    try app.run();
}

const HelloWidget = struct {
    pub fn render(self: *HelloWidget, ctx: *tui.RenderContext) void {
        _ = self;
        var screen = ctx.getSubScreen();

        // Center the message
        const msg = "Hello, TUI.zig!";
        const x = (screen.width -| 18) / 2;
        const y = screen.height / 2;

        screen.setStyle(tui.Style.default
            .setFg(tui.Color.rgb(100, 200, 255))
            .bold());
        screen.moveCursor(x, y);
        screen.putString(msg);
    }

    pub fn handleEvent(self: *HelloWidget, event: tui.Event) tui.EventResult {
        _ = self;
        if (event == .key) {
            if (event.key.modifiers.ctrl and event.key.key == .char) {
                if (event.key.key.char == 'c') {
                    return .quit;
                }
            }
        }
        return .ignored;
    }
};
```

### Interactive Counter

```zig
const std = @import("std");
const tui = @import("tui");

const Counter = struct {
    count: i32 = 0,

    pub fn render(self: *Counter, ctx: *tui.RenderContext) void {
        var screen = ctx.getSubScreen();
        screen.clear();

        // Display count
        var buf: [32]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "Count: {d}", .{self.count}) catch "?";

        screen.setStyle(tui.Style.default.setFg(tui.Color.cyan).bold());
        screen.moveCursor(2, 2);
        screen.putString(text);

        // Instructions
        screen.setStyle(tui.Style.default.dim());
        screen.moveCursor(2, 4);
        screen.putString("Up/Down to change, Ctrl+C to quit");
    }
    pub fn handleEvent(self: *Counter, event: tui.Event) tui.EventResult {
        switch (event) {
            .key => |k| switch (k.key) {
                .up => { self.count += 1; return .needs_redraw; },
                .down => { self.count -= 1; return .needs_redraw; },
                else => {},
            },
            else => {},
        }
        return .ignored;
    }
};

pub fn main() !void {
    var app = try tui.App.init(.{});
    defer app.deinit();

    var counter = Counter{};
    try app.setRoot(&counter);
    try app.run();
}
```


---

## Testing

```bash
# Run all tests
zig build test

# Run with verbose output
zig build test -- --verbose
```

---

## Documentation

Full documentation is available at [muhammad-fiaz.github.io/tui.zig](https://muhammad-fiaz.github.io/tui.zig/)

- **[Getting Started](https://muhammad-fiaz.github.io/tui.zig/guide/getting-started)** - Installation and first app
- **[Widgets](https://muhammad-fiaz.github.io/tui.zig/guide/widgets)** - Built-in widget reference
- **[Styling](https://muhammad-fiaz.github.io/tui.zig/guide/styling)** - Colors, themes, and styling
- **[Layout](https://muhammad-fiaz.github.io/tui.zig/guide/layout)** - Layout system guide
- **[Events](https://muhammad-fiaz.github.io/tui.zig/guide/events)** - Event handling
- **[API Reference](https://muhammad-fiaz.github.io/tui.zig/api/)** - Complete API docs

---

## Contributing

Contributions are welcome! Please see our [Contributing Guide](https://muhammad-fiaz.github.io/tui.zig/contributing) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Support

If you find TUI.zig useful, consider:

- Starring the repository
- Reporting bugs or suggesting features
- Improving documentation
- [Sponsoring development](https://pay.muhammadfiaz.com)

---

<div align="center">
<p>Made with care by <a href="https://github.com/muhammad-fiaz">Muhammad Fiaz</a></p>
</div>
