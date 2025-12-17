# Separator Widget

## Overview

The `Separator` widget provides visual division between sections of content. It supports horizontal and vertical orientations with various styles including solid, dashed, dotted, double, and thick lines.

## Properties

- `orientation`: Orientation of the separator (`.horizontal` or `.vertical`)
- `separator_style`: Style of the separator line (`.solid`, `.dashed`, `.dotted`, `.double`, `.thick`)
- `label`: Optional text label to display on the separator
- `base`: Base widget state
- `style`: Style configuration for rendering

## Methods

- `init()`: Creates a new separator with default settings
- `withOrientation(orientation: SeparatorOrientation)`: Sets the separator orientation
- `withStyle(separator_style: SeparatorStyle)`: Sets the separator line style
- `withLabel(label: []const u8)`: Adds a label to the separator
- `render(ctx: *RenderContext)`: Renders the separator

## Events

None - this widget is not interactive.

## Examples

### Basic Horizontal Separator

```zig
const tui = @import("tui");
const Separator = tui.widgets.Separator;

var separator = Separator.init();
```

### Vertical Separator with Label

```zig
var separator = Separator.init()
    .withOrientation(.vertical)
    .withLabel("Section Break");
```

### Dashed Separator

```zig
var separator = Separator.init()
    .withStyle(.dashed);
```
