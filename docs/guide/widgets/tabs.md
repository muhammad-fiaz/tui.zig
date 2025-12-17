# Tabs Widget

Tabbed navigation interface.

## Import

```zig
const tui = @import("tui");
// Define content type (e.g. tui.Text or your widget)
const Tabs = tui.Tabs(tui.Text);
```

## Usage

```zig
const definitions = &[_]tui.tabs.Tab{
    .{ .label = "Home" },
    .{ .label = "Settings" },
};

const contents = &[_]tui.Text{
    tui.Text.init("Home Content"),
    tui.Text.init("Settings Content"),
};

var tabs = Tabs.init(definitions, contents);
```

## Features

- Horizontal/Vertical positioning
- Keyboard navigation (Left/Right)
- Content switching
