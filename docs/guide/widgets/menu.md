# Menu Widget

## Overview

The `Menu` widget provides a dropdown or popup menu for navigation and actions. It supports keyboard navigation, shortcuts, disabled items, and separators.

## Properties

- `items`: Array of `MenuItem` structs containing labels, shortcuts, and handlers
- `selected`: Index of the currently selected item
- `visible`: Boolean controlling menu visibility
- `style`: Style configuration for rendering

## Methods

- `init(items: []const MenuItem)`: Creates a new menu with the given items
- `show()`: Shows the menu
- `hide()`: Hides the menu
- `render(ctx: *RenderContext)`: Renders the menu
- `handleEvent(event: Event)`: Handles keyboard navigation and selection

## Events

- **Navigation**: Up/Down arrows to move between items
- **Selection**: Enter key to select the current item
- **Close**: Escape key to hide the menu

## Examples

### Basic Menu

```zig
const tui = @import("tui");
const Menu = tui.widgets.Menu;
const MenuItem = tui.widgets.MenuItem;

const items = [_]MenuItem{
    .{ .label = "New", .shortcut = "Ctrl+N" },
    .{ .label = "Open", .shortcut = "Ctrl+O" },
    .{ .separator = true },
    .{ .label = "Exit", .shortcut = "Ctrl+Q" },
};

var menu = Menu.init(&items);
menu.show();
```

### Menu with Handlers

```zig
fn onNew() void {
    // Create new document
}

fn onOpen() void {
    // Open file dialog
}

const items = [_]MenuItem{
    .{ .label = "New", .on_select = onNew },
    .{ .label = "Open", .on_select = onOpen },
    .{ .label = "Save", .enabled = false },
};

var menu = Menu.init(&items);
```

### Disabled Items

```zig
const items = [_]MenuItem{
    .{ .label = "Cut", .enabled = false },
    .{ .label = "Copy" },
    .{ .label = "Paste" },
};
```