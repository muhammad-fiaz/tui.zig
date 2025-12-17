# Pagination Widget

## Overview

The `Pagination` widget provides navigation controls for multi-page content. It supports different display modes (simple, full, compact) and keyboard navigation.

## Properties

- `current_page`: Current active page number (1-based)
- `total_pages`: Total number of pages
- `mode`: `PaginationMode` enum (`.simple`, `.full`, `.compact`) - controls display style
- `style`: Style configuration for rendering
- `on_change`: Optional callback function called when page changes

## Methods

- `init(total_pages: usize)`: Creates a new pagination with the given total pages
- `withMode(mode: PaginationMode)`: Sets the display mode
- `withOnChange(callback: fn(usize))`: Sets the page change callback
- `render(ctx: *RenderContext)`: Renders the pagination controls
- `handleEvent(event: Event)`: Handles keyboard navigation
- `setPage(page: usize)`: Sets the current page
- `nextPage()`: Advances to the next page (returns true if successful)
- `previousPage()`: Goes to the previous page (returns true if successful)

## Events

- **Navigation**: Left/Right arrows for previous/next page
- **Jump**: Home/End keys for first/last page

## Examples

### Basic Pagination

```zig
const tui = @import("tui");
const Pagination = tui.widgets.Pagination;

var pagination = Pagination.init(10);
```

### With Change Callback

```zig
fn onPageChange(page: usize) void {
    std.debug.print("Switched to page {}\n", .{page});
    // Load content for new page
}

var pagination = Pagination.init(20)
    .withOnChange(onPageChange);
```

### Different Modes

```zig
// Simple mode: "Page 1 of 10 ◀ Prev Next ▶"
var simple = Pagination.init(10).withMode(.simple);

// Full mode: Shows page numbers with navigation
var full = Pagination.init(100).withMode(.full);

// Compact mode: "1/10"
var compact = Pagination.init(10).withMode(.compact);
```

### Programmatic Navigation

```zig
var pagination = Pagination.init(5);

// Go to specific page
pagination.setPage(3);

// Navigate programmatically
if (pagination.nextPage()) {
    // Moved to next page
}

if (pagination.previousPage()) {
    // Moved to previous page
}
```