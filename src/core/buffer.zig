//! 2D terminal cell grid (`Buffer`) and zero-allocation frame diff iterator (`BufferDiff`).
//!
//! `Buffer` owns its cell array and an internal `ArenaAllocator` (used only for
//! rare symbols > 32 bytes). Resizing and clearing retain allocated capacity so
//! steady-state rendering performs zero heap allocations per frame.

const std = @import("std");
const geom = @import("geometry.zig");
const cell_mod = @import("cell.zig");
const style_root = @import("../style/root.zig");
const grapheme = @import("../text/grapheme.zig");
const testing = std.testing;

pub const Rect = geom.Rect;
pub const Position = geom.Position;
pub const Cell = cell_mod.Cell;
pub const CellDiffOption = cell_mod.CellDiffOption;
pub const Style = style_root.Style;
pub const Color = style_root.Color;

/// A single changed cell yielded by `BufferDiff`.
pub const DiffEntry = struct {
    x: u16,
    y: u16,
    cell: *const Cell,
};

/// 2D grid of `Cell`s representing a rectangular terminal area.
pub const Buffer = struct {
    /// Backing allocator provided by caller.
    allocator: std.mem.Allocator,
    /// Bounding rectangle in terminal coordinates.
    area: Rect,
    /// Active slice of `area.area()` cells.
    cells: []Cell,
    /// Full allocated backing slice (may exceed `cells.len` to avoid realloc on shrink/regrow).
    backing: []Cell,
    /// Arena holding overflow symbols (> 32 bytes); reset with `.retain_capacity` on `clear`.
    symbol_arena: std.heap.ArenaAllocator,

    /// Allocates a `Buffer` initialized to `Cell.empty` for `area`.
    /// Caller owns the buffer and must call `deinit()`.
    pub fn init(allocator: std.mem.Allocator, area: Rect) std.mem.Allocator.Error!Buffer {
        const len: usize = @intCast(area.area());
        const backing: []Cell = if (len > 0) try allocator.alloc(Cell, len) else &.{};
        if (backing.len > 0) @memset(backing, Cell.empty);
        return .{
            .allocator = allocator,
            .area = area,
            .cells = backing,
            .backing = backing,
            .symbol_arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    /// Frees all owned memory. Safe to call on an already-deinitialized or empty buffer.
    pub fn deinit(self: *Buffer) void {
        if (self.backing.len > 0) {
            self.allocator.free(self.backing);
        }
        self.symbol_arena.deinit();
        self.backing = &.{};
        self.cells = &.{};
        self.area = Rect.zero;
    }

    /// Resets all cells to `Cell.empty` while retaining allocated capacity.
    pub fn clear(self: *Buffer) void {
        @memset(self.cells, Cell.empty);
        _ = self.symbol_arena.reset(.retain_capacity);
    }

    /// Resizes the buffer to `new_area`, reusing existing allocation capacity when possible.
    /// Clears cell contents to `Cell.empty`.
    pub fn resize(self: *Buffer, new_area: Rect) std.mem.Allocator.Error!void {
        const needed: usize = @intCast(new_area.area());
        if (needed > self.backing.len) {
            const next_backing = try self.allocator.alloc(Cell, needed);
            if (self.backing.len > 0) self.allocator.free(self.backing);
            self.backing = next_backing;
        }
        self.area = new_area;
        self.cells = self.backing[0..needed];
        self.clear();
    }

    /// Returns the flat index for `(x, y)` or `null` if outside `self.area`.
    pub fn indexOf(self: *const Buffer, x: u16, y: u16) ?usize {
        if (!self.area.containsXY(x, y)) return null;
        const dx: usize = x - self.area.x;
        const dy: usize = y - self.area.y;
        return dy * @as(usize, self.area.width) + dx;
    }

    /// Returns an immutable pointer to the cell at `(x, y)`, or `null` if out of bounds.
    pub fn get(self: *const Buffer, x: u16, y: u16) ?*const Cell {
        const idx = self.indexOf(x, y) orelse return null;
        return &self.cells[idx];
    }

    /// Returns a mutable pointer to the cell at `(x, y)`, or `null` if out of bounds.
    pub fn getMut(self: *Buffer, x: u16, y: u16) ?*Cell {
        const idx = self.indexOf(x, y) orelse return null;
        return &self.cells[idx];
    }

    /// Stores `sym` into `cell`, using `symbol_arena` only when `sym.len > 32`.
    pub fn setCellSymbol(self: *Buffer, cell: *Cell, sym: []const u8) std.mem.Allocator.Error!void {
        if (sym.len <= cell_mod.inline_symbol_capacity) {
            cell.setSymbol(sym);
            return;
        }
        const duped = try self.symbol_arena.allocator().dupe(u8, sym);
        cell.setOverflowSymbol(duped);
    }

    /// Copies the contents and area of `src` into `self`, reusing capacity.
    pub fn copyFrom(self: *Buffer, src: *const Buffer) std.mem.Allocator.Error!void {
        try self.resize(src.area);
        for (src.cells, self.cells) |src_cell, *dst_cell| {
            dst_cell.* = src_cell;
            if (src_cell.symbol_len == 255) {
                if (src_cell.overflow) |ov| {
                    dst_cell.overflow = try self.symbol_arena.allocator().dupe(u8, ov);
                }
            }
        }
    }

    /// Writes `text` starting at `(x, y)` with `s`, clipping to `self.area` and
    /// stopping at `max_width` columns. Returns the cursor end position.
    pub fn setStringN(
        self: *Buffer,
        x: u16,
        y: u16,
        text: []const u8,
        max_width: u16,
        s: Style,
    ) Position {
        return self.setStringClipped(x, y, text, max_width, s, self.area);
    }

    /// Writes `text` at `(x, y)` clipped to `clip` (intersected with `self.area`).
    /// Properly clears covered trailing cells for wide graphemes and drops control characters.
    pub fn setStringClipped(
        self: *Buffer,
        x: u16,
        y: u16,
        text: []const u8,
        max_width: u16,
        s: Style,
        clip: Rect,
    ) Position {
        const bounds = self.area.intersection(clip);
        if (bounds.isEmpty() or y < bounds.top() or y >= bounds.bottom()) {
            return .{ .x = x, .y = y };
        }
        if (x >= bounds.right() or max_width == 0) {
            return .{ .x = x, .y = y };
        }

        var col: u16 = x;
        var written_cols: u16 = 0;
        var it = grapheme.GraphemeIterator.init(text);
        while (it.next()) |g| {
            if (g.width == 0) continue; // Filter control / zero-width standalone bytes.
            if (written_cols + g.width > max_width) break;
            if (col + g.width > bounds.right()) break;

            if (col >= bounds.left()) {
                // If overwriting the trailing cell of a previously placed wide char, clear its leader.
                if (col > bounds.left()) {
                    if (self.getMut(col, y)) |cur_cell| {
                        if (cur_cell.diff_option == .skip) {
                            if (self.getMut(col - 1, y)) |prev_cell| {
                                if (prev_cell.cellWidth() > 1) {
                                    prev_cell.setSymbol(" ");
                                }
                            }
                        }
                    }
                }

                if (self.getMut(col, y)) |cell| {
                    self.setCellSymbol(cell, g.slice) catch {
                        cell.setSymbol(g.slice);
                    };
                    cell.diff_option = .none;
                    cell.setStyle(s);
                }

                // Mark trailing columns as skipped so diffing does not overwrite the wide glyph.
                var k: u16 = 1;
                while (k < g.width) : (k += 1) {
                    if (self.getMut(col + k, y)) |trail| {
                        trail.reset();
                        trail.setStyle(s);
                        trail.diff_option = .skip;
                    }
                }
            }
            col += g.width;
            written_cols += g.width;
        }
        return .{ .x = col, .y = y };
    }

    /// Convenience wrapper writing `text` across the remaining width of the line.
    pub fn setString(self: *Buffer, x: u16, y: u16, text: []const u8, s: Style) Position {
        return self.setStringN(x, y, text, std.math.maxInt(u16), s);
    }

    /// Applies `s` to every cell inside `rect` (intersected with `self.area`).
    pub fn setStyle(self: *Buffer, rect: Rect, s: Style) void {
        const bounds = self.area.intersection(rect);
        if (bounds.isEmpty()) return;
        var row: u16 = bounds.top();
        while (row < bounds.bottom()) : (row += 1) {
            var col: u16 = bounds.left();
            while (col < bounds.right()) : (col += 1) {
                if (self.getMut(col, row)) |cell| {
                    cell.setStyle(s);
                }
            }
        }
    }

    /// Fills `rect` (intersected with `self.area`) with `sym` and `s`.
    pub fn fill(self: *Buffer, rect: Rect, sym: []const u8, s: Style) void {
        const bounds = self.area.intersection(rect);
        if (bounds.isEmpty()) return;
        var row: u16 = bounds.top();
        while (row < bounds.bottom()) : (row += 1) {
            var col: u16 = bounds.left();
            while (col < bounds.right()) : (col += 1) {
                if (self.getMut(col, row)) |cell| {
                    cell.diff_option = .none;
                    self.setCellSymbol(cell, sym) catch cell.setSymbol(sym);
                    cell.setStyle(s);
                }
            }
        }
    }

    /// Composites `other` over `self` in the overlapping region.
    pub fn merge(self: *Buffer, other: *const Buffer) void {
        const overlap = self.area.intersection(other.area);
        if (overlap.isEmpty()) return;
        var row: u16 = overlap.top();
        while (row < overlap.bottom()) : (row += 1) {
            var col: u16 = overlap.left();
            while (col < overlap.right()) : (col += 1) {
                const src = other.get(col, row) orelse continue;
                const dst = self.getMut(col, row) orelse continue;
                dst.* = src.*;
                if (src.symbol_len == 255) {
                    if (src.overflow) |ov| {
                        self.setCellSymbol(dst, ov) catch dst.setSymbol(ov);
                    }
                }
            }
        }
    }

    /// Returns a zero-allocation iterator yielding changed cells between `prev` and `self`.
    pub fn diff(self: *const Buffer, prev: *const Buffer) BufferDiff {
        return BufferDiff.init(prev, self);
    }

    /// Writes plain buffer text (without ANSI styles) into reusable `out` list (retaining capacity).
    pub fn writePlainText(self: *const Buffer, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) std.mem.Allocator.Error!void {
        out.clearRetainingCapacity();

        var row: u16 = self.area.top();
        while (row < self.area.bottom()) : (row += 1) {
            if (row > self.area.top()) try out.append(allocator, '\n');
            var col: u16 = self.area.left();
            while (col < self.area.right()) : (col += 1) {
                const cell = self.get(col, row).?;
                if (cell.diff_option == .skip) continue;
                try out.appendSlice(allocator, cell.symbol());
            }
        }
    }

    /// Renders the buffer text (without ANSI styles) into an owned newline-delimited string.
    /// Useful for golden snapshot tests and debugging. Caller owns returned memory.
    pub fn toPlainTextAlloc(self: *const Buffer, allocator: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(allocator);
        try self.writePlainText(allocator, &out);
        return out.toOwnedSlice(allocator);
    }
};

/// Zero-allocation iterator producing only cells that changed between `prev` and `next`.
pub const BufferDiff = struct {
    prev: []const Cell,
    next: []const Cell,
    area: Rect,
    pos: usize = 0,
    covered_until: usize = 0,

    pub fn init(prev: *const Buffer, next: *const Buffer) BufferDiff {
        var area = prev.area;
        area.height = @min(prev.area.height, next.area.height);
        const usable = @min(prev.cells.len, next.cells.len);
        return .{
            .prev = prev.cells[0..usable],
            .next = next.cells[0..usable],
            .area = area,
        };
    }

    /// Yields the next changed cell `(x, y, *const Cell)`, or `null` when complete.
    pub fn nextEntry(self: *BufferDiff) ?DiffEntry {
        const len = self.next.len;
        while (self.pos < len) {
            const idx = self.pos;
            self.pos += 1;

            const current = &self.next[idx];
            if (current.diff_option == .skip) continue;

            const previous = if (idx < self.covered_until) &Cell.empty else &self.prev[idx];
            const cw: usize = @max(@as(usize, current.cellWidth()), 1);

            if (current.diff_option != .always_update and current.eql(previous)) {
                self.pos +|= cw - 1;
                continue;
            }

            const pw: usize = @max(@as(usize, previous.cellWidth()), 1);
            if (pw > cw) {
                self.covered_until = @max(self.covered_until, idx + pw);
            }
            self.pos +|= cw - 1;

            const w: usize = @max(@as(usize, self.area.width), 1);
            const x: u16 = @intCast((idx % w) + self.area.x);
            const y: u16 = @intCast((idx / w) + self.area.y);
            return .{ .x = x, .y = y, .cell = current };
        }
        return null;
    }
};

test "buffer init, resize, setString clipping, and wide glyphs" {
    const alloc = testing.allocator;
    var buf = try Buffer.init(alloc, Rect.init(0, 0, 10, 2));
    defer buf.deinit();

    _ = buf.setString(0, 0, "Hi日本!", .{ .foreground = .green });
    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expectEqualStrings("Hi日本!   \n          ", snap);

    // Resize smaller then larger without leaking.
    try buf.resize(Rect.init(0, 0, 4, 1));
    _ = buf.setString(0, 0, "abcdef", .{});
    const snap2 = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap2);
    try testing.expectEqualStrings("abcd", snap2);

    try buf.resize(Rect.init(0, 0, 12, 3));
    try testing.expectEqual(@as(usize, 36), buf.cells.len);
}

test "buffer diff emits only changed cells" {
    const alloc = testing.allocator;
    var prev = try Buffer.init(alloc, Rect.init(0, 0, 5, 1));
    defer prev.deinit();
    var next = try Buffer.init(alloc, Rect.init(0, 0, 5, 1));
    defer next.deinit();

    _ = prev.setString(0, 0, "hello", .{});
    _ = next.setString(0, 0, "heLlo", .{});

    var diff = next.diff(&prev);
    const first = diff.nextEntry().?;
    try testing.expectEqual(@as(u16, 2), first.x);
    try testing.expectEqualStrings("L", first.cell.symbol());
    try testing.expect(diff.nextEntry() == null);
}
