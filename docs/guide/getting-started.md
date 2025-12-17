# Getting Started

Get up and running with TUI.zig in minutes.

## Installation

### Using Zig Package Manager

Add TUI.zig to your project:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/tui.zig.git
```

### Configure build.zig

Add the dependency to your `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "my-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add TUI.zig dependency
    const tui_dep = b.dependency("tui", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("tui", tui_dep.module("tui"));

    b.installArtifact(exe);
}
```

## Hello World

Create your first TUI application:

```zig
const std = @import("std");
const tui = @import("tui");

pub fn main() !void {
    var app = try tui.App.init(.{});
    defer app.deinit();

    var hello = HelloWorld{};
    try app.setRoot(&hello);
    try app.run();
}

const HelloWorld = struct {
    pub fn render(self: *HelloWorld, ctx: *tui.RenderContext) void {
        _ = self;
        var screen = ctx.getSubScreen();
        
        const msg = "Hello, TUI.zig!";
        const x = (screen.width -| 18) / 2;
        const y = screen.height / 2;
        
        screen.setStyle(tui.Style.default.bold().setFg(tui.Color.cyan));
        screen.moveCursor(x, y);
        screen.putString(msg);
    }

    pub fn handleEvent(self: *HelloWorld, event: tui.Event) tui.EventResult {
        _ = self;
        _ = event;
        return .ignored;
    }
};
```

Build and run:

```bash
zig build run
```

Press `Ctrl+C` to exit.

## Interactive Counter

Let's add interactivity:

```zig
const Counter = struct {
    count: i32 = 0,

    pub fn render(self: *Counter, ctx: *tui.RenderContext) void {
        var screen = ctx.getSubScreen();
        
        var buf: [32]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "Count: {d}", .{self.count}) catch "?";
        
        screen.moveCursor(10, 10);
        screen.setStyle(tui.Style.default.bold().setFg(tui.Color.green));
        screen.putString(text);
        
        screen.moveCursor(10, 12);
        screen.setStyle(tui.Style.default.dim());
        screen.putString("↑/↓ to change, Ctrl+C to quit");
    }

    pub fn handleEvent(self: *Counter, event: tui.Event) tui.EventResult {
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

## Using Widgets

TUI.zig provides 36+ ready-to-use widgets:

```zig
const FormDemo = struct {
    input: tui.InputField,
    checkbox: tui.Checkbox,
    slider: tui.Slider,

    pub fn init(allocator: std.mem.Allocator) FormDemo {
        return .{
            .input = tui.InputField.init(allocator)
                .withPlaceholder("Enter text..."),
            .checkbox = tui.Checkbox.init("Accept terms"),
            .slider = tui.Slider.init(0.0, 100.0),
        };
    }

    pub fn render(self: *FormDemo, ctx: *tui.RenderContext) void {
        // Render input
        const input_rect = tui.Rect{ .x = 5, .y = 5, .width = 30, .height = 1 };
        var input_ctx = ctx.child(input_rect);
        self.input.render(&input_ctx);
        
        // Render checkbox
        const check_rect = tui.Rect{ .x = 5, .y = 7, .width = 30, .height = 1 };
        var check_ctx = ctx.child(check_rect);
        self.checkbox.render(&check_ctx);
        
        // Render slider
        const slider_rect = tui.Rect{ .x = 5, .y = 9, .width = 30, .height = 2 };
        var slider_ctx = ctx.child(slider_rect);
        self.slider.render(&slider_ctx);
    }
};
```

## Application Layout

Create a complete application layout:

```zig
const App = struct {
    navbar: tui.Navbar,
    sidebar: tui.Sidebar,
    statusbar: tui.Statusbar,

    pub fn init() App {
        const nav_items = [_]tui.navbar.NavItem{
            .{ .label = "Home", .icon = "🏠" },
            .{ .label = "Settings", .icon = "⚙️" },
        };
        
        const sidebar_items = [_]tui.sidebar.SidebarItem{
            .{ .label = "Dashboard", .icon = "📊" },
            .{ .label = "Files", .icon = "📁" },
        };
        
        const status_items = [_]tui.statusbar.StatusItem{
            .{ .text = "Ready", .alignment = .left },
            .{ .text = "Line 1:1", .alignment = .right },
        };

        return .{
            .navbar = tui.Navbar.init(&nav_items).withTitle("My App"),
            .sidebar = tui.Sidebar.init(&sidebar_items),
            .statusbar = tui.Statusbar.init(&status_items),
        };
    }

    pub fn render(self: *App, ctx: *tui.RenderContext) void {
        var screen = ctx.getSubScreen();
        
        // Navbar at top
        const nav_rect = tui.Rect{ .x = 0, .y = 0, .width = screen.width, .height = 1 };
        var nav_ctx = ctx.child(nav_rect);
        self.navbar.render(&nav_ctx);
        
        // Sidebar on left
        const sidebar_rect = tui.Rect{ .x = 0, .y = 1, .width = 20, .height = screen.height - 2 };
        var sidebar_ctx = ctx.child(sidebar_rect);
        self.sidebar.render(&sidebar_ctx);
        
        // Statusbar at bottom
        const status_rect = tui.Rect{ .x = 0, .y = screen.height - 1, .width = screen.width, .height = 1 };
        var status_ctx = ctx.child(status_rect);
        self.statusbar.render(&status_ctx);
    }
};
```

## Next Steps

- [Learn about Widgets](/guide/widgets)
- [Explore Layouts](/guide/layout)
- [Add Animations](/guide/animation)
- [Customize Themes](/guide/themes)
- [Handle Events](/guide/events)

## Common Patterns

### Form with Validation

```zig
const validated_input = tui.InputField.init(allocator)
    .withPlaceholder("Email")
    .withMaxLength(100);

// Validate on change
if (!isValidEmail(validated_input.value.items)) {
    // Show error
}
```

### Animated Progress

```zig
var progress: f32 = 0.0;
var anim = tui.animation.Animation(f32).init(0.0, 1.0, 2000)
    .withEasing(tui.animation.Easing.easeInOutQuad);

anim.start();

// In update loop
anim.update(delta_ms);
progress = anim.getValue();
```

### Modal Dialog

```zig
var modal = tui.Modal.init(content_widget)
    .withTitle("Confirm")
    .withOnClose(handleClose);

modal.show();
```

## Tips

1. **Always handle Ctrl+C** - The framework does this by default
2. **Use child contexts** for widget positioning
3. **Return `.needs_redraw`** when state changes
4. **Test on different terminals** for color compatibility
5. **Use allocators properly** for dynamic widgets

## Troubleshooting

### Widget not showing?
- Check bounds are within screen dimensions
- Verify `render()` is being called
- Ensure widget is visible

### Events not working?
- Return `.needs_redraw` for state changes
- Check event isn't consumed by parent
- Verify widget has focus if needed

### Colors look wrong?
- Terminal may not support true color
- Try 256-color palette
- Check terminal settings

## Resources

- [Widget Reference](/guide/widgets)
- [API Documentation](/api/)
- [GitHub Repository](https://github.com/muhammad-fiaz/tui.zig)
