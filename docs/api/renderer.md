# Renderer

The renderer handles outputting the screen buffer to the terminal with efficient diff-based rendering and ANSI escape sequence management.

## Overview

The renderer provides:
- Diff-based rendering to minimize terminal updates
- ANSI escape sequence generation for styling
- Cursor position optimization
- Cross-platform terminal output

## Types

### RenderStats

Statistics from a render operation.

### Fields

- `cells_drawn: usize` - Number of cells that were updated
- `cells_skipped: usize` - Number of cells that remained unchanged
- `efficiency: f32` - Rendering efficiency (0.0 to 1.0)

## Renderer

Main diff-based renderer for optimal performance.

### Fields

- `allocator: std.mem.Allocator` - Memory allocator
- `prev_buffer: ?Screen` - Previous frame for diffing
- `output_buffer: std.ArrayListUnmanaged(u8)` - Buffered output
- `current_style: Style` - Current terminal style state
- `last_x: u16` - Last cursor X position
- `last_y: u16` - Last cursor Y position
- `stdout: std.fs.File` - Standard output handle
- `cells_drawn: usize` - Statistics: cells drawn this frame
- `cells_skipped: usize` - Statistics: cells skipped this frame

### Methods

#### init

```zig
pub fn init(allocator: std.mem.Allocator) Renderer
```

Creates a new renderer instance.

**Parameters:**
- `allocator: std.mem.Allocator` - Memory allocator

**Returns:** New Renderer instance

#### deinit

```zig
pub fn deinit(self: *Renderer) void
```

Cleans up renderer resources.

#### render

```zig
pub fn render(self: *Renderer, current: *const Screen) !void
```

Renders a screen buffer to the terminal.

**Parameters:**
- `current: *const Screen` - Screen buffer to render

Performs diff-based rendering on subsequent calls, full rendering on first call or size changes.

#### invalidate

```zig
pub fn invalidate(self: *Renderer) void
```

Forces a full redraw on the next render call.

Clears the previous buffer to ensure all cells are re-rendered.

#### getStats

```zig
pub fn getStats(self: *Renderer) RenderStats
```

Gets rendering statistics from the last frame.

**Returns:** RenderStats with performance metrics

## ImmediateRenderer

Simple immediate-mode renderer without diffing.

### Fields

- `stdout: std.fs.File` - Standard output handle
- `current_style: Style` - Current style state

### Methods

#### init

```zig
pub fn init() ImmediateRenderer
```

Creates a new immediate renderer.

**Returns:** New ImmediateRenderer instance

#### render

```zig
pub fn render(self: *ImmediateRenderer, screen_buf: *const Screen) !void
```

Renders the entire screen buffer immediately.

**Parameters:**
- `screen_buf: *const Screen` - Screen buffer to render

Always performs a full redraw of the entire screen.

## Usage Examples

### Basic Rendering

```zig
const allocator = std.heap.page_allocator;
var renderer = Renderer.init(allocator);
defer renderer.deinit();

var screen = try Screen.init(allocator, 80, 24);
defer screen.deinit();

// ... populate screen ...

try renderer.render(&screen);

// Get performance stats
const stats = renderer.getStats();
std.debug.print("Efficiency: {d:.2}%\n", .{stats.efficiency * 100});
```

### Immediate Rendering

```zig
var renderer = ImmediateRenderer.init();

// For simple cases or debugging
try renderer.render(&screen);
```

### Forcing Redraw

```zig
// When screen content changes significantly
renderer.invalidate();
try renderer.render(&screen); // Will do full redraw
```

## Performance Considerations

- **Diff Rendering**: The main `Renderer` only updates changed cells
- **Buffering**: Output is buffered to minimize syscalls
- **Cursor Optimization**: Cursor movement is optimized for common patterns
- **Style Diffing**: Only changed style attributes are sent to terminal

## See Also

- [Screen API](screen.md)
- [Style API](style.md)
- Source: `src/core/renderer.zig`