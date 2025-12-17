# TextArea Widget

Multi-line text editing widget.

## Import

```zig
const tui = @import("tui");
const TextArea = tui.widgets.TextArea;
```

## Usage

```zig
var editor = TextArea.init(allocator);
editor.setText("Initial content\nLine 2");
```

## Features

- Multi-line editing
- Selection support (Shift+Arrows)
- Copy/Paste (Ctrl+C/V) - _Platform dependent hook required_
- Line numbers (optional)
- Word wrap (optional)

## Configuration

```zig
editor.withLineNumbers()
      .withWordWrap();
```
