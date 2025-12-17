# Layout

TUI.zig includes a flexible layout system based on Flexbox principles.

## Concepts

### Rect

A `Rect` explicitly defines a rectangular area:

```zig
const Rect = struct {
    x: u16,
    y: u16,
    width: u16,
    height: u16,
};
```

### Constraints

Layouts adapt to available space using constraints. However, in the current version, layout is primarily done by composing containers.

## Flex Containers

### FlexColumn

Arranges children vertically.

```zig
var col = tui.FlexColumn(.{
    tui.Text("Top"),
    tui.Text("Middle"),
    tui.Text("Bottom"),
});

// Options
col = col.gap(1)
         .mainAlign(.center)
         .crossAlign(.stretch);
```

### FlexRow

Arranges children horizontally.

```zig
var row = tui.FlexRow(.{
    tui.Button("Cancel", onCancel),
    tui.Button("OK", onOk),
});

row = row.gap(2).mainAlign(.end);
```

## Layout Widgets

### Padding

Adds space around a widget.

```zig
var padded = tui.Padding(
    tui.Text("Content"),
    .{ .top = 1, .right = 2, .bottom = 1, .left = 2 }
);
```

### Center

Centers a widget within the available space.

```zig
var centered = tui.Center(
    tui.Text("I am centered!")
);
```

### SizedBox

Forces a widget to a specific size.

```zig
var spacer = tui.SizedBox(
    .{ .width = 10, .height = 5 },
    tui.Text("Fixed Size")
);
```

### Margin

Similar to padding but conceptually outside the border.

```zig
var margin = tui.Margin(
    widget,
    .{ .all = 1 }
);
```

### Stack

Overlaps children on top of each other.

```zig
var stack = tui.Stack(.{
    BackgroundWidget{},
    ForegroundLabel{},
});
```
