# Styling

TUI.zig provides a comprehensive styling system with colors, themes, and text attributes.

## Colors

### True Color (24-bit RGB)

Create any color using RGB values:

```zig
const tui = @import("tui");

// RGB values (0-255)
const coral = tui.Color.rgb(255, 127, 80);
const teal = tui.Color.rgb(0, 128, 128);

// Hex color codes
const purple = tui.Color.hex(0x9B59B6);
const gold = tui.Color.hex(0xFFD700);
```

### Named Colors

Common colors are predefined:

```zig
tui.Color.black
tui.Color.red
tui.Color.green
tui.Color.yellow
tui.Color.blue
tui.Color.magenta
tui.Color.cyan
tui.Color.white

// Bright variants
tui.Color.bright_red
tui.Color.bright_green
// ... etc
```

### 256-Color Palette

For terminals that don't support true color:

```zig
const color = tui.Color.indexed(42);  // Color 42 from 256 palette
```

## Text Styles

Apply text attributes using the Style builder:

```zig
const style = tui.Style.default
    .setFg(tui.Color.cyan)        // Foreground color
    .setBg(tui.Color.black)       // Background color
    .bold()                        // Bold text
    .italic()                      // Italic text
    .underline()                   // Underlined
    .strikethrough()               // Strikethrough
    .dim()                         // Dimmed
    .reverse()                     // Reverse colors
    .blink();                      // Blinking (where supported)
```

### Combining Styles

```zig
// Create a warning style
const warning = tui.Style.default
    .setFg(tui.Color.black)
    .setBg(tui.Color.yellow)
    .bold();

// Create an error style
const error_style = tui.Style.default
    .setFg(tui.Color.white)
    .setBg(tui.Color.red)
    .bold();

// Create a subtle style
const muted = tui.Style.default
    .setFg(tui.Color.indexed(245))  // Gray
    .dim();
```

## Themes

TUI.zig includes several built-in themes:

```zig
// Available themes
tui.Theme.default_theme      // Default dark theme
tui.Theme.dark_theme         // Pure dark theme
tui.Theme.light_theme        // Light theme
tui.Theme.nord_theme         // Nord color scheme
tui.Theme.dracula_theme      // Dracula color scheme
tui.Theme.gruvbox_theme      // Gruvbox color scheme
tui.Theme.high_contrast      // High contrast for accessibility
```

### Using Themes

```zig
var app = try tui.App.init(.{
    .theme = tui.Theme.nord_theme,
});
```

### Theme Structure

A theme defines colors for various UI elements:

```zig
const Theme = struct {
    primary: Color,
    secondary: Color,
    background: Color,
    surface: Color,
    text: Color,
    text_muted: Color,
    border: Color,
    success: Color,
    warning: Color,
    error_color: Color,
    // Widget-specific styles
    input: Style,
    input_focus: Style,
    button: Style,
    button_hover: Style,
    button_press: Style,
    // ... and more
};
```

### Creating Custom Themes

```zig
const my_theme = tui.Theme{
    .primary = tui.Color.rgb(100, 150, 255),
    .secondary = tui.Color.rgb(150, 100, 255),
    .background = tui.Color.rgb(20, 20, 30),
    .surface = tui.Color.rgb(30, 30, 45),
    .text = tui.Color.rgb(240, 240, 250),
    .text_muted = tui.Color.rgb(150, 150, 170),
    .border = tui.Color.rgb(60, 60, 80),
    .success = tui.Color.rgb(100, 255, 150),
    .warning = tui.Color.rgb(255, 200, 100),
    .error_color = tui.Color.rgb(255, 100, 100),
    // ... configure other properties
};

var app = try tui.App.init(.{
    .theme = my_theme,
});
```

## Border Styles

TUI.zig supports various border styles:

```zig
// Border types
tui.BorderStyle.none      // No border
tui.BorderStyle.single    // ┌─┐ │ │ └─┘
tui.BorderStyle.double    // ╔═╗ ║ ║ ╚═╝
tui.BorderStyle.rounded   // ╭─╮ │ │ ╰─╯
tui.BorderStyle.thick     // ┏━┓ ┃ ┃ ┗━┛
tui.BorderStyle.ascii     // +-+ | | +-+
```

## Using Styles in Widgets

Widgets accept style configuration:

```zig
var button = tui.widgets.Button.init("Submit")
    .withStyle(tui.Style.default.setFg(tui.Color.white).setBg(tui.Color.blue))
    .withHoverStyle(tui.Style.default.setFg(tui.Color.white).setBg(tui.Color.cyan))
    .withPressStyle(tui.Style.default.setFg(tui.Color.black).setBg(tui.Color.white));
```

## Drawing with Styles

When rendering custom widgets:

```zig
pub fn render(self: *MyWidget, ctx: *tui.RenderContext) void {
    var screen = ctx.getSubScreen();

    // Set the current style
    screen.setStyle(tui.Style.default
        .setFg(tui.Color.rgb(255, 200, 100))
        .bold());

    // All subsequent drawing uses this style
    screen.moveCursor(0, 0);
    screen.putString("Bold gold text!");

    // Change style for different content
    screen.setStyle(tui.Style.default.setFg(tui.Color.cyan).italic());
    screen.moveCursor(0, 1);
    screen.putString("Italic cyan text");

    // Reset to default
    screen.setStyle(tui.Style.default);
}
```
