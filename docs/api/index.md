# API Reference

Complete API documentation for TUI.zig.

## Core Modules

### Application
- [`App`](/api/app) - Main application runner
- [`AppConfig`](/api/app#appconfig) - Application configuration

### Rendering
- [`Screen`](/api/screen) - Screen buffer management
- [`Renderer`](/api/renderer) - Diff-based rendering engine
- [`Cell`](/api/cell) - Cell representation

### Styling
- [`Style`](/api/style) - Text styling
- [`Color`](/api/color) - Color system
- [`Theme`](/api/theme) - Theme management

### Events
- [`Event`](/api/event) - Event types
- [`EventResult`](/api/event#eventresult) - Event handling results
- [`InputReader`](/api/event#inputreader) - Input parsing

### Layout
- [`Rect`](/api/layout#rect) - Rectangle bounds
- [`FlexRow`](/api/layout#flexrow) - Horizontal flex layout
- [`FlexColumn`](/api/layout#flexcolumn) - Vertical flex layout
- [`Grid`](/api/layout#grid) - Grid layout
- [`Stack`](/api/layout#stack) - Stack layout

### Animation
- [`Animation`](/api/animation) - Generic animation
- [`Easing`](/api/animation#easing) - Easing functions
- [`Timer`](/api/animation#timer) - Timer system
- [`FpsCounter`](/api/animation#fpscounter) - FPS tracking

## Widgets

### Form Widgets
```zig
tui.InputField      // Single-line text input
tui.TextArea        // Multi-line text editor
tui.Checkbox        // Boolean checkbox
tui.RadioGroup      // Radio button group
tui.Switch          // Toggle switch
tui.Slider          // Numeric slider
tui.Button          // Clickable button
```

### Display Widgets
```zig
tui.Text            // Static/dynamic text
tui.Badge           // Label badge
tui.Card            // Content card
tui.Table           // Data table
tui.ListView        // Scrollable list
tui.TreeView        // Hierarchical tree
tui.Image           // Image display
```

### Navigation Widgets
```zig
tui.Navbar          // Top navigation bar
tui.Sidebar         // Side navigation panel
tui.Breadcrumb      // Breadcrumb trail
tui.Tabs            // Tabbed interface
tui.Menu            // Dropdown menu
tui.Pagination      // Page navigation
```

### Feedback Widgets
```zig
tui.Alert           // Alert message
tui.AlertDialog     // Confirmation dialog
tui.Toast           // Toast notification
tui.Tooltip         // Contextual tooltip
tui.Modal           // Modal overlay
tui.ProgressBar     // Progress indicator
tui.Spinner         // Loading spinner
tui.Skeleton        // Loading placeholder
```

### Layout Widgets
```zig
tui.Grid            // Grid layout
tui.Accordion       // Collapsible sections
tui.SplitView       // Split panes
tui.ScrollView      // Scrollable container
tui.Separator       // Visual separator
tui.Statusbar       // Status bar
```

## Quick Reference

### Creating an App

```zig
var app = try tui.App.init(.{
    .theme = tui.Theme.dracula,
    .alternate_screen = true,
    .hide_cursor = true,
    .enable_mouse = true,
    .target_fps = 60,
});
defer app.deinit();
```

### Widget Pattern

```zig
const MyWidget = struct {
    pub fn render(self: *MyWidget, ctx: *tui.RenderContext) void {
        var screen = ctx.getSubScreen();
        // Render logic
    }

    pub fn handleEvent(self: *MyWidget, event: tui.Event) tui.EventResult {
        // Event handling
        return .ignored;
    }
};
```

### Styling

```zig
const style = tui.Style.default
    .setFg(tui.Color.cyan)
    .setBg(tui.Color.black)
    .bold()
    .underline();

screen.setStyle(style);
```

### Colors

```zig
// Named colors
tui.Color.red
tui.Color.green
tui.Color.blue

// RGB colors
tui.Color.fromRGB(255, 100, 50)

// Hex colors
tui.Color.hex(0xFF6432)

// 256-color palette
tui.Color{ .palette = 196 }
```

### Events

```zig
pub fn handleEvent(self: *Widget, event: tui.Event) tui.EventResult {
    switch (event) {
        .key => |k| {
            switch (k.key) {
                .char => |c| {
                    // Handle character
                },
                .up, .down, .left, .right => {
                    // Handle arrows
                },
                .enter => {
                    // Handle enter
                },
                else => {},
            }
        },
        .mouse => |m| {
            // Handle mouse
        },
        .resize => |r| {
            // Handle resize
        },
        else => {},
    }
    return .ignored;
}
```

### Layouts

```zig
// Flex layout
var row = tui.FlexRow.init(&widgets);
var column = tui.FlexColumn.init(&widgets);

// Grid layout
var grid = tui.Grid.init(3, 3);
const cell_bounds = grid.getCellBounds(.{ .row = 0, .col = 0 }, width, height);

// Stack layout
var stack = tui.Stack.init().withAlignment(.center);
const aligned = stack.alignChild(child_w, child_h, container_w, container_h);
```

### Animations

```zig
// Create animation
var anim = tui.animation.Animation(f32).init(0.0, 100.0, 1000)
    .withEasing(tui.animation.Easing.easeInOutBounce)
    .loopForever()
    .withAlternate();

// Start and update
anim.start();
anim.update(delta_ms);
const value = anim.getValue();
```

## Type Definitions

### EventResult

```zig
pub const EventResult = enum {
    ignored,        // Event not handled
    consumed,       // Event handled, stop propagation
    needs_redraw,   // Request screen redraw
    request_focus,  // Request focus
    yield_focus,    // Release focus
};
```

### AnimationState

```zig
pub const AnimationState = enum {
    idle,
    running,
    paused,
    completed,
};
```

### BorderStyle

```zig
pub const BorderStyle = enum {
    none,
    single,
    double,
    rounded,
    thick,
    ascii,
};
```

## Constants

```zig
// Version
pub const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };
pub const version_string = "0.1.0";
```

## Utilities

### Unicode

```zig
// String width calculation
const width = tui.unicode.stringWidth("Hello 世界");

// Grapheme iteration
var iter = tui.unicode.graphemeIterator(text);
while (iter.next()) |grapheme| {
    // Process grapheme
}
```

### Platform

```zig
// Platform detection
const is_windows = tui.platform.isWindows();
const is_unix = tui.platform.isUnix();
```

## Error Handling

```zig
// Common errors
pub const Error = error{
    TerminalError,
    RenderError,
    InputError,
    AllocationError,
};
```

## Best Practices

1. **Always defer deinit**
   ```zig
   var app = try tui.App.init(.{});
   defer app.deinit();
   ```

2. **Use child contexts for positioning**
   ```zig
   const rect = tui.Rect{ .x = 10, .y = 5, .width = 30, .height = 10 };
   var child_ctx = ctx.child(rect);
   widget.render(&child_ctx);
   ```

3. **Return appropriate EventResult**
   ```zig
   if (state_changed) {
       return .needs_redraw;
   }
   return .ignored;
   ```

4. **Handle allocations properly**
   ```zig
   var widget = tui.InputField.init(allocator);
   defer widget.deinit();
   ```

## See Also

- [Getting Started Guide](/guide/getting-started)
- [Widget Reference](/guide/widgets)
- [Layout Guide](/guide/layout)
- [Animation Guide](/guide/animation)
