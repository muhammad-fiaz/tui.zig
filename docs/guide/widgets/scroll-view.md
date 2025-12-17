# Scroll View Widget

## Overview

The `ScrollView` widget provides a scrollable container for content that exceeds the available viewport size. It supports both vertical and horizontal scrolling with customizable scrollbars and smooth navigation.

## Properties

- `content`: The content widget to be scrolled
- `content_width`: Width of the content area
- `content_height`: Height of the content area
- `scroll_x`: Horizontal scroll offset
- `scroll_y`: Vertical scroll offset
- `show_vertical_scrollbar`: Whether to display the vertical scrollbar
- `show_horizontal_scrollbar`: Whether to display the horizontal scrollbar
- `scrollbar_track`: Character used for scrollbar track
- `scrollbar_thumb`: Character used for scrollbar thumb
- `scrollbar_style`: Style configuration for scrollbars
- `base`: Base widget state

## Methods

- `init(content: ContentType)`: Creates a new scroll view with the given content
- `withContentSize(width: u16, height: u16)`: Sets the content dimensions
- `withHorizontalScrollbar()`: Enables horizontal scrollbar display
- `hideVerticalScrollbar()`: Hides the vertical scrollbar
- `scrollBy(dx: i16, dy: i16)`: Scrolls by the specified amount
- `scrollTo(x: u16, y: u16)`: Scrolls to the specified position
- `scrollToTop()`: Scrolls to the top of the content
- `scrollToBottom()`: Scrolls to the bottom of the content
- `getViewportWidth()`: Returns the width of the visible viewport
- `getViewportHeight()`: Returns the height of the visible viewport
- `render(ctx: *RenderContext)`: Renders the scroll view and its content
- `handleEvent(event: Event)`: Handles keyboard and mouse events
- `isFocusable()`: Returns true as scroll views are focusable
- `sizeHint()`: Returns size hint for layout

## Events

- **Keyboard Navigation**: Arrow keys for scrolling, Page Up/Down, Home/End
- **Mouse Scrolling**: Mouse wheel events for vertical scrolling

## Examples

### Basic Usage

```zig
const tui = @import("tui");
const ScrollView = tui.widgets.ScrollView;
const Text = tui.widgets.Text;

var text = Text.init("This is a long text that will be scrollable...");
var scroll_view = ScrollView(Text).init(text)
    .withContentSize(100, 50);
```

### With Custom Scrollbars

```zig
var scroll_view = ScrollView(Text).init(text)
    .withContentSize(100, 50)
    .withHorizontalScrollbar();
```