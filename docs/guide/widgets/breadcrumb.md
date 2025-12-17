# Breadcrumb Widget

## Overview

The `Breadcrumb` widget displays hierarchical navigation paths, showing the current location within a navigation structure. It supports clickable items and custom separators.

## Properties

- `items`: Array of `BreadcrumbItem` structs containing labels and optional click handlers
- `separator`: String used to separate breadcrumb items (default " / ")
- `selected`: Index of the currently selected item
- `style`: Style configuration for rendering

## Methods

- `init(items: []const BreadcrumbItem)`: Creates a new breadcrumb with the given items
- `withSeparator(separator: []const u8)`: Sets the separator string
- `render(ctx: *RenderContext)`: Renders the breadcrumb navigation
- `handleEvent(event: Event)`: Handles keyboard navigation and selection

## Events

- **Navigation**: Left/Right arrows to move between items
- **Selection**: Enter key to trigger the selected item's click handler

## Examples

### Basic Breadcrumb

```zig
const tui = @import("tui");
const Breadcrumb = tui.widgets.Breadcrumb;
const BreadcrumbItem = tui.widgets.BreadcrumbItem;

const items = [_]BreadcrumbItem{
    .{ .label = "Home" },
    .{ .label = "Products" },
    .{ .label = "Electronics" },
};

var breadcrumb = Breadcrumb.init(&items);
```

### With Click Handlers

```zig
fn onHomeClick() void {
    // Navigate to home
}

fn onProductsClick() void {
    // Navigate to products
}

const items = [_]BreadcrumbItem{
    .{ .label = "Home", .on_click = onHomeClick },
    .{ .label = "Products", .on_click = onProductsClick },
    .{ .label = "Electronics" },
};

var breadcrumb = Breadcrumb.init(&items);
```

### Custom Separator

```zig
var breadcrumb = Breadcrumb.init(&items)
    .withSeparator(" > ");
```