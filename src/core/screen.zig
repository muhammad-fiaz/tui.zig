//! Screen buffer for off-screen rendering.
//!
//! The screen buffer maintains a 2D grid of cells that represents
//! what should be displayed on the terminal. Double-buffering is
//! used to enable efficient diff-based rendering.

const std = @import("std");
const cell = @import("cell.zig");
const style = @import("../style/style.zig");
const unicode = @import("../unicode/unicode.zig");

pub const Cell = cell.Cell;
pub const Style = style.Style;

/// Screen buffer for rendering
pub const Screen = struct {
    allocator: std.mem.Allocator,

    /// Cell grid (row-major order)
    cells: []Cell,

    /// Screen dimensions
    width: u16,
    height: u16,

    /// Cursor position
    cursor_x: u16 = 0,
    cursor_y: u16 = 0,

    /// Current style for drawing operations
    current_style: Style = .{},

    /// Create a new screen buffer
    pub fn init(allocator: std.mem.Allocator, width: u16, height: u16) !Screen {
        const size = @as(usize, width) * @as(usize, height);
        const cells = try allocator.alloc(Cell, size);
        @memset(cells, Cell.blank);

        return .{
            .allocator = allocator,
            .cells = cells,
            .width = width,
            .height = height,
        };
    }

    /// Free the screen buffer
    pub fn deinit(self: *Screen) void {
        self.allocator.free(self.cells);
    }

    /// Resize the screen buffer
    pub fn resize(self: *Screen, new_width: u16, new_height: u16) !void {
        const new_size = @as(usize, new_width) * @as(usize, new_height);
        const new_cells = try self.allocator.alloc(Cell, new_size);
        @memset(new_cells, Cell.blank);

        // Copy existing content
        const copy_width = @min(self.width, new_width);
        const copy_height = @min(self.height, new_height);

        for (0..copy_height) |y| {
            const old_row_start = y * self.width;
            const new_row_start = y * new_width;
            @memcpy(
                new_cells[new_row_start..][0..copy_width],
                self.cells[old_row_start..][0..copy_width],
            );
        }

        self.allocator.free(self.cells);
        self.cells = new_cells;
        self.width = new_width;
        self.height = new_height;

        // Clamp cursor position
        self.cursor_x = @min(self.cursor_x, new_width -| 1);
        self.cursor_y = @min(self.cursor_y, new_height -| 1);
    }

    /// Clear the entire screen
    pub fn clear(self: *Screen) void {
        @memset(self.cells, Cell.blank);
        self.cursor_x = 0;
        self.cursor_y = 0;
    }

    /// Clear the screen with a specific style
    pub fn clearWithStyle(self: *Screen, s: Style) void {
        const blank = Cell{ .content = .{ .codepoint = ' ' }, .style = s };
        @memset(self.cells, blank);
    }

    /// Get a cell at a specific position
    pub fn getCell(self: *const Screen, x: u16, y: u16) ?*const Cell {
        if (x >= self.width or y >= self.height) return null;
        const idx = @as(usize, y) * @as(usize, self.width) + @as(usize, x);
        return &self.cells[idx];
    }

    /// Get a mutable cell at a specific position
    pub fn getCellMut(self: *Screen, x: u16, y: u16) ?*Cell {
        if (x >= self.width or y >= self.height) return null;
        const idx = @as(usize, y) * @as(usize, self.width) + @as(usize, x);
        return &self.cells[idx];
    }

    /// Set a cell at a specific position
    pub fn setCell(self: *Screen, x: u16, y: u16, c: Cell) void {
        if (x >= self.width or y >= self.height) return;
        const idx = @as(usize, y) * @as(usize, self.width) + @as(usize, x);
        self.cells[idx] = c;

        // Handle wide characters - blank the next cell
        if (c.width == 2 and x + 1 < self.width) {
            self.cells[idx + 1] = Cell{
                .content = .{ .codepoint = ' ' },
                .style = c.style,
                .width = 0, // Continuation of wide char
            };
        }
    }

    /// Set the current style
    pub fn setStyle(self: *Screen, s: Style) void {
        self.current_style = s;
    }

    /// Move the cursor
    pub fn moveCursor(self: *Screen, x: u16, y: u16) void {
        self.cursor_x = @min(x, self.width -| 1);
        self.cursor_y = @min(y, self.height -| 1);
    }

    /// Write a character at the current cursor position
    pub fn putChar(self: *Screen, char: u21) void {
        const c = Cell.initStyled(char, self.current_style);
        self.setCell(self.cursor_x, self.cursor_y, c);

        // Advance cursor
        self.cursor_x += c.width;
        if (self.cursor_x >= self.width) {
            self.cursor_x = 0;
            self.cursor_y = @min(self.cursor_y + 1, self.height -| 1);
        }
    }

    /// Write a string at the current cursor position
    pub fn putString(self: *Screen, s: []const u8) void {
        var iter = std.unicode.Utf8Iterator{ .bytes = s, .i = 0 };
        while (iter.nextCodepoint()) |cp| {
            self.putChar(cp);
        }
    }

    /// Write a string at a specific position
    pub fn putStringAt(self: *Screen, x: u16, y: u16, s: []const u8) void {
        self.cursor_x = x;
        self.cursor_y = y;
        self.putString(s);
    }

    /// Draw a horizontal line
    pub fn hline(self: *Screen, x: u16, y: u16, len: u16, char: u21) void {
        if (y >= self.height) return;

        const end_x = @min(x + len, self.width);
        for (x..end_x) |xi| {
            const c = Cell.initStyled(char, self.current_style);
            self.setCell(@intCast(xi), y, c);
        }
    }

    /// Draw a vertical line
    pub fn vline(self: *Screen, x: u16, y: u16, len: u16, char: u21) void {
        if (x >= self.width) return;

        const end_y = @min(y + len, self.height);
        for (y..end_y) |yi| {
            const c = Cell.initStyled(char, self.current_style);
            self.setCell(x, @intCast(yi), c);
        }
    }

    /// Fill a rectangular region
    pub fn fill(self: *Screen, x: u16, y: u16, w: u16, h: u16, char: u21) void {
        const end_x = @min(x + w, self.width);
        const end_y = @min(y + h, self.height);

        for (y..end_y) |yi| {
            for (x..end_x) |xi| {
                const c = Cell.initStyled(char, self.current_style);
                self.setCell(@intCast(xi), @intCast(yi), c);
            }
        }
    }

    /// Draw a box border
    pub fn drawBox(self: *Screen, x: u16, y: u16, w: u16, h: u16, border: style.BorderStyle) void {
        if (w < 2 or h < 2) return;

        const chars = border.chars();

        // Corners
        self.setCell(x, y, Cell.initStyled(chars.top_left, self.current_style));
        self.setCell(x + w - 1, y, Cell.initStyled(chars.top_right, self.current_style));
        self.setCell(x, y + h - 1, Cell.initStyled(chars.bottom_left, self.current_style));
        self.setCell(x + w - 1, y + h - 1, Cell.initStyled(chars.bottom_right, self.current_style));

        // Horizontal edges
        self.hline(x + 1, y, w - 2, chars.horizontal);
        self.hline(x + 1, y + h - 1, w - 2, chars.horizontal);

        // Vertical edges
        self.vline(x, y + 1, h - 2, chars.vertical);
        self.vline(x + w - 1, y + 1, h - 2, chars.vertical);
    }

    /// Copy a region from another screen
    pub fn blit(self: *Screen, src: *const Screen, src_x: u16, src_y: u16, dst_x: u16, dst_y: u16, w: u16, h: u16) void {
        const actual_w = @min(w, @min(src.width - src_x, self.width - dst_x));
        const actual_h = @min(h, @min(src.height - src_y, self.height - dst_y));

        for (0..actual_h) |dy| {
            for (0..actual_w) |dx| {
                if (src.getCell(src_x + @as(u16, @intCast(dx)), src_y + @as(u16, @intCast(dy)))) |c| {
                    self.setCell(dst_x + @as(u16, @intCast(dx)), dst_y + @as(u16, @intCast(dy)), c.*);
                }
            }
        }
    }

    /// Get a row slice
    pub fn getRow(self: *const Screen, y: u16) ?[]const Cell {
        if (y >= self.height) return null;
        const start = @as(usize, y) * @as(usize, self.width);
        return self.cells[start..][0..self.width];
    }

    /// Create a sub-region view (for clipping)
    pub fn subRegion(self: *Screen, x: u16, y: u16, w: u16, h: u16) SubScreen {
        return SubScreen{
            .parent = self,
            .offset_x = x,
            .offset_y = y,
            .width = @min(w, self.width -| x),
            .height = @min(h, self.height -| y),
        };
    }
};

/// A view into a sub-region of a screen for clipped drawing
pub const SubScreen = struct {
    parent: *Screen,
    offset_x: u16,
    offset_y: u16,
    width: u16,
    height: u16,
    cursor_x: u16 = 0,
    cursor_y: u16 = 0,
    current_style: Style = .{},

    pub fn setCell(self: *SubScreen, x: u16, y: u16, c: Cell) void {
        if (x >= self.width or y >= self.height) return;
        self.parent.setCell(self.offset_x + x, self.offset_y + y, c);
    }

    pub fn putChar(self: *SubScreen, char: u21) void {
        if (self.cursor_x >= self.width) return;
        const c = Cell.initStyled(char, self.current_style);
        self.setCell(self.cursor_x, self.cursor_y, c);
        self.cursor_x += c.width;
    }

    pub fn putString(self: *SubScreen, s: []const u8) void {
        var iter = std.unicode.Utf8Iterator{ .bytes = s, .i = 0 };
        while (iter.nextCodepoint()) |cp| {
            if (self.cursor_x >= self.width) break;
            self.putChar(cp);
        }
    }

    pub fn setStyle(self: *SubScreen, s: Style) void {
        self.current_style = s;
    }

    pub fn moveCursor(self: *SubScreen, x: u16, y: u16) void {
        self.cursor_x = @min(x, self.width -| 1);
        self.cursor_y = @min(y, self.height -| 1);
    }

    pub fn clear(self: *SubScreen) void {
        const blank = Cell{ .content = .{ .codepoint = ' ' }, .style = self.current_style };
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                self.parent.setCell(
                    self.offset_x + @as(u16, @intCast(x)),
                    self.offset_y + @as(u16, @intCast(y)),
                    blank,
                );
            }
        }
    }

    /// Fill sub-screen with a character
    pub fn fill(self: *SubScreen, char: u21) void {
        const c = Cell.initStyled(char, self.current_style);
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                self.parent.setCell(
                    self.offset_x + @as(u16, @intCast(x)),
                    self.offset_y + @as(u16, @intCast(y)),
                    c,
                );
            }
        }
    }

    /// Create a nested sub-region
    pub fn subRegion(self: *SubScreen, x: u16, y: u16, w: u16, h: u16) SubScreen {
        return SubScreen{
            .parent = self.parent,
            .offset_x = self.offset_x + x,
            .offset_y = self.offset_y + y,
            .width = @min(w, self.width -| x),
            .height = @min(h, self.height -| y),
        };
    }
};

test "screen creation" {
    const allocator = std.testing.allocator;
    var screen_buf = try Screen.init(allocator, 80, 24);
    defer screen_buf.deinit();

    try std.testing.expectEqual(@as(u16, 80), screen_buf.width);
    try std.testing.expectEqual(@as(u16, 24), screen_buf.height);
}

test "screen cell operations" {
    const allocator = std.testing.allocator;
    var screen_buf = try Screen.init(allocator, 80, 24);
    defer screen_buf.deinit();

    screen_buf.putChar('A');

    const c = screen_buf.getCell(0, 0);
    try std.testing.expect(c != null);
}

test "screen resize" {
    const allocator = std.testing.allocator;
    var screen_buf = try Screen.init(allocator, 80, 24);
    defer screen_buf.deinit();

    try screen_buf.resize(100, 30);
    try std.testing.expectEqual(@as(u16, 100), screen_buf.width);
    try std.testing.expectEqual(@as(u16, 30), screen_buf.height);
}

test "subscreen clipping" {
    const allocator = std.testing.allocator;
    var screen_buf = try Screen.init(allocator, 80, 24);
    defer screen_buf.deinit();

    const sub = screen_buf.subRegion(10, 5, 20, 10);
    try std.testing.expectEqual(@as(u16, 20), sub.width);
    try std.testing.expectEqual(@as(u16, 10), sub.height);
}
