# Styles & Themes

TUI.zig provides a robust styling system.

## Styles

A `Style` defines the visual appearance of a cell:

```zig
const style = tui.Style{
    .fg = tui.Color.red,
    .bg = tui.Color.black,
    .bold = true,
};
```

Method chaining is supported:

```zig
const active = tui.Style.default
    .setFg(.green)
    .bold()
    .underline();
```

## Themes

A `Theme` is a collection of styles for common UI elements.

```zig
pub const Theme = struct {
    primary: Style,
    secondary: Style,
    background: Style,
    surface: Style,
    error: Style,
    // ...
};
```

## Built-in Themes

Several themes are included:

- `Theme.default_theme`
- `Theme.dark`
- `Theme.light`
- `Theme.nord`
- `Theme.dracula`
- `Theme.gruvbox`

## Using a Theme

Set the theme when initializing the App:

```zig
var app = try tui.App.init(.{
    .theme = tui.Theme.nord,
});
```
