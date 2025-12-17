# Application

The `App` struct is the entry point for your TUI application. It manages the terminal, event loop, and rendering pipeline.

## Basic Layout

```zig
const std = @import("std");
const tui = @import("tui");

pub fn main() !void {
    // 1. Initialize App
    var app = try tui.App.init(.{});
    defer app.deinit();

    // 2. Setup your root widget
    var main_widget = MyWidget{};
    try app.setRoot(&main_widget);

    // 3. Run the event loop
    try app.run();
}
```

## Configuration

You can configure the application behaviors via `AppConfig`:

```zig
const app = try tui.App.init(.{
    // Use a specific theme
    .theme = tui.Theme.nord_theme,

    // Set custom FPS limit (default: 60)
    .target_fps = 30,

    // Custom input handling options
    .mouse_enabled = true,
});
```

## Event Loop

The `app.run()` method starts the main event loop which:

1. Polls for input events (keyboard, mouse, resize)
2. Dispatches events to the active widget
3. Updates animations
4. Renders the screen if dirtied
5. Sleeps to maintain target FPS

## Manual Control

You can also control the loop manually:

```zig
// Single iteration
try app.step();

// Force redraw
app.requestRedraw();

// Exit loop
app.quit();
```

## Root Widget

The root widget is the top-level component that receives all events and drawing commands. It usually contains layout containers (like `FlexColumn`) that organize other widgets.

```zig
var layout = tui.FlexColumn(.{
    tui.Header("My App"),
    tui.Center(tui.Text("Hello World")),
    tui.Footer("Press q to quit"),
});
try app.setRoot(&layout);
```
