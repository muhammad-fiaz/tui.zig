const std = @import("std");
const builtin = @import("builtin");
const screen_mod = @import("screen.zig");
const cell_mod = @import("cell.zig");
const terminal = @import("terminal.zig");
const style_mod = @import("../style/style.zig");

pub const Screen = screen_mod.Screen;
pub const Cell = cell_mod.Cell;
pub const Style = style_mod.Style;

/// Renderer for outputting screen buffer to terminal
pub const Renderer = struct {
    allocator: std.mem.Allocator,

    /// Previous frame buffer for diffing
    prev_buffer: ?Screen,

    /// Output buffer to minimize write syscalls
    output_buffer: std.ArrayListUnmanaged(u8),

    /// Current terminal style
    current_style: Style,

    /// Last cursor position
    last_x: u16,
    last_y: u16,

    /// Stdout handle
    stdout: std.fs.File,

    /// Statistics
    cells_drawn: usize = 0,
    cells_skipped: usize = 0,

    /// Get stdout handle in a cross-platform way for Zig 0.15+
    fn getStdout() std.fs.File {
        if (builtin.os.tag == .windows) {
            const handle = std.os.windows.GetStdHandle(std.os.windows.STD_OUTPUT_HANDLE) catch unreachable;
            return std.fs.File{ .handle = handle };
        } else {
            return std.fs.File{ .handle = std.posix.STDOUT_FILENO };
        }
    }

    /// Create a new renderer
    pub fn init(allocator: std.mem.Allocator) Renderer {
        return .{
            .allocator = allocator,
            .prev_buffer = null,
            .output_buffer = .{},
            .current_style = .{},
            .last_x = 0,
            .last_y = 0,
            .stdout = getStdout(),
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Renderer) void {
        if (self.prev_buffer) |*buf| {
            buf.deinit();
        }
        self.output_buffer.deinit(self.allocator);
    }

    /// Render a screen buffer with diffing
    pub fn render(self: *Renderer, current: *const Screen) !void {
        self.cells_drawn = 0;
        self.cells_skipped = 0;

        // Reset output buffer
        self.output_buffer.clearRetainingCapacity();

        const buf_writer = self.output_buffer.writer(self.allocator);

        // Hide cursor during rendering
        try buf_writer.writeAll(terminal.Escape.hide_cursor);

        if (self.prev_buffer) |*prev| {
            // Diff-based rendering
            if (prev.width == current.width and prev.height == current.height) {
                try self.renderDiff(current, prev, buf_writer);
            } else {
                // Screen size changed, full redraw
                try prev.resize(current.width, current.height);
                try self.renderFull(current, buf_writer);
            }
        } else {
            // First frame, full render
            self.prev_buffer = try Screen.init(self.allocator, current.width, current.height);
            try self.renderFull(current, buf_writer);
        }

        // Reset style at end
        try buf_writer.writeAll(terminal.Escape.reset);

        // Show cursor if needed
        try buf_writer.writeAll(terminal.Escape.show_cursor);

        // Write all output at once
        _ = try self.stdout.writeAll(self.output_buffer.items);

        // Update previous buffer
        if (self.prev_buffer) |*prev| {
            @memcpy(prev.cells, current.cells);
        }
    }

    /// Render entire screen (no diffing)
    fn renderFull(self: *Renderer, current: *const Screen, writer: anytype) !void {
        // Move to home
        try writer.writeAll(terminal.Escape.home);
        try writer.writeAll(terminal.Escape.clear_screen);

        self.current_style = .{};
        self.last_x = 0;
        self.last_y = 0;

        for (0..current.height) |y| {
            try self.moveCursorTo(0, @intCast(y), writer);

            for (0..current.width) |x| {
                if (current.getCell(@intCast(x), @intCast(y))) |cell| {
                    try self.renderCell(cell.*, @intCast(x), @intCast(y), writer);
                }
            }
        }
    }

    /// Render only changed cells
    fn renderDiff(self: *Renderer, current: *const Screen, prev: *const Screen, writer: anytype) !void {
        for (0..current.height) |y| {
            for (0..current.width) |x| {
                const curr_cell = current.getCell(@intCast(x), @intCast(y)) orelse continue;
                const prev_cell = prev.getCell(@intCast(x), @intCast(y)) orelse continue;

                if (!curr_cell.eql(prev_cell.*)) {
                    try self.moveCursorTo(@intCast(x), @intCast(y), writer);
                    try self.renderCell(curr_cell.*, @intCast(x), @intCast(y), writer);
                    self.cells_drawn += 1;
                } else {
                    self.cells_skipped += 1;
                }
            }
        }
    }

    /// Render a single cell
    fn renderCell(self: *Renderer, cell: Cell, x: u16, y: u16, writer: anytype) !void {
        _ = x;
        _ = y;

        // Skip continuation cells for wide characters
        if (cell.width == 0) return;

        // Update style if changed
        if (!cell.style.eql(self.current_style)) {
            try cell.style.toDiffAnsi(self.current_style, writer);
            self.current_style = cell.style;
        }

        // Write the cell content
        try cell.writeTo(writer);

        // Update cursor tracking
        self.last_x += cell.width;
    }

    /// Move cursor to position with optimal path
    fn moveCursorTo(self: *Renderer, x: u16, y: u16, writer: anytype) !void {
        if (self.last_x == x and self.last_y == y) return;

        // Calculate distance
        const dx = @as(i32, x) - @as(i32, self.last_x);
        const dy = @as(i32, y) - @as(i32, self.last_y);

        // Optimize cursor movement
        if (dy == 0 and dx == 1) {
            // Already at correct position (after writing a char)
        } else if (dy == 0 and dx > 0 and dx < 8) {
            // Move right
            try writer.print("\x1b[{d}C", .{@as(u16, @intCast(dx))});
        } else if (dy == 0 and dx < 0 and dx > -8) {
            // Move left
            try writer.print("\x1b[{d}D", .{@as(u16, @intCast(-dx))});
        } else if (dx == 0 and dy == 1) {
            // Move down one line
            try writer.writeAll("\n");
            if (x > 0) {
                try writer.print("\x1b[{d}G", .{x + 1});
            } else {
                try writer.writeAll("\r");
            }
        } else {
            // Full position move
            try writer.print("\x1b[{d};{d}H", .{ y + 1, x + 1 });
        }

        self.last_x = x;
        self.last_y = y;
    }

    /// Force a full redraw on next render
    pub fn invalidate(self: *Renderer) void {
        if (self.prev_buffer) |*prev| {
            prev.clear();
        }
    }

    /// Get rendering statistics
    pub fn getStats(self: *Renderer) RenderStats {
        return .{
            .cells_drawn = self.cells_drawn,
            .cells_skipped = self.cells_skipped,
            .efficiency = if (self.cells_drawn + self.cells_skipped > 0)
                @as(f32, @floatFromInt(self.cells_skipped)) / @as(f32, @floatFromInt(self.cells_drawn + self.cells_skipped))
            else
                1.0,
        };
    }
};

/// Rendering statistics
pub const RenderStats = struct {
    cells_drawn: usize,
    cells_skipped: usize,
    efficiency: f32,
};

/// Simple immediate-mode renderer (no diffing)
pub const ImmediateRenderer = struct {
    stdout: std.fs.File,
    current_style: Style = .{},

    pub fn init() ImmediateRenderer {
        const stdout = if (builtin.os.tag == .windows)
            std.fs.File{ .handle = std.os.windows.GetStdHandle(std.os.windows.STD_OUTPUT_HANDLE) catch unreachable }
        else
            std.fs.File{ .handle = std.posix.STDOUT_FILENO };
        return .{
            .stdout = stdout,
        };
    }

    pub fn render(self: *ImmediateRenderer, screen_buf: *const Screen) !void {
        // Clear and home
        _ = try self.stdout.writeAll(terminal.Escape.clear_screen);
        _ = try self.stdout.writeAll(terminal.Escape.home);

        for (0..screen_buf.height) |y| {
            for (0..screen_buf.width) |x| {
                if (screen_buf.getCell(@intCast(x), @intCast(y))) |cell| {
                    if (cell.width == 0) continue;

                    if (!cell.style.eql(self.current_style)) {
                        // Write style using buffer
                        var buf: [64]u8 = undefined;
                        const len = cell.style.toAnsiBuf(&buf);
                        _ = try self.stdout.writeAll(buf[0..len]);
                        self.current_style = cell.style;
                    }

                    // Write cell content
                    var cell_buf: [8]u8 = undefined;
                    const cell_len = cell.writeToBuffer(&cell_buf);
                    _ = try self.stdout.writeAll(cell_buf[0..cell_len]);
                }
            }
            if (y + 1 < screen_buf.height) {
                _ = try self.stdout.writeAll("\r\n");
            }
        }

        _ = try self.stdout.writeAll(terminal.Escape.reset);
    }
};

test "renderer initialization" {
    const allocator = std.testing.allocator;
    var renderer_inst = Renderer.init(allocator);
    defer renderer_inst.deinit();

    try std.testing.expectEqual(@as(usize, 0), renderer_inst.cells_drawn);
}
