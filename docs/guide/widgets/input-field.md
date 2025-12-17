# InputField Widget

The `InputField` provides a single-line text input with cursor management.

## Import

```zig
const tui = @import("tui");
const InputField = tui.widgets.InputField;
```

## Usage

```zig
var input = InputField.init(allocator);
```

## Options

- `withPlaceholder("Search...")`: Text to show when empty.
- `withMaxLength(10)`: Limit input length.
- `withPasswordMode()`: Mask characters (e.g. `*`).

## Getting Value

```zig
const value = input.getValue();
```

## Events

The input field handles:

- Character input
- Backspace/Delete
- Left/Right arrows
- Home/End
