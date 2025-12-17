# Widgets

TUI.zig provides a rich set of built-in widgets for building interactive terminal interfaces.

## Widget Basics

All widgets implement the same basic interface:

```zig
pub fn render(self: *Self, ctx: *RenderContext) void;
pub fn handleEvent(self: *Self, event: Event) EventResult;
```

## Built-in Widgets

### Text

Display styled text with alignment and wrapping:

```zig
const tui = @import("tui");

// Simple text
var text = tui.widgets.Text.init("Hello, World!");

// Styled text
var styled = tui.widgets.Text.init("Important!")
    .withStyle(tui.Style.default.setFg(tui.Color.red).bold())
    .withAlignment(.center);
```

### Button

Clickable buttons with hover and press states:

```zig
var button = tui.widgets.Button.init("Click Me!")
    .withOnClick(onButtonClick);

fn onButtonClick() void {
    // Button was clicked
}
```

### Input Field

Single-line text input with cursor:

```zig
var input = tui.widgets.InputField.init(allocator)
    .withPlaceholder("Enter your name...")
    .withMaxLength(50);

// Get the entered value
const value = input.getValue();
```

### Text Area

Multi-line text editing:

```zig
var textarea = tui.widgets.TextArea.init(allocator)
    .withLineNumbers()
    .withWordWrap();

// Set content
try textarea.setText("Line 1\nLine 2\nLine 3");
```

### Checkbox

Toggle checkboxes:

```zig
var checkbox = tui.widgets.Checkbox.init("Enable feature");

// Check state
if (checkbox.isChecked()) {
    // Feature is enabled
}
```

### Progress Bar

Visual progress indicators:

```zig
var progress = tui.widgets.Progress.init()
    .withLabel("Loading...")
    .withShowPercentage(true);

// Update progress (0.0 - 1.0)
progress.setValue(0.75);
```

### Spinner

Animated loading indicators:

```zig
var spinner = tui.widgets.Spinner.init(.dots)
    .withLabel("Processing...");

// In your render loop, update the animation
spinner.tick();
```

Available spinner styles:

- `.dots` - ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧
- `.line` - - \ | /
- `.circle` - ◐ ◓ ◑ ◒
- `.square` - ◰ ◳ ◲ ◱
- `.arrow` - ← ↖ ↑ ↗ → ↘ ↓ ↙

### List View

Scrollable item lists with selection:

```zig
var list = tui.widgets.ListView.init(allocator, []const u8);

try list.addItem("Item 1");
try list.addItem("Item 2");
try list.addItem("Item 3");

// Get selected item
if (list.getSelectedItem()) |item| {
    // Process selected item
}
```

### Table

Data tables with columns:

```zig
var table = tui.widgets.Table.init(allocator);

try table.addColumn("Name", 20);
try table.addColumn("Email", 30);
try table.addColumn("Role", 15);

try table.addRow(.{ "John Doe", "john@example.com", "Admin" });
try table.addRow(.{ "Jane Smith", "jane@example.com", "User" });
```

### Tabs

Tabbed navigation:

```zig
var tabs = tui.widgets.Tabs.init(allocator);

try tabs.addTab("Home", &home_widget);
try tabs.addTab("Settings", &settings_widget);
try tabs.addTab("Help", &help_widget);
```

### Modal

Dialog overlays:

```zig
var modal = tui.widgets.Modal.init(allocator)
    .withTitle("Confirm Action")
    .withContent(&confirm_widget)
    .withButtons(.{ "OK", "Cancel" });

modal.show();
```

## Creating Custom Widgets

You can create your own widgets by implementing the required interface:

```zig
const MyWidget = struct {
    // Your state
    value: i32 = 0,

    pub fn render(self: *MyWidget, ctx: *tui.RenderContext) void {
        var screen = ctx.getSubScreen();
        screen.setStyle(tui.Style.default.setFg(tui.Color.green));
        screen.moveCursor(0, 0);

        var buf: [32]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "Value: {d}", .{self.value}) catch "?";
        screen.putString(text);
    }

    pub fn handleEvent(self: *MyWidget, event: tui.Event) tui.EventResult {
        switch (event) {
            .key => |k| switch (k.key) {
                .up => { self.value += 1; return .needs_redraw; },
                .down => { self.value -= 1; return .needs_redraw; },
                else => {},
            },
            else => {},
        }
        return .ignored;
    }
};
```

See the [Custom Widgets](/guide/custom-widgets) guide for more details.
