# Tooltip Widget

## Overview

The `Tooltip` widget displays contextual help information on hover or focus. It automatically positions itself to avoid screen edges and supports customizable delay and positioning.

## Properties

- `text`: The tooltip text content
- `visible`: Whether the tooltip is currently visible
- `position`: Preferred position (`.top`, `.bottom`, `.left`, `.right`, `.auto`)
- `base`: Base widget state
- `style`: Style configuration for rendering
- `delay_ms`: Delay before showing the tooltip

## Methods

- `init(text: []const u8)`: Creates a new tooltip with the given text
- `withPosition(position: TooltipPosition)`: Sets the preferred position
- `withDelay(delay_ms: u32)`: Sets the show delay
- `show()`: Shows the tooltip
- `hide()`: Hides the tooltip
- `render(ctx: *RenderContext)`: Renders the tooltip with border and background

## Events

None - this widget is not interactive.

## Examples

### Basic Tooltip

```zig
const tui = @import("tui");
const Tooltip = tui.widgets.Tooltip;

var tooltip = Tooltip.init("Click here to save")
    .withPosition(.top)
    .withDelay(500);

tooltip.show();
```

### Auto-positioned Tooltip

```zig
var tooltip = Tooltip.init("Press Ctrl+S to save")
    .withPosition(.auto);
```