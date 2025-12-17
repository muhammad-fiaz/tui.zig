# Progress Bar Widget

Visualizes progress of a task.

## Import

```zig
const tui = @import("tui");
const Progress = tui.widgets.Progress;
```

## Usage

```zig
var p = Progress.init();
p.setValue(0.5); // 50%
```

## Options

- `withLabel("Loading...")`: Text label
- `withShowPercentage(bool)`: Display partial percentage
- `withStyle(style)`: Bar color

## Value Range

Value should be between `0.0` (empty) and `1.0` (full).
