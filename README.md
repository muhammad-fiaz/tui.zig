<div align="center">


# TUI.zig

<a href="https://muhammad-fiaz.github.io/tui.zig/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io-blue" alt="Documentation"></a>
<a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.15.0+-orange.svg?logo=zig" alt="Zig Version"></a>
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
<a href="https://github.com/sponsors/muhammad-fiaz"><img src="https://img.shields.io/badge/Sponsor-💖-pink?style=social&logo=github" alt="GitHub Sponsors"></a>
<a href="https://hits.sh/github.com/muhammad-fiaz/tui.zig/"><img src="https://hits.sh/github.com/muhammad-fiaz/tui.zig.svg?label=Visitors&extraCount=0&color=green" alt="Repo Visitors"></a>

<p><em>A modern, feature-rich Terminal User Interface library for Zig</em></p>

<b>📚 <a href="https://muhammad-fiaz.github.io/tui.zig/">Documentation</a> |
<a href="https://muhammad-fiaz.github.io/tui.zig/api/">API Reference</a> |
<a href="https://muhammad-fiaz.github.io/tui.zig/guide/getting-started">Quick Start</a> |
<a href="https://muhammad-fiaz.github.io/tui.zig/contributing">Contributing</a></b>

</div>

---
TUI.zig is a Modern and easy-to-use Terminal User Interface (TUI) library for the Zig programming language. It provides a rich set of features to create modern, responsive, and visually appealing terminal applications with minimal effort.

> ⚠️ **Note:** TUI.zig is under active development. so expect frequent updates and improvements.

## ✨ Features

TUI.zig provides a comprehensive Terminal User Interface library with cross-platform support:

### 🎨 Rendering & Display

- **True Color (24-bit RGB)** - Full spectrum color support
- **256 Color Palette** - Fallback for older terminals
- **16 ANSI Colors** - Universal compatibility
- **Double Buffering** - Flicker-free rendering
- **Diff-Based Updates** - Only redraw changed cells
- **Unicode Support** - Full grapheme cluster handling
- **Wide Character Support** - CJK and emoji rendering

### 🖱️ Input Handling

- **Keyboard Events** - Full key detection with modifiers
- **Mouse Support** - Click, drag, scroll, and hover
- **Bracketed Paste** - Safe paste mode
- **Focus Events** - Window focus detection
- **Raw Mode** - Direct terminal control

### 🧩 Widget System

- **Text** - Styled text with alignment and wrapping
- **Button** - Clickable buttons with hover states
- **Input Field** - Single-line text input with cursor
- **Text Area** - Multi-line text editing
- **Checkbox** - Toggle checkboxes
- **Radio Button** - Single selection groups
- **Progress Bar** - Visual progress indicators
- **Spinner** - Animated loading indicators
- **List View** - Scrollable item lists
- **Table** - Data tables with columns
- **Tabs** - Tabbed navigation
- **Modal** - Dialog overlays
- **Scroll View** - Scrollable containers
- **Split View** - Resizable panes
- more...

### 🎭 Styling & Themes

- **Rich Text Styling** - Bold, italic, underline, strikethrough
- **Built-in Themes** - Default, Dark, Light, Nord, Dracula, Gruvbox
- **Custom Themes** - Create your own color schemes
- **Border Styles** - Single, double, rounded, thick, ASCII

### 📐 Layout System

- **Flex Layout** - Flexible row/column layouts
- **Box Model** - Padding, margin, borders
- **Constraints** - Min/max sizing
- **Alignment** - Start, center, end, stretch

### 🎬 Animation

- **Easing Functions** - Linear, ease-in, ease-out, bounce, elastic
- **Tween Animations** - Smooth value interpolation
- **Timer System** - Scheduled callbacks
- **FPS Counter** - Performance monitoring

### 🌍 Cross-Platform

- **Linux** - Full terminal support
- **macOS** - Native terminal integration
- **Windows** - Console API support
- **BSD/Unix** - POSIX compatibility

---

## 🚀 Quick Start

### Installation

Add TUI.zig to your project using Zig's package manager:

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
        const msg = "Hello, TUI.zig! 🚀";
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
        screen.putString("↑/↓ to change, Ctrl+C to quit");
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

## 🧪 Testing

```bash
# Run all tests
zig build test

# Run with verbose output
zig build test -- --verbose
```

---

## 📖 Documentation

Full documentation is available at [muhammad-fiaz.github.io/tui.zig](https://muhammad-fiaz.github.io/tui.zig/)

- **[Getting Started](https://muhammad-fiaz.github.io/tui.zig/guide/getting-started)** - Installation and first app
- **[Widgets](https://muhammad-fiaz.github.io/tui.zig/guide/widgets)** - Built-in widget reference
- **[Styling](https://muhammad-fiaz.github.io/tui.zig/guide/styling)** - Colors, themes, and styling
- **[Layout](https://muhammad-fiaz.github.io/tui.zig/guide/layout)** - Layout system guide
- **[Events](https://muhammad-fiaz.github.io/tui.zig/guide/events)** - Event handling
- **[API Reference](https://muhammad-fiaz.github.io/tui.zig/api/)** - Complete API docs

---

## 🤝 Contributing

Contributions are welcome! Please see our [Contributing Guide](https://muhammad-fiaz.github.io/tui.zig/contributing) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 💖 Support

If you find TUI.zig useful, consider:

- ⭐ Starring the repository
- 🐛 Reporting bugs or suggesting features
- 📖 Improving documentation
- 💰 [Sponsoring development](https://pay.muhammadfiaz.com)

---

<div align="center">
<p>Made with ❤️ by <a href="https://github.com/muhammad-fiaz">Muhammad Fiaz</a></p>
</div>
