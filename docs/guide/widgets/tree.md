# Tree View Widget

## Overview

The `TreeView` widget displays hierarchical data in an expandable tree structure. It supports keyboard navigation, expand/collapse functionality, and selection callbacks.

## Properties

- `root`: Array of root `TreeNode` items
- `selected`: Index of the currently selected node
- `base`: Base widget state
- `style`: Style configuration for rendering
- `on_select`: Optional callback function called when selection changes

## Methods

- `init(root: []TreeNode)`: Creates a new tree view with the given root nodes
- `render(ctx: *RenderContext)`: Renders the tree with expand/collapse indicators
- `handleEvent(event: Event)`: Handles keyboard navigation and interaction

## Events

- **Keyboard Navigation**: Up/Down arrows to navigate nodes
- **Expand/Collapse**: Left/Right arrows or Space/Enter to toggle expansion
- **Selection Callback**: Triggered when the selected node changes

## Examples

### Basic Tree View

```zig
const tui = @import("tui");
const TreeView = tui.widgets.TreeView;
const TreeNode = tui.widgets.TreeNode;

const nodes = [_]TreeNode{
    .{
        .label = "Root 1",
        .children = &[_]TreeNode{
            .{ .label = "Child 1.1" },
            .{ .label = "Child 1.2" },
        },
    },
    .{
        .label = "Root 2",
        .expanded = true,
        .children = &[_]TreeNode{
            .{ .label = "Child 2.1" },
        },
    },
};

var tree = TreeView.init(&nodes);
```

### Tree with Selection Callback

```zig
fn onSelect(index: usize) void {
    std.debug.print("Selected node: {}\n", .{index});
}

var tree = TreeView.init(&nodes);
tree.on_select = onSelect;
```