// Grid layout widget for arranging widgets in rows and columns.

const std = @import("std");
const widget = @import("widget.zig");
const layout = @import("../layout/layout.zig");

pub const GridCell = struct {
    row: usize,
    col: usize,
    row_span: usize = 1,
    col_span: usize = 1,
};

pub const Grid = struct {
    rows: usize,
    cols: usize,
    gap: u16 = 1,
    base: widget.StatefulWidget = .{},

    pub fn init(rows: usize, cols: usize) Grid {
        return .{ .rows = rows, .cols = cols };
    }

    pub fn withGap(self: Grid, gap: u16) Grid {
        var result = self;
        result.gap = gap;
        return result;
    }

    pub fn getCellBounds(self: *Grid, cell: GridCell, total_width: u16, total_height: u16) layout.Rect {
        const cell_width = total_width / @as(u16, @intCast(self.cols));
        const cell_height = total_height / @as(u16, @intCast(self.rows));
        
        return .{
            .x = @intCast(cell.col * cell_width + self.gap),
            .y = @intCast(cell.row * cell_height + self.gap),
            .width = @intCast(cell.col_span * cell_width - self.gap * 2),
            .height = @intCast(cell.row_span * cell_height - self.gap * 2),
        };
    }
};

test "Grid creation" {
    const grid = Grid.init(3, 3);
    try std.testing.expectEqual(@as(usize, 3), grid.rows);
    try std.testing.expectEqual(@as(usize, 3), grid.cols);
}

test "Grid cell bounds" {
    var grid = Grid.init(2, 2);
    const bounds = grid.getCellBounds(.{ .row = 0, .col = 0 }, 100, 100);
    try std.testing.expectEqual(@as(u16, 1), bounds.x);
    try std.testing.expectEqual(@as(u16, 1), bounds.y);
}
