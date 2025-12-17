# Alert Widget

## Overview

The `Alert` widget displays important messages with different severity levels (info, success, warning, error). It supports dismissible alerts and can be styled based on the alert type. The `AlertDialog` provides a modal dialog for confirmations and user interactions. Both widgets are designed for drawing user attention to critical information or requiring user acknowledgment.

## Alert Widget

### Properties

- `title`: The alert title text displayed prominently
- `message`: The main alert message content (supports multi-line text)
- `alert_type`: `AlertType` enum (`.info`, `.success`, `.warning`, `.error_alert`) - determines color scheme and icon
- `dismissible`: Boolean indicating if the alert can be dismissed by the user
- `visible`: Boolean controlling alert visibility (can be used for show/hide animations)
- `on_dismiss`: Optional callback function called when the alert is dismissed
- `style`: Base style configuration (colors are overridden by alert type)

### Methods

- `init(title: []const u8, message: []const u8)`: Creates a new alert with title and message
- `withType(alert_type: AlertType)`: Sets the alert type (info, success, warning, error)
- `withDismissible(dismissible: bool)`: Enables or disables dismissal functionality
- `withOnDismiss(callback: *const fn () void)`: Sets the dismiss callback function
- `render(ctx: *RenderContext)`: Renders the alert with appropriate colors and layout
- `handleEvent(event: Event)`: Handles keyboard events for dismissal
- `dismiss()`: Programmatically dismisses the alert (calls callback if set)
- `show()`: Shows the alert (sets visible to true)

### Events

- **Dismiss**: `Escape` key or `x`/`X` key to dismiss (if dismissible)
- **Dismiss Callback**: Triggered when alert is dismissed

## AlertDialog Widget

### Properties

- `title`: Dialog title displayed in the header
- `message`: Dialog message content
- `confirm_text`: Text for the confirm button (default "OK")
- `cancel_text`: Text for the cancel button (default "Cancel")
- `visible`: Boolean controlling dialog visibility
- `on_confirm`: Optional callback for confirm button action
- `on_cancel`: Optional callback for cancel button action
- `focused_button`: Index of currently focused button (0 for confirm, 1 for cancel)
- `style`: Base style configuration

### Methods

- `init(title: []const u8, message: []const u8)`: Creates a new dialog with title and message
- `show()`: Shows the dialog (sets visible to true)
- `hide()`: Hides the dialog (sets visible to false)
- `render(ctx: *RenderContext)`: Renders the modal dialog with overlay and buttons
- `handleEvent(event: Event)`: Handles keyboard navigation and button selection

### Events

- **Navigation**: `Left`/`Right` arrows or `Tab` to switch between buttons
- **Confirm**: `Enter` key on confirm button
- **Cancel**: `Escape` key or `Enter` on cancel button
- **Confirm Callback**: Triggered when confirm button is pressed
- **Cancel Callback**: Triggered when cancel button is pressed

## Alert Types

- **Info** (ℹ): Blue color scheme for general information
- **Success** (✓): Green color scheme for positive outcomes
- **Warning** (⚠): Yellow/Orange color scheme for cautionary messages
- **Error** (✗): Red color scheme for error conditions

## Usage Examples

### Basic Alert Display

```zig
const tui = @import("tui");
const Alert = tui.widgets.Alert;

var successAlert = Alert.init("Operation Complete", "Your data has been saved successfully.")
    .withType(.success)
    .withDismissible(true);
```

### Error Alert with Callback

```zig
fn onAlertDismiss() void {
    std.debug.print("User dismissed the error alert\n", .{});
    // Clean up error state or show next step
}

var errorAlert = Alert.init("Connection Failed", "Unable to connect to the server.\nPlease check your network connection.")
    .withType(.error_alert)
    .withDismissible(true)
    .withOnDismiss(onAlertDismiss);
```

### Warning Alert (Non-dismissible)

```zig
var warningAlert = Alert.init("System Maintenance", "The system will be unavailable for maintenance\nfrom 2:00 AM to 4:00 AM EST.")
    .withType(.warning);
// Note: dismissible defaults to false
```

### Confirmation Dialog

```zig
const AlertDialog = tui.widgets.AlertDialog;

fn onConfirmDelete() void {
    std.debug.print("User confirmed deletion\n", .{});
    performDeletion();
}

fn onCancelDelete() void {
    std.debug.print("User cancelled deletion\n", .{});
}

var deleteDialog = AlertDialog.init(
    "Confirm Deletion",
    "Are you sure you want to delete this item?\nThis action cannot be undone."
);

deleteDialog.on_confirm = onConfirmDelete;
deleteDialog.on_cancel = onCancelDelete;
deleteDialog.show();
```

### Custom Button Text

```zig
var customDialog = AlertDialog.init("Save Changes", "You have unsaved changes. Save before exiting?")
    .withConfirmText("Save")
    .withCancelText("Discard");
```

### Alert Management in Application

```zig
const AlertManager = struct {
    alerts: std.ArrayList(Alert),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) AlertManager {
        return .{
            .alerts = std.ArrayList(Alert).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn showAlert(self: *AlertManager, alert: Alert) !void {
        try self.alerts.append(alert);
    }
    
    pub fn dismissAlert(self: *AlertManager, index: usize) void {
        if (index < self.alerts.items.len) {
            self.alerts.items[index].dismiss();
        }
    }
    
    pub fn renderAll(self: *AlertManager, ctx: *RenderContext) void {
        var y_offset: u16 = 0;
        for (self.alerts.items) |*alert| {
            if (alert.visible) {
                // Create sub-context for each alert
                var alert_ctx = ctx.child(Rect.init(0, y_offset, ctx.bounds.width, 5));
                alert.render(&alert_ctx);
                y_offset += 5;
            }
        }
    }
};
```

## Styling and Theming

Alerts use predefined color schemes based on type, but can be customized:

```zig
// Custom styling (colors will still be overridden by alert type)
var customAlert = Alert.init("Custom Alert", "This alert has custom styling")
    .withType(.info);

customAlert.style = Style.default.bold();
```

Dialog styling:

```zig
var styledDialog = AlertDialog.init("Styled Dialog", "This dialog has custom appearance");
styledDialog.style = Style.default.setFg(Color.magenta);
```

## Best Practices

- Use appropriate alert types for semantic meaning
- Keep messages concise and actionable
- Provide clear titles that summarize the issue
- Use dismissible alerts for non-critical information
- Use dialogs for actions requiring user confirmation
- Consider accessibility: ensure color isn't the only indicator of severity
- Test keyboard navigation for dialog interactions

### AlertDialog
- **Navigation**: Left/Right/Tab to switch between buttons
- **Confirm**: Enter on confirm button
- **Cancel**: Enter on cancel button or Escape

## Examples

### Basic Alert

```zig
const tui = @import("tui");
const Alert = tui.widgets.Alert;

var alert = Alert.init("Warning", "This is a warning message")
    .withType(.warning)
    .withDismissible(true);
```

### Error Alert with Callback

```zig
fn onDismiss() void {
    std.debug.print("Alert dismissed\n", .{});
}

var errorAlert = Alert.init("Error", "Something went wrong")
    .withType(.error_alert)
    .withOnDismiss(onDismiss);
```

### Alert Dialog

```zig
const AlertDialog = tui.widgets.AlertDialog;

fn onConfirm() void {
    std.debug.print("Confirmed!\n", .{});
}

fn onCancel() void {
    std.debug.print("Cancelled\n", .{});
}

var dialog = AlertDialog.init("Confirm", "Are you sure?")
    .withOnConfirm(onConfirm)
    .withOnCancel(onCancel);
dialog.show();
```