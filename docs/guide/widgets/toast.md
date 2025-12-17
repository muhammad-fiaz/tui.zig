# Toast Widget

## Overview

The `Toast` widget displays temporary notification messages that auto-dismiss after a timeout. It supports different types (info, success, warning, error) and positions with smooth animations.

## Properties

- `message`: The notification message text
- `toast_type`: Type of toast (`.info`, `.success`, `.warning`, `.error_toast`)
- `position`: Screen position (`.top_left`, `.top_center`, `.top_right`, `.bottom_left`, `.bottom_center`, `.bottom_right`)
- `visible`: Whether the toast is currently visible
- `duration_ms`: Display duration in milliseconds
- `elapsed_ms`: Time elapsed since showing
- `base`: Base widget state

## Methods

- `init(message: []const u8)`: Creates a new toast with the given message
- `withType(toast_type: ToastType)`: Sets the toast type
- `withPosition(position: ToastPosition)`: Sets the display position
- `withDuration(duration_ms: u32)`: Sets the display duration
- `show()`: Shows the toast
- `hide()`: Hides the toast
- `update(delta_ms: u32)`: Updates the toast state for auto-dismiss
- `render(ctx: *RenderContext)`: Renders the toast with icon and progress bar

## Events

None - this widget is not interactive.

## Examples

### Basic Info Toast

```zig
const tui = @import("tui");
const Toast = tui.widgets.Toast;

var toast = Toast.init("Operation completed successfully")
    .withType(.success)
    .withDuration(3000);

toast.show();
```

### Error Toast

```zig
var toast = Toast.init("Failed to save file")
    .withType(.error_toast)
    .withPosition(.top_right);

toast.show();
```

### Toast Manager

```zig
const ToastManager = tui.widgets.ToastManager;

var manager = ToastManager.init(allocator);
defer manager.deinit();

var toast = Toast.init("Message").withType(.info);
try manager.show(toast);

// In main loop:
manager.update(16); // Update with delta time
manager.render(ctx);
```