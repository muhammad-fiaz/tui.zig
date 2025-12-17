# Border Widget

## Overview

The `Border` widget provides utilities for rendering borders around content areas using various Unicode box-drawing character sets. It supports different border styles and allows selective enabling/disabling of border sides. Borders are essential for creating visual separation, grouping related content, and improving the overall structure and readability of terminal user interfaces.

## BorderStyle Enum

- `.none`: No border characters
- `.single`: Single-line border (─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼)
- `.double`: Double-line border (═ ║ ╔ ╗ ╚ ╝ ╠ ╣ ╦ ╩ ╬)
- `.rounded`: Rounded corner border (─ │ ╭ ╮ ╰ ╯ ├ ┤ ┬ ┴ ┼)
- `.thick`: Thick line border (━ ┃ ┏ ┓ ┗ ┛ ┣ ┫ ┳ ┻ ╋)
- `.ascii`: ASCII character border (- | +)
- `.custom`: Allows custom border characters (not commonly used)

## BorderChars Struct

Contains all border drawing characters:

- `top_left`, `top_right`, `bottom_left`, `bottom_right`: Corner characters
- `horizontal`, `vertical`: Line characters
- `left_t`, `right_t`, `top_t`, `bottom_t`: T-junction characters
- `cross`: Cross junction character

## Border Struct Properties

- `top`, `bottom`, `left`, `right`: Boolean flags to show/hide each border side
- `style`: BorderStyle enum determining the character set
- `chars`: BorderChars struct containing the actual drawing characters

## Methods

- `all(style: BorderStyle)`: Creates a border with all sides enabled using the specified style
- `none()`: Creates a border with no sides (invisible border)
- `horizontal(style: BorderStyle)`: Creates a border with only top and bottom sides
- `vertical(style: BorderStyle)`: Creates a border with only left and right sides

## Usage Examples

### Basic Full Border

```zig
const tui = @import("tui");
const Border = tui.widgets.Border;

var fullBorder = Border.all(.single);
```

### Different Border Styles

```zig
var doubleBorder = Border.all(.double);
var roundedBorder = Border.all(.rounded);
var thickBorder = Border.all(.thick);
var asciiBorder = Border.all(.ascii);
```

### Partial Borders

```zig
// Only top and bottom borders
var horizontalBorder = Border.horizontal(.single);

// Only left and right borders
var verticalBorder = Border.vertical(.double);

// Custom side configuration
var customBorder = Border{
    .top = true,
    .bottom = true,
    .left = false,
    .right = false,
    .style = .single,
};
```

### Integration with Other Widgets

```zig
const Card = tui.widgets.Card;

var borderedCard = Card.init("Card content with border")
    .withBorder(.rounded);
```

### Custom Border Characters

```zig
// Create custom border characters
const customChars = BorderChars{
    .top_left = "*",
    .top_right = "*",
    .bottom_left = "*",
    .bottom_right = "*",
    .horizontal = "*",
    .vertical = "*",
    .left_t = "*",
    .right_t = "*",
    .top_t = "*",
    .bottom_t = "*",
    .cross = "*",
};

var starBorder = Border{
    .style = .custom,
    .chars = customChars,
};
```

### Border in Layouts

```zig
const Layout = tui.layout.Layout;
const Border = tui.widgets.Border;

// Create a bordered layout section
var sectionBorder = Border.all(.single);
var layout = Layout.vertical()
    .withBorder(sectionBorder)
    .addChild(headerWidget)
    .addChild(contentWidget);
```

### Themed Borders

```zig
// Different borders for different UI sections
const PanelBorder = Border.all(.rounded);
const DialogBorder = Border.all(.double);
const ErrorBorder = Border.all(.thick); // More prominent for errors

var infoPanel = Panel.init("Information")
    .withBorder(PanelBorder);

var errorDialog = Dialog.init("Error")
    .withBorder(ErrorBorder);
```

## Border Character Sets

### Single Line Border
```
┌─────┐
│     │
└─────┘
```

### Double Line Border
```
╔═════╗
║     ║
╚═════╝
```

### Rounded Border
```
╭─────╮
│     │
╰─────╯
```

### Thick Border
```
┏━━━━━┓
┃     ┃
┗━━━━━┛
```

### ASCII Border
```
+-----+
|     |
+-----+
```

## Best Practices

- Use consistent border styles throughout your application
- Choose border styles that match your UI theme
- Consider terminal compatibility - not all terminals support all Unicode characters
- Use `.ascii` style as a fallback for limited terminal environments
- Partial borders (horizontal/vertical only) can create subtle visual separation
- Reserve thicker/double borders for important UI elements like dialogs or errors

## Performance Notes

- Border rendering is lightweight and doesn't significantly impact performance
- Borders are rendered using simple character output
- No additional memory allocation required for border creation

```zig
const BorderChars = tui.widgets.BorderChars;
var customChars = BorderChars{
    .top_left = "*",
    .top_right = "*",
    .bottom_left = "*",
    .bottom_right = "*",
    .horizontal = "*",
    .vertical = "*",
    .left_t = "*",
    .right_t = "*",
    .top_t = "*",
    .bottom_t = "*",
    .cross = "*",
};

var customBorder = Border.all(.custom);
customBorder.chars = customChars;
```