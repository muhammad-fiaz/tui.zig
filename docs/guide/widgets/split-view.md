# Split View Widget

## Overview

The `SplitView` widget provides a resizable split-pane interface for displaying two content areas. It supports both horizontal and vertical splits with adjustable ratios and interactive resizing.

## Properties

- `first`: Content for the first pane
- `second`: Content for the second pane
- `orientation`: Split orientation (`.horizontal` or `.vertical`)
- `ratio`: Split ratio between panes (0.0 - 1.0)
- `min_size`: Minimum size for each pane
- `dragging`: Whether the divider is currently being dragged
- `show_divider`: Whether to display the divider
- `divider_char`: Character for vertical divider
- `horizontal_divider_char`: Character for horizontal divider
- `divider_style`: Style for the divider
- `focused_pane`: Currently focused pane (0 or 1)
- `base`: Base widget state

## Methods

- `horizontal(first: FirstType, second: SecondType)`: Creates a horizontal split view
- `vertical(first: FirstType, second: SecondType)`: Creates a vertical split view
- `withRatio(r: f32)`: Sets the split ratio
- `withMinSize(size: u16)`: Sets the minimum pane size
- `hideDivider()`: Hides the divider line
- `render(ctx: *RenderContext)`: Renders both panes and divider
- `handleEvent(event: Event)`: Handles keyboard and mouse events
- `isFocusable()`: Returns true as split views are focusable
- `sizeHint()`: Returns size hint for layout

## Events

- **Keyboard Navigation**: Tab to switch between panes
- **Mouse Interaction**: Click and drag divider to resize, click panes to focus

## Examples

### Basic Horizontal Split

```zig
const tui = @import("tui");
const SplitView = tui.widgets.SplitView;
const Text = tui.widgets.Text;

var left_text = Text.init("Left pane content");
var right_text = Text.init("Right pane content");

var split_view = SplitView(Text, Text).horizontal(left_text, right_text);
```

### Vertical Split with Custom Ratio

```zig
var split_view = SplitView(Text, Text).vertical(left_text, right_text)
    .withRatio(0.3);
```

### Hidden Divider

```zig
var split_view = SplitView(Text, Text).horizontal(left_text, right_text)
    .hideDivider();
```