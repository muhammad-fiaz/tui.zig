# App

The `App` struct is the core of TUI.zig applications, managing the terminal interface, event loop, rendering pipeline, and widget lifecycle.

## Overview

The application provides:
- Terminal initialization and management
- Event processing and input handling
- Rendering coordination
- Frame timing and FPS control
- Widget management

## Exported Types

### Screen

```zig
pub const Screen = screen_mod.Screen;
```

Screen buffer for rendering. See [Screen API](screen.md).

### Renderer

```zig
pub const Renderer = renderer_mod.Renderer;
```

Terminal renderer. See [Renderer API](screen.md).

### Terminal

```zig
pub const Terminal = terminal.Terminal;
```

Terminal interface. See [Terminal API](screen.md).

### Event

```zig
pub const Event = events.Event;
```

Input events. See [Event API](event.md).

### Theme

```zig
pub const Theme = theme_mod.Theme;
```

Color and style themes. See [Theme API](style.md).

### RenderContext

```zig
pub const RenderContext = widget.RenderContext;
```

Rendering context passed to widgets. See [Widget API](widget.md).

## AppConfig

Configuration structure for application initialization.

### Fields

- `theme: Theme` - Initial theme (default: `Theme.default_theme`)
- `alternate_screen: bool` - Use alternate screen buffer (default: `true`)
- `hide_cursor: bool` - Hide terminal cursor (default: `true`)
- `enable_mouse: bool` - Enable mouse input (default: `true`)
- `enable_paste: bool` - Enable bracketed paste (default: `true`)
- `enable_focus: bool` - Enable focus events (default: `true`)
- `target_fps: u16` - Target frames per second (default: `60`)
- `tick_rate_ms: u16` - Animation tick rate in milliseconds (default: `16`)
- `poll_timeout_ms: u16` - Input poll timeout in milliseconds (default: `10`)

## AppState

Enumeration representing the application's current state.

### Values

- `uninitialized` - Not yet initialized
- `running` - Main loop is active
- `paused` - Temporarily paused
- `stopping` - In the process of shutting down
- `stopped` - Fully stopped

## App

Main application structure.

### Fields

- `allocator: std.mem.Allocator` - Memory allocator
- `config: AppConfig` - Application configuration
- `term: ?Terminal` - Terminal handler
- `screen: ?Screen` - Screen buffer
- `renderer: ?Renderer` - Renderer instance
- `theme: Theme` - Current theme
- `state: AppState` - Current application state
- `root: ?*anyopaque` - Type-erased root widget pointer
- `root_render_fn: ?*const fn (*anyopaque, *RenderContext) void` - Root widget render function
- `root_event_fn: ?*const fn (*anyopaque, Event) widget.EventResult` - Root widget event handler
- `input_reader: input.InputReader` - Input parsing
- `event_queue: events.EventQueue` - Event queue
- `start_time_ns: i128` - Application start time
- `last_frame_ns: i128` - Last frame timestamp
- `tick_count: u64` - Frame counter
- `fps_counter: animation.FpsCounter` - FPS tracking
- `should_quit: bool` - Quit flag
- `needs_redraw: bool` - Redraw flag

### Methods

#### init

```zig
pub fn init(config: AppConfig) !App
```

Creates a new application with the page allocator.

**Parameters:**
- `config: AppConfig` - Application configuration

**Returns:** New App instance

#### initWithAllocator

```zig
pub fn initWithAllocator(allocator: std.mem.Allocator, config: AppConfig) !App
```

Creates a new application with a custom allocator.

**Parameters:**
- `allocator: std.mem.Allocator` - Memory allocator
- `config: AppConfig` - Application configuration

**Returns:** New App instance

#### deinit

```zig
pub fn deinit(self: *App) void
```

Cleans up application resources and shuts down the terminal.

#### setRoot

```zig
pub fn setRoot(self: *App, root_ptr: anytype) !void
```

Sets the root widget for the application.

**Parameters:**
- `root_ptr: anytype` - Pointer to the root widget

The widget must have `render` and optionally `handleEvent` methods.

#### setTheme

```zig
pub fn setTheme(self: *App, theme: Theme) void
```

Updates the application's theme.

**Parameters:**
- `theme: Theme` - New theme to apply

#### quit

```zig
pub fn quit(self: *App) void
```

Requests the application to quit at the end of the current frame.

#### requestRedraw

```zig
pub fn requestRedraw(self: *App) void
```

Requests a redraw on the next frame.

#### run

```zig
pub fn run(self: *App) !void
```

Starts the main application loop.

#### getFps

```zig
pub fn getFps(self: *App) f32
```

Gets the current frames per second.

**Returns:** Current FPS

#### getElapsedTime

```zig
pub fn getElapsedTime(self: *App) u64
```

Gets elapsed time since application start in milliseconds.

**Returns:** Elapsed time in milliseconds

#### getTickCount

```zig
pub fn getTickCount(self: *App) u64
```

Gets the total number of ticks (frames) processed.

**Returns:** Tick count

#### getScreenSize

```zig
pub fn getScreenSize(self: *App) struct { width: u16, height: u16 }
```

Gets the current screen dimensions.

**Returns:** Struct with width and height

## Utility Functions

### run

```zig
pub fn run(comptime RootWidget: type, initial_state: RootWidget) !void
```

Simple runner for quick applications with default configuration.

**Parameters:**
- `RootWidget: type` - Root widget type
- `initial_state: RootWidget` - Initial widget state

## Usage Examples

### Basic Application

```zig
const tui = @import("tui");

pub fn main() !void {
    var app = try tui.App.init(.{
        .target_fps = 30,
        .enable_mouse = false,
    });
    defer app.deinit();

    var root_widget = MyWidget{};
    try app.setRoot(&root_widget);
    try app.run();
}
```

### Custom Configuration

```zig
const config = tui.AppConfig{
    .theme = my_custom_theme,
    .alternate_screen = false,
    .target_fps = 60,
    .tick_rate_ms = 16,
};

var app = try tui.App.init(config);
```

### Simple Runner

```zig
const MyWidget = struct {
    pub fn render(self: *MyWidget, ctx: *tui.RenderContext) void {
        // Render logic
    }
};

pub fn main() !void {
    try tui.run(MyWidget, MyWidget{});
}
```

## Event Handling

The application automatically handles:
- Keyboard input (Ctrl+C/Ctrl+Q to quit)
- Terminal resize events
- Mouse events (if enabled)
- Focus events (if enabled)

Events are passed to the root widget's `handleEvent` method if it exists.

## Lifecycle

1. Create app with `App.init()` or `App.initWithAllocator()`
2. Set root widget with `setRoot()`
3. Call `run()` to start the main loop
4. Application handles setup, event processing, and rendering
5. Call `deinit()` when done

## See Also

- [Application Guide](../guide/application.md)
- [Widget API](widget.md)
- [Event API](event.md)
- Source: `src/app.zig`