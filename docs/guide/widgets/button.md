# Button Widget

The `Button` widget is a clickable element that triggers an action.

## Import

```zig
const tui = @import("tui");
const Button = tui.widgets.Button;
```

## Basic Usage

```zig
var btn = Button.init("Click Me", onClick);

fn onClick() void {
    std.debug.print("Clicked!\n", .{});
}
```

## Styling

Configure styles for different states:

```zig
var btn = Button.init("Submit", onSubmit)
    .withStyle(normal_style)
    .withHoverStyle(hover_style)
    .withPressStyle(press_style);
```

## Keyboard Support

Buttons can be triggered via keyboard (Enter/Space) when focused.
