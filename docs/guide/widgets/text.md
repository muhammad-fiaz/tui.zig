# Text Widget

The `Text` widget displays a static or styled string.

## Import

```zig
const tui = @import("tui");
const Text = tui.widgets.Text;
```

## Basic Usage

```zig
var label = Text.init("Hello World");
```

## Styling

You can apply a style to the entire text:

```zig
var styled = Text.init("Error!")
    .withStyle(tui.Style.default.setFg(tui.Color.red).bold());
```

## Alignment

Text supports alignment within its bounding box:

```zig
var aligned = Text.init("Centered")
    .withAlignment(.center);
```

Options: `.left`, `.center`, `.right`.

## Word Wrapping

For multi-line text, enable word wrapping:

```zig
var wrapped = Text.init("Long text that wraps...")
    .withWordWrap();
```
