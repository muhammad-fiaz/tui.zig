# Accordion Widget

## Overview

The `Accordion` widget provides a collapsible interface for displaying multiple content sections. It supports both single and multiple expanded panels simultaneously, allowing users to toggle visibility of content areas. This widget is ideal for organizing content in a space-efficient manner, such as FAQs, settings panels, or hierarchical information displays.

## Properties

- `items`: Array of `AccordionItem` structs containing:
  - `title`: The display text for the accordion header
  - `content`: The content text to show when expanded (supports multi-line with `\n`)
  - `expanded`: Boolean indicating if the item is currently expanded
  - `enabled`: Boolean indicating if the item can be interacted with
- `mode`: `AccordionMode` enum (`.single` or `.multiple`) - determines if only one or multiple panels can be expanded simultaneously
- `selected`: Index of the currently selected (focused) item for keyboard navigation
- `style`: Style configuration for rendering text and colors
- `on_change`: Optional callback function called when an item's expanded state changes, receives `(index: usize, expanded: bool)`

## Methods

- `init(items: []AccordionItem)`: Creates a new Accordion with the given items array
- `withMode(mode: AccordionMode)`: Sets the expansion mode (single or multiple)
- `withOnChange(callback: *const fn (usize, bool) void)`: Sets the change callback function
- `render(ctx: *RenderContext)`: Renders the accordion to the screen with proper styling and layout
- `handleEvent(event: Event)`: Handles keyboard and mouse events for navigation and toggling
- `toggle(index: usize)`: Toggles the expanded state of the item at the given index
- `expand(index: usize)`: Expands the item at the given index (respects mode restrictions)
- `collapse(index: usize)`: Collapses the item at the given index
- `collapseAll()`: Collapses all items in the accordion

## Events

- **Keyboard Navigation**:
  - `Up Arrow`: Move selection to previous item
  - `Down Arrow`: Move selection to next item
  - `Space` or `Enter`: Toggle expanded state of selected item
- **Change Callback**: Triggered when an item's expanded state changes via user interaction

## Usage Examples

### Basic Single-Mode Accordion

```zig
const tui = @import("tui");
const Accordion = tui.widgets.Accordion;
const AccordionItem = tui.widgets.AccordionItem;

var items = [_]AccordionItem{
    .{
        .title = "Getting Started",
        .content = "Welcome to our application!\n\nThis guide will help you get started with the basic features.",
        .expanded = true, // Start expanded
    },
    .{
        .title = "Configuration",
        .content = "Configure your settings here:\n- Theme selection\n- Keyboard shortcuts\n- Notification preferences",
    },
    .{
        .title = "Advanced Features",
        .content = "Explore advanced features:\n- Custom plugins\n- API integration\n- Performance tuning",
    },
};

var accordion = Accordion.init(&items);
```

### Multiple Expansion Mode with Callbacks

```zig
fn onAccordionChange(index: usize, expanded: bool) void {
    std.debug.print("Section {} {}\n", .{ index, if (expanded) "expanded" else "collapsed" });
    
    // Handle specific sections
    switch (index) {
        0 => if (expanded) loadGettingStartedContent(),
        1 => if (expanded) loadConfigurationPanel(),
        2 => if (expanded) loadAdvancedSettings(),
        else => {},
    }
}

var accordion = Accordion.init(&items)
    .withMode(.multiple)
    .withOnChange(onAccordionChange);
```

### Dynamic Content Updates

```zig
// Update accordion content dynamically
fn updateAccordionContent(accordion: *Accordion, new_content: []const u8, index: usize) void {
    if (index < accordion.items.len) {
        accordion.items[index].content = new_content;
        // Force re-render if needed
    }
}

// Expand specific section programmatically
accordion.expand(1); // Expand configuration section

// Collapse all sections
accordion.collapseAll();
```

### Integration with Application State

```zig
const AppState = struct {
    accordion: Accordion,
    current_section: usize = 0,
    
    pub fn init() AppState {
        var items = [_]AccordionItem{
            .{ .title = "Dashboard", .content = "Main dashboard content..." },
            .{ .title = "Settings", .content = "Settings panel..." },
            .{ .title = "Help", .content = "Help documentation..." },
        };
        
        return .{
            .accordion = Accordion.init(&items)
                .withMode(.single)
                .withOnChange(onSectionChange),
        };
    }
    
    fn onSectionChange(index: usize, expanded: bool) void {
        if (expanded) {
            app_state.current_section = index;
            updateUIForSection(index);
        }
    }
};
```

## Styling

The accordion uses the provided `Style` for text rendering. Individual items can be styled differently by modifying the style before rendering:

```zig
// Custom styling
var styledAccordion = Accordion.init(&items);
styledAccordion.style = Style.default
    .setFg(Color.cyan)
    .bold();

// Or modify theme colors
accordion.style = Style.default.setBg(Color.fromRGB(20, 20, 30));
```

## Accessibility

- Items marked as `enabled = false` will be visually dimmed and cannot be interacted with
- Keyboard navigation follows standard UI patterns
- Screen readers can announce expanded/collapsed states through the change callback
- Focus management ensures proper navigation flow

## Performance Considerations

- Content is rendered only when expanded, improving performance for large content
- Use `collapseAll()` to reset state when switching contexts
- Consider pagination for very large numbers of accordion items