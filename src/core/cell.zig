//! Cell representation for the terminal screen buffer.
//!
//! A Cell represents a single character position in the terminal with
//! associated style information.

const std = @import("std");
const style = @import("../style/style.zig");
const unicode = @import("../unicode/unicode.zig");

pub const Style = style.Style;
pub const Color = style.Color;

/// A single cell in the terminal screen buffer
pub const Cell = struct {
    /// The character(s) to display (grapheme cluster)
    /// A grapheme can be multiple codepoints (e.g., emoji + modifier)
    content: Content = .{ .codepoint = ' ' },

    /// Cell style
    style: Style = .{},

    /// Display width (1 for normal chars, 2 for wide chars like CJK, 0 for combining)
    width: u2 = 1,

    /// Content type
    pub const Content = union(enum) {
        /// Single codepoint (most common case)
        codepoint: u21,

        /// Multiple codepoints for grapheme clusters
        grapheme: []const u8,
    };

    /// Default blank cell
    pub const blank = Cell{};

    /// Create a cell with a single character
    pub fn init(char: u21) Cell {
        return .{
            .content = .{ .codepoint = char },
            .width = unicode.charWidth(char),
        };
    }

    /// Create a cell with a character and style
    pub fn initStyled(char: u21, s: Style) Cell {
        return .{
            .content = .{ .codepoint = char },
            .style = s,
            .width = unicode.charWidth(char),
        };
    }

    /// Create a cell from a grapheme cluster
    pub fn fromGrapheme(grapheme: []const u8) Cell {
        const w = unicode.graphemeWidth(grapheme);
        return .{
            .content = .{ .grapheme = grapheme },
            .width = @intCast(if (w > 2) 2 else if (w == 0) 0 else w),
        };
    }

    /// Get the character content as a string
    pub fn getContent(self: Cell, buf: *[4]u8) []const u8 {
        switch (self.content) {
            .codepoint => |cp| {
                const len = std.unicode.utf8Encode(cp, buf) catch 1;
                return buf[0..len];
            },
            .grapheme => |g| return g,
        }
    }

    /// Check if this cell is empty (space with default style)
    pub fn isEmpty(self: Cell) bool {
        const is_space = switch (self.content) {
            .codepoint => |cp| cp == ' ',
            .grapheme => |g| g.len == 1 and g[0] == ' ',
        };
        return is_space and self.style.eql(Style.default);
    }

    /// Check if two cells are equal
    pub fn eql(self: Cell, other: Cell) bool {
        const content_eq = switch (self.content) {
            .codepoint => |cp| switch (other.content) {
                .codepoint => |ocp| cp == ocp,
                .grapheme => false,
            },
            .grapheme => |g| switch (other.content) {
                .codepoint => false,
                .grapheme => |og| std.mem.eql(u8, g, og),
            },
        };

        return content_eq and self.style.eql(other.style) and self.width == other.width;
    }

    /// Set the character content
    pub fn setChar(self: *Cell, char: u21) void {
        self.content = .{ .codepoint = char };
        self.width = unicode.charWidth(char);
    }

    /// Set the style
    pub fn setStyle(self: *Cell, s: Style) void {
        self.style = s;
    }

    /// Clear the cell to blank
    pub fn clear(self: *Cell) void {
        self.* = Cell.blank;
    }

    /// Clear the cell but keep the style
    pub fn clearKeepStyle(self: *Cell) void {
        self.content = .{ .codepoint = ' ' };
        self.width = 1;
    }

    /// Write the cell content to a writer
    pub fn writeTo(self: Cell, writer: anytype) !void {
        switch (self.content) {
            .codepoint => |cp| {
                var buf: [4]u8 = undefined;
                const len = std.unicode.utf8Encode(cp, &buf) catch 1;
                try writer.writeAll(buf[0..len]);
            },
            .grapheme => |g| try writer.writeAll(g),
        }
    }
};

/// A row of cells
pub const CellRow = struct {
    cells: []Cell,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: usize) !CellRow {
        const cells = try allocator.alloc(Cell, width);
        @memset(cells, Cell.blank);
        return .{
            .cells = cells,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CellRow) void {
        self.allocator.free(self.cells);
    }

    pub fn get(self: CellRow, x: usize) ?*Cell {
        if (x >= self.cells.len) return null;
        return &self.cells[x];
    }

    pub fn set(self: *CellRow, x: usize, cell: Cell) void {
        if (x < self.cells.len) {
            self.cells[x] = cell;
        }
    }

    pub fn clear(self: *CellRow) void {
        @memset(self.cells, Cell.blank);
    }

    pub fn resize(self: *CellRow, new_width: usize) !void {
        if (new_width == self.cells.len) return;

        const new_cells = try self.allocator.alloc(Cell, new_width);
        const copy_len = @min(self.cells.len, new_width);

        @memcpy(new_cells[0..copy_len], self.cells[0..copy_len]);

        if (new_width > self.cells.len) {
            @memset(new_cells[copy_len..], Cell.blank);
        }

        self.allocator.free(self.cells);
        self.cells = new_cells;
    }
};

test "cell creation" {
    const cell = Cell.init('A');
    var buf: [4]u8 = undefined;
    try std.testing.expectEqualStrings("A", cell.getContent(&buf));
    try std.testing.expectEqual(@as(u2, 1), cell.width);
}

test "cell styling" {
    const s = Style.default.bold();
    const cell = Cell.initStyled('B', s);
    try std.testing.expect(cell.style.attrs.bold);
}

test "cell equality" {
    const cell1 = Cell.init('A');
    const cell2 = Cell.init('A');
    const cell3 = Cell.init('B');

    try std.testing.expect(cell1.eql(cell2));
    try std.testing.expect(!cell1.eql(cell3));
}

test "blank cell" {
    const cell = Cell.blank;
    try std.testing.expect(cell.isEmpty());
}
