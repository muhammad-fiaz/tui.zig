# Grid

Grid layout for arranging widgets in rows and columns.

## Basic Usage

```zig
var grid = tui.Grid.init(3, 3)
    .withGap(1);

const cell = tui.grid.GridCell{ .row = 0, .col = 0, .row_span = 1, .col_span = 1 };
const bounds = grid.getCellBounds(cell, total_width, total_height);
```

## Features

- Flexible row/column configuration
- Cell spanning
- Gap control
- Responsive sizing

## API

```zig
pub fn init(rows: usize, cols: usize) Grid
pub fn withGap(self: Grid, gap: u16) Grid
pub fn getCellBounds(self: *Grid, cell: GridCell, total_width: u16, total_height: u16) Rect

pub const GridCell = struct {
    row: usize,
    col: usize,
    row_span: usize = 1,
    col_span: usize = 1,
};
```

## Example

```zig
const Dashboard = struct {
    grid: tui.Grid,

    pub fn init() Dashboard {
        return .{
            .grid = tui.Grid.init(2, 3).withGap(2),
        };
    }

    pub fn render(self: *Dashboard, ctx: *tui.RenderContext) void {
        var screen = ctx.getSubScreen();
        
        // Header spans all columns
        const header_cell = tui.grid.GridCell{ .row = 0, .col = 0, .col_span = 3 };
        const header_bounds = self.grid.getCellBounds(header_cell, screen.width, screen.height);
        var header_ctx = ctx.child(header_bounds);
        // Render header widget
        
        // Three columns in second row
        for (0..3) |col| {
            const cell = tui.grid.GridCell{ .row = 1, .col = col };
            const bounds = self.grid.getCellBounds(cell, screen.width, screen.height);
            var cell_ctx = ctx.child(bounds);
            // Render cell widget
        }
    }
};
```
