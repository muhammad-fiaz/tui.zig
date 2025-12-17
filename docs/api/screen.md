# Screen

The `Screen` struct provides an off-screen buffer for building terminal displays, with drawing primitives and cell management.

## Overview

The screen buffer:
- Maintains a 2D grid of cells
- Provides drawing operations (text, shapes, regions)
- Supports sub-regions for clipping
- Handles wide character positioning
- Enables efficient rendering through diffing

## Screen

Main screen buffer structure.

### Fields

- `allocator: std.mem.Allocator` - Memory allocator
- `cells: []Cell` - Cell grid in row-major order
- `width: u16` - Screen width in cells
- `height: u16` - Screen height in cells
- `cursor_x: u16` - Current cursor X position
- `cursor_y: u16` - Current cursor Y position
- `current_style: Style` - Current drawing style

### Methods

#### init

```zig
pub fn init(allocator: std.mem.Allocator, width: u16, height: u16) !Screen
```

Creates a new screen buffer.

**Parameters:**
- `allocator: std.mem.Allocator` - Memory allocator
- `width: u16` - Screen width in cells
- `height: u16` - Screen height in cells

**Returns:** New Screen instance filled with blank cells

#### deinit

```zig
pub fn deinit(self: *Screen) void
```

Frees the screen buffer memory.

#### resize

```zig
pub fn resize(self: *Screen, new_width: u16, new_height: u16) !void
```

Resizes the screen buffer, preserving existing content where possible.

**Parameters:**
- `new_width: u16` - New width in cells
- `new_height: u16` - New height in cells

#### clear

```zig
pub fn clear(self: *Screen) void
```

Clears the entire screen to blank cells and resets cursor to (0,0).

#### clearWithStyle

```zig
pub fn clearWithStyle(self: *Screen, s: Style) void
```

Clears the screen with cells having the specified style.

**Parameters:**
- `s: Style` - Style for blank cells

#### getCell

```zig
pub fn getCell(self: *const Screen, x: u16, y: u16) ?*const Cell
```

Gets a read-only pointer to a cell.

**Parameters:**
- `x: u16` - X coordinate
- `y: u16` - Y coordinate

**Returns:** Pointer to cell or null if out of bounds

#### getCellMut

```zig
pub fn getCellMut(self: *Screen, x: u16, y: u16) ?*Cell
```

Gets a mutable pointer to a cell.

**Parameters:**
- `x: u16` - X coordinate
- `y: u16` - Y coordinate

**Returns:** Mutable pointer to cell or null if out of bounds

#### setCell

```zig
pub fn setCell(self: *Screen, x: u16, y: u16, c: Cell) void
```

Sets a cell at the specified position.

**Parameters:**
- `x: u16` - X coordinate
- `y: u16` - Y coordinate
- `c: Cell` - Cell to set

Handles wide characters by setting continuation cells.

#### setStyle

```zig
pub fn setStyle(self: *Screen, s: Style) void
```

Sets the current drawing style.

**Parameters:**
- `s: Style` - New style for drawing operations

#### moveCursor

```zig
pub fn moveCursor(self: *Screen, x: u16, y: u16) void
```

Moves the cursor to a new position.

**Parameters:**
- `x: u16` - X coordinate
- `y: u16` - Y coordinate

Cursor is clamped to screen bounds.

#### putChar

```zig
pub fn putChar(self: *Screen, char: u21) void
```

Writes a character at the current cursor position and advances the cursor.

**Parameters:**
- `char: u21` - Unicode codepoint

#### putString

```zig
pub fn putString(self: *Screen, s: []const u8) void
```

Writes a UTF-8 string at the current cursor position.

**Parameters:**
- `s: []const u8` - UTF-8 string

#### putStringAt

```zig
pub fn putStringAt(self: *Screen, x: u16, y: u16, s: []const u8) void
```

Writes a string at a specific position.

**Parameters:**
- `x: u16` - X coordinate
- `y: u16` - Y coordinate
- `s: []const u8` - UTF-8 string

#### hline

```zig
pub fn hline(self: *Screen, x: u16, y: u16, len: u16, char: u21) void
```

Draws a horizontal line.

**Parameters:**
- `x: u16` - Starting X coordinate
- `y: u16` - Y coordinate
- `len: u16` - Line length
- `char: u21` - Character to draw

#### vline

```zig
pub fn vline(self: *Screen, x: u16, y: u16, len: u16, char: u21) void
```

Draws a vertical line.

**Parameters:**
- `x: u16` - X coordinate
- `y: u16` - Starting Y coordinate
- `len: u16` - Line length
- `char: u21` - Character to draw

#### fill

```zig
pub fn fill(self: *Screen, x: u16, y: u16, w: u16, h: u16, char: u21) void
```

Fills a rectangular region with a character.

**Parameters:**
- `x: u16` - Starting X coordinate
- `y: u16` - Starting Y coordinate
- `w: u16` - Width
- `h: u16` - Height
- `char: u21` - Fill character

#### drawBox

```zig
pub fn drawBox(self: *Screen, x: u16, y: u16, w: u16, h: u16, border: style.BorderStyle) void
```

Draws a box border using the specified border style.

**Parameters:**
- `x: u16` - Starting X coordinate
- `y: u16` - Starting Y coordinate
- `w: u16` - Box width
- `h: u16` - Box height
- `border: style.BorderStyle` - Border style

#### blit

```zig
pub fn blit(self: *Screen, src: *const Screen, src_x: u16, src_y: u16, dst_x: u16, dst_y: u16, w: u16, h: u16) void
```

Copies a region from another screen.

**Parameters:**
- `src: *const Screen` - Source screen
- `src_x: u16` - Source X coordinate
- `src_y: u16` - Source Y coordinate
- `dst_x: u16` - Destination X coordinate
- `dst_y: u16` - Destination Y coordinate
- `w: u16` - Width to copy
- `h: u16` - Height to copy

#### getRow

```zig
pub fn getRow(self: *const Screen, y: u16) ?[]const Cell
```

Gets a read-only slice of a row.

**Parameters:**
- `y: u16` - Row index

**Returns:** Slice of cells or null if out of bounds

#### subRegion

```zig
pub fn subRegion(self: *Screen, x: u16, y: u16, w: u16, h: u16) SubScreen
```

Creates a sub-region view for clipped drawing.

**Parameters:**
- `x: u16` - Offset X
- `y: u16` - Offset Y
- `w: u16` - Sub-region width
- `h: u16` - Sub-region height

**Returns:** SubScreen view

## SubScreen

A view into a sub-region of a screen for clipped operations.

### Fields

- `parent: *Screen` - Parent screen
- `offset_x: u16` - X offset in parent
- `offset_y: u16` - Y offset in parent
- `width: u16` - Sub-region width
- `height: u16` - Sub-region height
- `cursor_x: u16` - Local cursor X
- `cursor_y: u16` - Local cursor Y
- `current_style: Style` - Current style

### Methods

#### setCell

```zig
pub fn setCell(self: *SubScreen, x: u16, y: u16, c: Cell) void
```

Sets a cell in the sub-region.

#### putChar

```zig
pub fn putChar(self: *SubScreen, char: u21) void
```

Writes a character at the current cursor position.

#### putString

```zig
pub fn putString(self: *SubScreen, s: []const u8) void
```

Writes a string at the current cursor position.

#### setStyle

```zig
pub fn setStyle(self: *SubScreen, s: Style) void
```

Sets the current style.

#### moveCursor

```zig
pub fn moveCursor(self: *SubScreen, x: u16, y: u16) void
```

Moves the cursor within the sub-region.

#### clear

```zig
pub fn clear(self: *SubScreen) void
```

Clears the sub-region.

#### fill

```zig
pub fn fill(self: *SubScreen, char: u21) void
```

Fills the sub-region with a character.

#### subRegion

```zig
pub fn subRegion(self: *SubScreen, x: u16, y: u16, w: u16, h: u16) SubScreen
```

Creates a nested sub-region.

## Usage Examples

### Basic Drawing

```zig
var screen = try Screen.init(allocator, 80, 24);
defer screen.deinit();

// Set style and draw text
screen.setStyle(Style.default.bold().foreground(Color.red));
screen.putStringAt(10, 5, "Hello World");

// Draw shapes
screen.hline(0, 0, 80, '─');
screen.vline(0, 0, 24, '│');
screen.drawBox(5, 5, 20, 10, BorderStyle.single);
```

### Sub-region Clipping

```zig
// Create a clipped area
var sub = screen.subRegion(10, 10, 30, 10);

// Drawing in sub-region is automatically clipped
sub.setStyle(Style.default.foreground(Color.blue));
sub.putString("This text is clipped to the sub-region");
```

### Copying Regions

```zig
// Copy a 10x5 region from (5,5) to (20,15)
screen.blit(&other_screen, 5, 5, 20, 15, 10, 5);
```

## See Also

- [Cell API](cell.md)
- [Renderer API](renderer.md)
- Source: `src/core/screen.zig`