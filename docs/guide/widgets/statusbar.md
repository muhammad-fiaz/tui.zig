# Statusbar Widget

## Overview

The `Statusbar` widget displays status information at the bottom of the application. It supports multiple status items with left, center, and right alignment.

## Properties

- `items`: Array of `StatusItem` structs containing text and alignment
- `base`: Base widget state
- `style`: Style configuration for rendering

## Methods

- `init(items: []const StatusItem)`: Creates a new statusbar with the given items
- `render(ctx: *RenderContext)`: Renders the statusbar with all items

## Events

None - this widget is not interactive.

## Examples

### Basic Statusbar

```zig
const tui = @import("tui");
const Statusbar = tui.widgets.Statusbar;
const StatusItem = tui.widgets.StatusItem;

const items = [_]StatusItem{
    .{ .text = "Ready", .alignment = .left },
    .{ .text = "v1.0.0", .alignment = .right },
};

var statusbar = Statusbar.init(&items);
```

### Multiple Items

```zig
const items = [_]StatusItem{
    .{ .text = "File: main.zig", .alignment = .left },
    .{ .text = "Line 42", .alignment = .center },
    .{ .text = "UTF-8", .alignment = .right },
};

var statusbar = Statusbar.init(&items);
```