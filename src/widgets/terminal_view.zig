//! Embedded `VtScreen` ANSI/VT100 terminal emulator buffer and `TerminalView` widget.
//!
//! Pure Zig with zero external CLI dependencies: feed raw PTY or synthetic ANSI
//! output bytes into `VtScreen.feed(bytes)` and render the resulting colored
//! screen grid inside any `Ui` region via `TerminalView` / `ui.terminalView(...)`.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Position = core_root.Position;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const Color = style_root.Color;
pub const CursorShape = core_root.CursorShape;
pub const Block = block_mod.Block;

/// Single cell inside `VtScreen`.
pub const VtCell = struct {
    ch: [8]u8 = .{ ' ', 0, 0, 0, 0, 0, 0, 0 },
    len: u8 = 1,
    style: Style = .{},

    pub fn slice(self: *const VtCell) []const u8 {
        return self.ch[0..self.len];
    }
};

/// Pure-Zig VT100/ANSI screen state machine parsing SGR colors, cursor movement, and erases.
pub const VtScreen = struct {
    allocator: std.mem.Allocator,
    cols: u16,
    rows: u16,
    cells: []VtCell,
    cursor_x: u16 = 0,
    cursor_y: u16 = 0,
    cursor_hidden: bool = false,
    cursor_shape: CursorShape = .default_shape,
    active_style: Style = .{},

    // Incremental VT parser state
    parse_state: enum { ground, esc, csi, osc, osc_esc } = .ground,
    csi_buf: [64]u8 = undefined,
    csi_len: usize = 0,
    utf8_buf: [4]u8 = undefined,
    utf8_len: u8 = 0,
    utf8_expected: u8 = 0,

    pub fn init(allocator: std.mem.Allocator, cols: u16, rows: u16) !VtScreen {
        const w = @max(@as(u16, 1), cols);
        const h = @max(@as(u16, 1), rows);
        const cells = try allocator.alloc(VtCell, @as(usize, w) * h);
        @memset(cells, VtCell{});
        return .{
            .allocator = allocator,
            .cols = w,
            .rows = h,
            .cells = cells,
        };
    }

    pub fn deinit(self: *VtScreen) void {
        self.allocator.free(self.cells);
    }

    /// Resizes the virtual screen grid, preserving overlapping content.
    pub fn resize(self: *VtScreen, new_cols: u16, new_rows: u16) !void {
        const w = @max(@as(u16, 1), new_cols);
        const h = @max(@as(u16, 1), new_rows);
        if (w == self.cols and h == self.rows) return;
        const next = try self.allocator.alloc(VtCell, @as(usize, w) * h);
        @memset(next, VtCell{});
        const copy_w = @min(w, self.cols);
        const copy_h = @min(h, self.rows);
        var r: u16 = 0;
        while (r < copy_h) : (r += 1) {
            const src_off = @as(usize, r) * self.cols;
            const dst_off = @as(usize, r) * w;
            @memcpy(next[dst_off .. dst_off + copy_w], self.cells[src_off .. src_off + copy_w]);
        }
        self.allocator.free(self.cells);
        self.cells = next;
        self.cols = w;
        self.rows = h;
        self.cursor_x = @min(self.cursor_x, w - 1);
        self.cursor_y = @min(self.cursor_y, h - 1);
    }

    /// Clears all cells and moves cursor to `(0, 0)`.
    pub fn clear(self: *VtScreen) void {
        @memset(self.cells, VtCell{});
        self.cursor_x = 0;
        self.cursor_y = 0;
    }

    pub fn cellAt(self: *const VtScreen, row: u16, col: u16) ?VtCell {
        if (row >= self.rows or col >= self.cols) return null;
        return self.cells[@as(usize, row) * self.cols + col];
    }

    /// Feeds raw VT100/ANSI output bytes into the screen state machine.
    pub fn feed(self: *VtScreen, bytes: []const u8) void {
        for (bytes) |b| {
            switch (self.parse_state) {
                .ground => self.feedGround(b),
                .esc => {
                    if (b == '[') {
                        self.parse_state = .csi;
                        self.csi_len = 0;
                    } else if (b == ']') {
                        self.parse_state = .osc;
                    } else if (b == 'c') {
                        self.active_style = .{};
                        self.clear();
                        self.parse_state = .ground;
                    } else {
                        self.parse_state = .ground;
                    }
                },
                .csi => {
                    if (b >= 0x40 and b <= 0x7E) {
                        self.execCsi(b);
                        self.parse_state = .ground;
                    } else if (self.csi_len < self.csi_buf.len) {
                        self.csi_buf[self.csi_len] = b;
                        self.csi_len += 1;
                    }
                },
                .osc => {
                    if (b == 0x07) {
                        self.parse_state = .ground;
                    } else if (b == 0x1B) {
                        self.parse_state = .osc_esc;
                    }
                },
                .osc_esc => {
                    self.parse_state = if (b == '\\') .ground else .osc;
                },
            }
        }
    }

    fn feedGround(self: *VtScreen, b: u8) void {
        if (self.utf8_expected > 0) {
            if ((b & 0xC0) == 0x80) {
                self.utf8_buf[self.utf8_len] = b;
                self.utf8_len += 1;
                if (self.utf8_len == self.utf8_expected) {
                    self.putGlyph(self.utf8_buf[0..self.utf8_len]);
                    self.utf8_expected = 0;
                    self.utf8_len = 0;
                }
                return;
            }
            self.utf8_expected = 0;
            self.utf8_len = 0;
        }

        switch (b) {
            0x1B => self.parse_state = .esc,
            '\r' => self.cursor_x = 0,
            '\n' => self.lineFeed(),
            '\t' => {
                const next_tab = ((self.cursor_x / 8) + 1) * 8;
                self.cursor_x = @min(self.cols - 1, next_tab);
            },
            0x08 => self.cursor_x -|= 1,
            else => {
                if (b < 0x20) return;
                if (b < 0x80) {
                    const one = [_]u8{b};
                    self.putGlyph(&one);
                } else {
                    const seq_len = std.unicode.utf8ByteSequenceLength(b) catch return;
                    if (seq_len > 1 and seq_len <= 4) {
                        self.utf8_buf[0] = b;
                        self.utf8_len = 1;
                        self.utf8_expected = @intCast(seq_len);
                    }
                }
            },
        }
    }

    fn putGlyph(self: *VtScreen, glyph: []const u8) void {
        if (self.cursor_x >= self.cols) {
            self.cursor_x = 0;
            self.lineFeed();
        }
        const idx = @as(usize, self.cursor_y) * self.cols + self.cursor_x;
        var cell = VtCell{ .style = self.active_style };
        const n = @min(glyph.len, cell.ch.len);
        @memcpy(cell.ch[0..n], glyph[0..n]);
        cell.len = @intCast(n);
        self.cells[idx] = cell;
        self.cursor_x += 1;
    }

    fn lineFeed(self: *VtScreen) void {
        if (self.cursor_y + 1 < self.rows) {
            self.cursor_y += 1;
            return;
        }
        // Scroll up 1 row
        const row_len = @as(usize, self.cols);
        std.mem.copyForwards(VtCell, self.cells[0 .. (@as(usize, self.rows) - 1) * row_len], self.cells[row_len..]);
        @memset(self.cells[(@as(usize, self.rows) - 1) * row_len ..], VtCell{});
    }

    fn parseParams(raw: []const u8, out: *[16]u16) usize {
        var count: usize = 0;
        var it = std.mem.splitScalar(u8, raw, ';');
        while (it.next()) |part| {
            if (count >= out.len) break;
            out[count] = if (part.len == 0) 0 else (std.fmt.parseInt(u16, part, 10) catch 0);
            count += 1;
        }
        return count;
    }

    fn execCsi(self: *VtScreen, final_byte: u8) void {
        const raw = self.csi_buf[0..self.csi_len];
        if (raw.len > 0 and raw[0] == '?') {
            if (std.mem.eql(u8, raw[1..], "25")) {
                if (final_byte == 'h') self.cursor_hidden = false;
                if (final_byte == 'l') self.cursor_hidden = true;
            }
            return;
        }
        if (raw.len > 0 and raw[raw.len - 1] == ' ' and final_byte == 'q') {
            const code = std.fmt.parseInt(u16, raw[0 .. raw.len - 1], 10) catch 0;
            self.cursor_shape = switch (code) {
                1 => .blinking_block,
                2 => .steady_block,
                3 => .blinking_underline,
                4 => .steady_underline,
                5 => .blinking_bar,
                6 => .steady_bar,
                else => .default_shape,
            };
            return;
        }

        var params: [16]u16 = undefined;
        const pcount = parseParams(raw, &params);
        const p0: u16 = if (pcount > 0 and params[0] > 0) params[0] else 1;
        const p1: u16 = if (pcount > 1 and params[1] > 0) params[1] else 1;

        switch (final_byte) {
            'A' => self.cursor_y -|= p0,
            'B' => self.cursor_y = @min(self.rows - 1, self.cursor_y +| p0),
            'C' => self.cursor_x = @min(self.cols - 1, self.cursor_x +| p0),
            'D' => self.cursor_x -|= p0,
            'H', 'f' => {
                self.cursor_y = @min(self.rows - 1, p0 -| 1);
                self.cursor_x = @min(self.cols - 1, p1 -| 1);
            },
            'J' => {
                const mode = if (pcount > 0) params[0] else 0;
                const cur_idx = @as(usize, self.cursor_y) * self.cols + @min(self.cursor_x, self.cols - 1);
                switch (mode) {
                    0 => @memset(self.cells[cur_idx..], VtCell{}),
                    1 => @memset(self.cells[0 .. cur_idx + 1], VtCell{}),
                    2, 3 => @memset(self.cells, VtCell{}),
                    else => {},
                }
            },
            'K' => {
                const mode = if (pcount > 0) params[0] else 0;
                const row_start = @as(usize, self.cursor_y) * self.cols;
                const row_end = row_start + self.cols;
                const cur = row_start + @min(self.cursor_x, self.cols - 1);
                switch (mode) {
                    0 => @memset(self.cells[cur..row_end], VtCell{}),
                    1 => @memset(self.cells[row_start .. cur + 1], VtCell{}),
                    2 => @memset(self.cells[row_start..row_end], VtCell{}),
                    else => {},
                }
            },
            'm' => self.applySgr(params[0..pcount]),
            else => {},
        }
    }

    fn applySgr(self: *VtScreen, params: []const u16) void {
        if (params.len == 0) {
            self.active_style = .{};
            return;
        }
        var i: usize = 0;
        while (i < params.len) : (i += 1) {
            const p = params[i];
            switch (p) {
                0 => self.active_style = .{},
                1 => self.active_style.bold = true,
                2 => self.active_style.dim = true,
                3 => self.active_style.italic = true,
                4 => self.active_style.underline = true,
                7 => self.active_style.reverse = true,
                9 => self.active_style.strikethrough = true,
                22 => {
                    self.active_style.bold = false;
                    self.active_style.dim = false;
                },
                23 => self.active_style.italic = false,
                24 => self.active_style.underline = false,
                27 => self.active_style.reverse = false,
                29 => self.active_style.strikethrough = false,
                30...37 => self.active_style.foreground = Color.indexed(@intCast(p - 30)),
                39 => self.active_style.foreground = .reset,
                40...47 => self.active_style.background = Color.indexed(@intCast(p - 40)),
                49 => self.active_style.background = .reset,
                90...97 => self.active_style.foreground = Color.indexed(@intCast(p - 90 + 8)),
                100...107 => self.active_style.background = Color.indexed(@intCast(p - 100 + 8)),
                38, 48 => {
                    const is_fg = (p == 38);
                    if (i + 2 < params.len and params[i + 1] == 5) {
                        const c = Color.ansi256(@intCast(@min(255, params[i + 2])));
                        if (is_fg) self.active_style.foreground = c else self.active_style.background = c;
                        i += 2;
                    } else if (i + 4 < params.len and params[i + 1] == 2) {
                        const c = Color.rgb(
                            @intCast(@min(255, params[i + 2])),
                            @intCast(@min(255, params[i + 3])),
                            @intCast(@min(255, params[i + 4])),
                        );
                        if (is_fg) self.active_style.foreground = c else self.active_style.background = c;
                        i += 4;
                    }
                },
                else => {},
            }
        }
    }
};

/// Renders a `VtScreen` pseudo-terminal buffer inside an optional `Block`.
pub const TerminalView = struct {
    screen: *const VtScreen,
    block: ?Block = .{ .title = "Terminal" },
    base_style: ?Style = null,
    show_cursor: bool = true,
    focused: bool = true,

    pub fn render(self: TerminalView, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        const base = self.base_style orelse ui.theme.surface;
        ui.buffer.fill(inner, " ", base);

        const max_r = @min(inner.height, self.screen.rows);
        const max_c = @min(inner.width, self.screen.cols);
        var r: u16 = 0;
        while (r < max_r) : (r += 1) {
            var c: u16 = 0;
            while (c < max_c) : (c += 1) {
                const cell = self.screen.cellAt(r, c) orelse continue;
                const merged = base.patch(cell.style);
                _ = ui.buffer.setStringClipped(inner.left() + c, inner.top() + r, cell.slice(), 1, merged, inner);
            }
        }

        if (self.show_cursor and self.focused and !self.screen.cursor_hidden) {
            const cx = inner.left() + self.screen.cursor_x;
            const cy = inner.top() + self.screen.cursor_y;
            if (inner.containsXY(cx, cy)) {
                ui.setCursor(cx, cy);
                if (ui.buffer.getMut(cx, cy)) |buf_cell| {
                    buf_cell.modifiers.reverse = !buf_cell.modifiers.reverse;
                }
            }
        }
    }
};

test "VtScreen parses ANSI SGR colors, cursor movement, and renders via TerminalView" {
    const alloc = testing.allocator;
    var scr = try VtScreen.init(alloc, 32, 4);
    defer scr.deinit();

    scr.feed("\x1b[1;32mOK\x1b[0m build passed\r\n\x1b[38;2;255;128;0mReady\x1b[0m");

    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 34, 6));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    try (TerminalView{ .screen = &scr }).render(&ui, buf.area);

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "OK build passed") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "Ready") != null);
    try testing.expect(cursor != null);
}
