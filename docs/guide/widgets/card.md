# Card Widget

## Overview

The `Card` widget provides a container for grouped content with optional header, body, and footer sections. It supports borders and padding for visual separation.

## Properties

- `title`: Optional title text displayed at the top
- `content`: Main content text
- `footer`: Optional footer text displayed at the bottom
- `border_style`: Border style using `BorderStyle` enum
- `style`: Style configuration for rendering
- `padding`: Internal padding size

## Methods

- `init(content: []const u8)`: Creates a new card with the given content
- `withTitle(title: []const u8)`: Sets the card title
- `withFooter(footer: []const u8)`: Sets the card footer
- `withBorder(border_style: BorderStyle)`: Sets the border style
- `withPadding(padding: u16)`: Sets the internal padding
- `render(ctx: *RenderContext)`: Renders the card with borders and content

## Events

None - the card is a static display container.

## Examples

### Basic Card

```zig
const tui = @import("tui");
const Card = tui.widgets.Card;

var card = Card.init("This is the card content.");
```

### Card with Title and Footer

```zig
var card = Card.init("Main content here")
    .withTitle("Card Title")
    .withFooter("Card Footer");
```

### Styled Card

```zig
var styledCard = Card.init("Styled content")
    .withTitle("Styled Card")
    .withBorder(.double)
    .withPadding(2);
```