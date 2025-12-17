---
layout: home

hero:
  name: TUI.zig
  text: Modern Terminal UI Framework
  tagline: Build beautiful, performant terminal applications with Zig
  image:
    src: /logo.svg
    alt: TUI.zig
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: View on GitHub
      link: https://github.com/muhammad-fiaz/tui.zig

features:
  - icon: 🎨
    title: 36+ Widgets
    details: Complete widget library including forms, navigation, feedback, and data display components
  
  - icon: ⚡
    title: High Performance
    details: Diff-based rendering, double buffering, and 60 FPS target for smooth animations
  
  - icon: 🎭
    title: 30+ Animations
    details: Comprehensive easing functions including bounce, elastic, and back animations
  
  - icon: 📐
    title: 8 Layout Systems
    details: Flex, Grid, Stack, Absolute positioning and more for any design
  
  - icon: 🎨
    title: 6 Built-in Themes
    details: Default, Dark, Light, Nord, Dracula, and Gruvbox themes ready to use
  
  - icon: 🖼️
    title: Image Support
    details: Kitty, iTerm2, Sixel protocols with ASCII fallback
  
  - icon: 🌍
    title: Cross-Platform
    details: Linux, macOS, Windows with full Unicode and CJK support
  
  - icon: 🔒
    title: Type-Safe
    details: Pure Zig implementation with zero-cost abstractions
  
  - icon: 🧪
    title: Fully Tested
    details: Comprehensive test coverage for all components
---

## Quick Example

```zig
const tui = @import("tui");

pub fn main() !void {
    var app = try tui.App.init(.{});
    defer app.deinit();

    var widget = MyWidget{};
    try app.setRoot(&widget);
    try app.run();
}

const MyWidget = struct {
    count: i32 = 0,

    pub fn render(self: *MyWidget, ctx: *tui.RenderContext) void {
        var screen = ctx.getSubScreen();
        
        var buf: [32]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "Count: {d}", .{self.count}) catch "?";
        
        screen.moveCursor(10, 10);
        screen.setStyle(tui.Style.default.bold().setFg(tui.Color.cyan));
        screen.putString(text);
    }

    pub fn handleEvent(self: *MyWidget, event: tui.Event) tui.EventResult {
        if (event == .key) {
            switch (event.key.key) {
                .up => {
                    self.count += 1;
                    return .needs_redraw;
                },
                .down => {
                    self.count -= 1;
                    return .needs_redraw;
                },
                else => {},
            }
        }
        return .ignored;
    }
};
```

## Features at a Glance

### Complete Widget Library
- **Forms**: InputField, TextArea, Checkbox, RadioGroup, Switch, Slider
- **Navigation**: Navbar, Sidebar, Breadcrumb, Tabs, Menu, Pagination
- **Feedback**: Alert, Toast, Modal, Progress, Spinner, Skeleton
- **Display**: Text, Badge, Card, Table, ListView, TreeView, Image
- **Layout**: Grid, Accordion, SplitView, ScrollView, Separator

### Advanced Animation System
- 30+ easing functions (Linear, Quad, Cubic, Sine, Expo, Circ, Back, Elastic, Bounce)
- Generic Animation<T> for any type
- Loop and alternate modes
- Animation groups and timers

### Flexible Layout Engine
- FlexRow/FlexColumn for responsive layouts
- Grid for structured designs
- Stack for overlays
- Absolute positioning
- Box model with padding/margin

### Rich Styling
- True color (24-bit RGB)
- 256-color palette
- 16 ANSI colors
- Bold, italic, underline, dim, reverse
- 6 built-in themes

## Why TUI.zig?

- **Production Ready**: 36 widgets, comprehensive features, full test coverage
- **High Performance**: Diff-based rendering, minimal allocations, 60 FPS
- **Developer Friendly**: Simple API, type-safe, composable
- **Cross-Platform**: Linux, macOS, Windows support
- **Zero Dependencies**: Pure Zig implementation
- **Well Documented**: Complete guides and API reference

## Installation

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/tui.zig.git
```

Add to your `build.zig`:

```zig
const tui_dep = b.dependency("tui", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("tui", tui_dep.module("tui"));
```

## Community

- [GitHub Repository](https://github.com/muhammad-fiaz/tui.zig)
- [Issue Tracker](https://github.com/muhammad-fiaz/tui.zig/issues)
- [Discussions](https://github.com/muhammad-fiaz/tui.zig/discussions)

## License

MIT License - see [LICENSE](https://github.com/muhammad-fiaz/tui.zig/blob/main/LICENSE)
