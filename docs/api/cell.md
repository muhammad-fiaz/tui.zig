# Cell

The `Cell` struct represents a single character position in the terminal screen buffer, including Unicode grapheme clusters and styling information.

## Overview

Cells are the fundamental building blocks of the screen buffer, containing:
- Character content (single codepoint or grapheme cluster)
- Style information (colors, attributes)
- Display width for proper alignment

## Types

### Content

Union type for cell content.

```zig
pub const Content = union(enum) {
    codepoint: u21,      // Single Unicode codepoint
    grapheme: []const u8, // Grapheme cluster bytes
};
```

## Cell

Main cell structure.

### Fields

- `content: Content` - Character content (default: space)
- `style: Style` - Cell styling (default: default style)
- `width: u2` - Display width (1 for normal, 2 for wide, 0 for combining)

### Constants

#### blank

```zig
pub const blank = Cell{};
```

Default blank cell (space with default style).

### Methods

#### init

```zig
pub fn init(char: u21) Cell
```

Creates a cell with a single Unicode codepoint.

**Parameters:**
- `char: u21` - Unicode codepoint

**Returns:** New Cell with calculated width

#### initStyled

```zig
pub fn initStyled(char: u21, s: Style) Cell
```

Creates a cell with a character and style.

**Parameters:**
- `char: u21` - Unicode codepoint
- `s: Style` - Cell style

**Returns:** New styled Cell

#### fromGrapheme

```zig
pub fn fromGrapheme(grapheme: []const u8) Cell
```

Creates a cell from a grapheme cluster.

**Parameters:**
- `grapheme: []const u8` - UTF-8 grapheme cluster bytes

**Returns:** New Cell with grapheme content

#### getContent

```zig
pub fn getContent(self: Cell, buf: *[4]u8) []const u8
```

Gets the cell content as a UTF-8 string.

**Parameters:**
- `buf: *[4]u8` - Buffer for UTF-8 encoding

**Returns:** UTF-8 string slice

#### isEmpty

```zig
pub fn isEmpty(self: Cell) bool
```

Checks if the cell is empty (space with default style).

**Returns:** True if cell is blank

#### eql

```zig
pub fn eql(self: Cell, other: Cell) bool
```

Compares two cells for equality.

**Parameters:**
- `other: Cell` - Cell to compare with

**Returns:** True if cells are identical

#### setChar

```zig
pub fn setChar(self: *Cell, char: u21) void
```

Updates the cell's character content.

**Parameters:**
- `char: u21` - New Unicode codepoint

#### setStyle

```zig
pub fn setStyle(self: *Cell, s: Style) void
```

Updates the cell's style.

**Parameters:**
- `s: Style` - New style

#### clear

```zig
pub fn clear(self: *Cell) void
```

Clears the cell to blank state.

#### clearKeepStyle

```zig
pub fn clearKeepStyle(self: *Cell) void
```

Clears the cell content but preserves the style.

#### writeTo

```zig
pub fn writeTo(self: Cell, writer: anytype) !void
```

Writes the cell content to a writer.

**Parameters:**
- `writer: anytype` - Writer interface

## CellRow

A row of cells for screen buffer management.

### Fields

- `cells: []Cell` - Array of cells
- `allocator: std.mem.Allocator` - Memory allocator

### Methods

#### init

```zig
pub fn init(allocator: std.mem.Allocator, width: usize) !CellRow
```

Creates a new cell row.

**Parameters:**
- `allocator: std.mem.Allocator` - Memory allocator
- `width: usize` - Row width in cells

**Returns:** New CellRow filled with blank cells

#### deinit

```zig
pub fn deinit(self: *CellRow) void
```

Frees the cell row memory.

#### get

```zig
pub fn get(self: CellRow, x: usize) ?*Cell
```

Gets a pointer to a cell at position x.

**Parameters:**
- `x: usize` - Column index

**Returns:** Pointer to cell or null if out of bounds

#### set

```zig
pub fn set(self: *CellRow, x: usize, cell: Cell) void
```

Sets a cell at position x.

**Parameters:**
- `x: usize` - Column index
- `cell: Cell` - Cell to set

#### clear

```zig
pub fn clear(self: *CellRow) void
```

Clears all cells in the row to blank.

#### resize

```zig
pub fn resize(self: *CellRow, new_width: usize) !void
```

Resizes the row to a new width.

**Parameters:**
- `new_width: usize` - New width in cells

## Usage Examples

### Creating Cells

```zig
// Simple character cell
const cell1 = Cell.init('A');

// Styled cell
const style = Style.default.foreground(Color.red);
const cell2 = Cell.initStyled('B', style);

// Grapheme cluster (emoji)
const cell3 = Cell.fromGrapheme("🚀");
```

### Cell Operations

```zig
var cell = Cell.init('X');
cell.setStyle(Style.default.bold());

// Check if empty
if (cell.isEmpty()) {
    // Handle empty cell
}

// Write to output
var buf: [4]u8 = undefined;
const content = cell.getContent(&buf);
try writer.writeAll(content);
```

### CellRow Management

```zig
var row = try CellRow.init(allocator, 80);
defer row.deinit();

// Set a cell
if (row.get(10)) |cell| {
    cell.* = Cell.initStyled('!', Style.default.foreground(Color.blue));
}

// Clear row
row.clear();

// Resize
try row.resize(120);
```

## See Also

- [Screen API](screen.md)
- [Style API](style.md)
- Source: `src/core/cell.zig`