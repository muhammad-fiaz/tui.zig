# ListView Widget

A vertical list of items with selection support.

## Import

```zig
const tui = @import("tui");
const ListView = tui.widgets.ListView;
```

## Usage

```zig
var list = ListView.init(allocator, []const u8);
try list.addItem("Item A");
try list.addItem("Item B");
```

## Selection

```zig
// Get selected index
if (list.getSelectedIndex()) |idx| {
    // ...
}

// Get selected item
if (list.getSelectedItem()) |item| {
    std.debug.print("Selected: {s}\n", .{item});
}
```

## Events

Handles `Up`/`Down` keys for navigation.
