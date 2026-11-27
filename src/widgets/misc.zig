//! High-impact presentation & productivity widgets: `BigText` banner,
//! `Markdown` viewer, `CommandPalette`, and `Tooltip`.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const event_root = @import("../event/root.zig");
const clear_mod = @import("clear.zig");
const block_mod = @import("block.zig");
const list_mod = @import("list.zig");
const popup_mod = @import("popup.zig");
const input_mod = @import("text_input.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Alignment = core_root.Alignment;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const Block = block_mod.Block;
pub const List = list_mod.List;
pub const ListState = list_mod.ListState;
pub const Popup = popup_mod.Popup;
pub const TextInput = input_mod.TextInput;
pub const TextInputState = input_mod.TextInputState;
pub const Event = event_root.Event;

/// Pixel/block banner widget powered by `BitmapFont` (built-in ASCII or custom client Unicode fonts),
/// supporting full-block, half-block (2x vertical res), quadrant (2x2), and Braille (2x4) rendering modes.
pub const BigText = struct {
    text: []const u8,
    alignment: Alignment = .left,
    direction: text_root.TextDirection = .ltr,
    style: ?Style = null,
    pixel_char: []const u8 = style_root.symbols.block.full,
    letter_spacing: u16 = 1,
    font: ?*const text_root.BitmapFont = null,
    mode: text_root.FontRenderMode = .full_block,
    scale_x: u16 = 1,
    scale_y: u16 = 1,

    /// Default compact banner height (`5` rows).
    pub const banner_height: u16 = 5;

    /// Renders UTF-8 text using the selected `BitmapFont` (or built-in `block_3x5`) into `ui.buffer` within `area`.
    pub fn render(self: BigText, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty() or self.text.len == 0) return;

        var rtl_buf: [256]u8 = undefined;
        const vis_text = text_root.visualOrderInto(self.text, self.direction, &rtl_buf);

        var active_font = (self.font orelse &text_root.BitmapFont.block_3x5).*;
        active_font.letter_spacing = self.letter_spacing;
        const sx = @max(@as(u16, 1), self.scale_x);
        const sy = @max(@as(u16, 1), self.scale_y);
        const px_dim = active_font.measurePixels(vis_text, sx, sy);
        const cell_dim = active_font.measureCells(vis_text, self.mode, sx, sy);
        if (cell_dim.cols == 0 or cell_dim.rows == 0) return;

        const total_w = cell_dim.cols;
        const start_x: u16 = switch (self.alignment) {
            .left => bounds.left(),
            .center => bounds.left() + (bounds.width -| total_w) / 2,
            .right => bounds.right() -| total_w,
        };
        const st = self.style orelse ui.theme.accent.patch(.{ .bold = true });

        if (self.mode == .full_block and sx == 1 and sy == 1) {
            const fh: u16 = px_dim.height;
            var r: u16 = 0;
            while (r < fh and r < bounds.height) : (r += 1) {
                var x = start_x;
                var git = text_root.GraphemeIterator.init(vis_text);
                var idx: usize = 0;
                while (git.next()) |g| : (idx += 1) {
                    if (idx > 0) x +|= active_font.letter_spacing;
                    if (x >= bounds.right()) break;
                    const seq_l = std.unicode.utf8ByteSequenceLength(g.slice[0]) catch 1;
                    const cp = std.unicode.utf8Decode(g.slice[0..@min(seq_l, g.slice.len)]) catch '?';
                    if (active_font.resolveGlyph(cp)) |gl| {
                        const y_off = (fh -| gl.height) / 2;
                        if (r >= y_off and r < y_off + gl.height) {
                            const gr = r - y_off;
                            var dx: u16 = 0;
                            while (dx < gl.width and x + dx < bounds.right()) : (dx += 1) {
                                if (gl.pixelAt(dx, gr)) {
                                    if (ui.buffer.getMut(x + dx, bounds.top() + r)) |cell| {
                                        try ui.buffer.setCellSymbol(cell, self.pixel_char);
                                        cell.diff_option = .none;
                                        cell.setStyle(st);
                                    }
                                }
                            }
                        }
                        x +|= gl.width;
                    } else {
                        x +|= active_font.default_width;
                    }
                }
            }
            return;
        }

        // High-density sub-cell rendering modes (.half_block, .quadrant, .braille, or scaled blocks).
        const sub_x: u16 = switch (self.mode) {
            .full_block, .half_block => 1,
            .quadrant, .braille => 2,
        };
        const sub_y: u16 = switch (self.mode) {
            .full_block => 1,
            .half_block, .quadrant => 2,
            .braille => 4,
        };
        const vis_cols = @min(total_w, bounds.width -| (start_x - bounds.left()));
        const vis_rows = @min(cell_dim.rows, bounds.height);
        if (vis_cols == 0 or vis_rows == 0) return;

        const grid_px_w = vis_cols * sub_x;
        const grid_px_h = vis_rows * sub_y;
        const masks = try ui.scratchAllocator().alloc(u8, @as(usize, vis_cols) * @as(usize, vis_rows));
        @memset(masks, 0);

        var px_cursor: u16 = 0;
        var git = text_root.GraphemeIterator.init(vis_text);
        var idx: usize = 0;
        while (git.next()) |g| : (idx += 1) {
            if (idx > 0) px_cursor +|= active_font.letter_spacing * sx;
            if (px_cursor >= grid_px_w) break;
            const seq_l = std.unicode.utf8ByteSequenceLength(g.slice[0]) catch 1;
            const cp = std.unicode.utf8Decode(g.slice[0..@min(seq_l, g.slice.len)]) catch '?';
            const gl = active_font.resolveGlyph(cp) orelse {
                px_cursor +|= @as(u16, active_font.default_width) * sx;
                continue;
            };
            const y_off_px = (px_dim.height -| (@as(u16, gl.height) * sy)) / 2;
            var gy: u16 = 0;
            while (gy < gl.height) : (gy += 1) {
                var gx: u16 = 0;
                while (gx < gl.width) : (gx += 1) {
                    if (!gl.pixelAt(gx, gy)) continue;
                    var sy_i: u16 = 0;
                    while (sy_i < sy) : (sy_i += 1) {
                        const py = y_off_px + gy * sy + sy_i;
                        if (py >= grid_px_h) continue;
                        var sx_i: u16 = 0;
                        while (sx_i < sx) : (sx_i += 1) {
                            const px = px_cursor + gx * sx + sx_i;
                            if (px >= grid_px_w) continue;
                            const cx = px / sub_x;
                            const cy = py / sub_y;
                            const cell_idx = @as(usize, cy) * @as(usize, vis_cols) + cx;
                            const bit_sx = px % sub_x;
                            const bit_sy = py % sub_y;
                            switch (self.mode) {
                                .full_block => masks[cell_idx] = 1,
                                .half_block => masks[cell_idx] |= if (bit_sy == 0) @as(u8, 0b10) else @as(u8, 0b01),
                                .quadrant => masks[cell_idx] |= @as(u8, 1) << @intCast(3 - (bit_sy * 2 + bit_sx)),
                                .braille => masks[cell_idx] |= style_root.symbols.braille_dot_bits[bit_sy][bit_sx],
                            }
                        }
                    }
                }
            }
            px_cursor +|= @as(u16, gl.width) * sx;
        }

        var br_tmp: [3]u8 = undefined;
        var cy: u16 = 0;
        while (cy < vis_rows) : (cy += 1) {
            var cx: u16 = 0;
            while (cx < vis_cols) : (cx += 1) {
                const m = masks[@as(usize, cy) * @as(usize, vis_cols) + cx];
                if (m == 0) continue;
                const cell = ui.buffer.getMut(start_x + cx, bounds.top() + cy) orelse continue;
                const sym: []const u8 = switch (self.mode) {
                    .full_block => self.pixel_char,
                    .half_block => switch (m & 0b11) {
                        0b11 => "█",
                        0b10 => "▀",
                        0b01 => "▄",
                        else => " ",
                    },
                    .quadrant => style_root.symbols.quadrants[m & 0x0F],
                    .braille => style_root.symbols.encodeBrailleMask(m, &br_tmp),
                };
                try ui.buffer.setCellSymbol(cell, sym);
                cell.diff_option = .none;
                cell.setStyle(st);
            }
        }
    }
};

/// Lightweight terminal Markdown document viewer supporting headings (`#`), lists (`- `, `* `),
/// blockquotes (`> `), code fences (```` ``` ````), horizontal rules (`---`), and inline `` `code` `` / `**bold**`.
pub const Markdown = struct {
    source: []const u8,
    block: ?Block = null,
    scroll_y: u16 = 0,
    style: ?Style = null,

    pub fn render(self: Markdown, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        const base_s = self.style orelse ui.theme.text;
        var in_code_block = false;
        var row_idx: usize = 0;
        var lines = text_root.splitLinesIter(self.source);

        while (lines.next()) |raw_line| : (row_idx += 1) {
            const trimmed = std.mem.trim(u8, raw_line, " \t");
            if (std.mem.startsWith(u8, trimmed, "```")) {
                in_code_block = !in_code_block;
                continue;
            }
            if (row_idx < self.scroll_y) continue;
            const rel = row_idx - self.scroll_y;
            if (rel >= inner.height) break;
            const y = inner.top() + @as(u16, @intCast(rel));

            if (in_code_block) {
                const code_s = Style{ .foreground = ui.theme.info.foreground, .background = ui.theme.input.background };
                ui.buffer.setStyle(Rect.init(inner.left(), y, inner.width, 1), code_s);
                _ = ui.buffer.setStringClipped(inner.left() +| 1, y, raw_line, inner.width -| 2, code_s, inner);
                continue;
            }

            if (std.mem.eql(u8, trimmed, "---") or std.mem.eql(u8, trimmed, "***")) {
                var x = inner.left();
                while (x < inner.right()) : (x += 1) {
                    _ = ui.buffer.setStringClipped(x, y, style_root.symbols.line.normal.horizontal, 1, ui.theme.border, inner);
                }
            } else if (std.mem.startsWith(u8, trimmed, "# ")) {
                _ = ui.buffer.setStringClipped(inner.left(), y, trimmed[2..], inner.width, ui.theme.accent.patch(.{ .bold = true, .underline = true }), inner);
            } else if (std.mem.startsWith(u8, trimmed, "## ")) {
                _ = ui.buffer.setStringClipped(inner.left(), y, trimmed[3..], inner.width, ui.theme.title, inner);
            } else if (std.mem.startsWith(u8, trimmed, "### ")) {
                _ = ui.buffer.setStringClipped(inner.left(), y, trimmed[4..], inner.width, ui.theme.secondary.patch(.{ .bold = true }), inner);
            } else if (std.mem.startsWith(u8, trimmed, "> ")) {
                const pos = ui.buffer.setStringClipped(inner.left(), y, "│ ", inner.width, ui.theme.accent, inner);
                renderInlineMarkdown(ui.buffer, inner, pos.x, y, trimmed[2..], ui.theme.muted.patch(.{ .italic = true }), ui.theme);
            } else if (std.mem.startsWith(u8, trimmed, "- ") or std.mem.startsWith(u8, trimmed, "* ")) {
                const pos = ui.buffer.setStringClipped(inner.left(), y, " • ", inner.width, ui.theme.accent, inner);
                renderInlineMarkdown(ui.buffer, inner, pos.x, y, trimmed[2..], base_s, ui.theme);
            } else {
                renderInlineMarkdown(ui.buffer, inner, inner.left(), y, raw_line, base_s, ui.theme);
            }
        }
    }

    fn renderInlineMarkdown(
        buf: *core_root.Buffer,
        inner: Rect,
        start_x: u16,
        y: u16,
        line: []const u8,
        base_s: Style,
        theme: *const style_root.Theme,
    ) void {
        var x = start_x;
        var pos: usize = 0;
        while (pos < line.len and x < inner.right()) {
            if (line[pos] == '`') {
                if (std.mem.indexOfScalarPos(u8, line, pos + 1, '`')) |end_tick| {
                    const code_s = Style{ .foreground = theme.warning.foreground, .background = theme.input.background };
                    x = buf.setStringClipped(x, y, line[pos + 1 .. end_tick], inner.right() - x, code_s, inner).x;
                    pos = end_tick + 1;
                    continue;
                }
            }
            if (pos + 2 < line.len and line[pos] == '*' and line[pos + 1] == '*') {
                if (std.mem.indexOfPos(u8, line, pos + 2, "**")) |end_bold| {
                    x = buf.setStringClipped(x, y, line[pos + 2 .. end_bold], inner.right() - x, base_s.patch(.{ .bold = true }), inner).x;
                    pos = end_bold + 2;
                    continue;
                }
            }
            // Emit run up to next inline token or end.
            var next = pos + 1;
            while (next < line.len) : (next += 1) {
                if (line[next] == '`' or (next + 1 < line.len and line[next] == '*' and line[next + 1] == '*')) break;
            }
            x = buf.setStringClipped(x, y, line[pos..next], inner.right() - x, base_s, inner).x;
            pos = next;
        }
    }
};

/// Action item displayed inside `CommandPalette`.
pub const CommandEntry = struct {
    name: []const u8,
    shortcut: ?[]const u8 = null,
    category: ?[]const u8 = null,
};

/// Outcome returned from `CommandPaletteState.handleEvent`.
pub const CommandPaletteResult = union(enum) {
    none,
    cancelled,
    executed: usize,
};

/// Allocator-backed query input + selection state for `CommandPalette`.
pub const CommandPaletteState = struct {
    allocator: std.mem.Allocator,
    open: bool = false,
    query: TextInputState,
    list: ListState = .{ .selected = 0 },

    pub fn init(allocator: std.mem.Allocator) CommandPaletteState {
        return .{
            .allocator = allocator,
            .query = TextInputState.init(allocator),
        };
    }

    pub fn deinit(self: *CommandPaletteState) void {
        self.query.deinit();
        self.* = undefined;
    }

    pub fn toggle(self: *CommandPaletteState) void {
        self.open = !self.open;
        if (self.open) {
            self.query.clear();
            self.list.selected = 0;
            self.list.offset = 0;
        }
    }

    /// Processes filter typing, Up/Down selection, Enter execution, and Esc close.
    /// Returns `.executed = original_command_index` when chosen.
    pub fn handleEvent(self: *CommandPaletteState, event: Event, commands: []const CommandEntry) !CommandPaletteResult {
        return self.handleEventImpl(event, null, commands);
    }

    /// Processes keyboard, scroll wheel, click-to-run item, and click-outside dismissal inside `screen`.
    pub fn handleEventAt(self: *CommandPaletteState, event: Event, screen: Rect, commands: []const CommandEntry) !CommandPaletteResult {
        return self.handleEventImpl(event, screen, commands);
    }

    fn handleEventImpl(self: *CommandPaletteState, event: Event, screen_opt: ?Rect, commands: []const CommandEntry) !CommandPaletteResult {
        if (!self.open) return .none;
        if (event.isEscape()) {
            self.open = false;
            return .cancelled;
        }

        const q = self.query.text();
        var match_buf: [256]usize = undefined;
        var match_count: usize = 0;
        for (commands, 0..) |cmd, idx| {
            if (matchesQuery(cmd.name, q) and match_count < match_buf.len) {
                match_buf[match_count] = idx;
                match_count += 1;
            }
        }

        if (event == .mouse) {
            if (screen_opt) |scr| {
                const m = event.mouse;
                const pop_box = (Popup{
                    .title = "Command Palette",
                    .footer_hint = "Up/Down Select • Enter Run • Esc Close",
                    .width_percent = 65,
                    .height_percent = 55,
                }).computeRect(scr);
                const inner = (Block{
                    .border_type = .rounded,
                    .padding = .{ .left = 1, .right = 1, .top = 0, .bottom = 0 },
                }).inner(pop_box);
                const list_area = core_root.layout.splitFixed(2, inner, .{ .{ .length = 3 }, .{ .fill = 1 } }, .{ .direction = .vertical })[1];

                if (m.kind == .down and m.button == .left) {
                    if (!m.isInside(pop_box)) {
                        self.open = false;
                        return .cancelled;
                    }
                    if (m.isInside(list_area)) {
                        const rel_row = self.list.offset + (m.y - list_area.top());
                        if (rel_row < match_count) {
                            self.list.selected = rel_row;
                            self.open = false;
                            return .{ .executed = match_buf[rel_row] };
                        }
                    }
                    return .none;
                } else if (m.isInside(list_area) and (m.kind == .scroll_up or m.kind == .scroll_down)) {
                    if (m.kind == .scroll_up) {
                        self.list.selectPrevious(match_count);
                    } else {
                        self.list.selectNext(match_count);
                    }
                    return .none;
                }
            }
            return .none;
        }

        if (event == .key and event.key.kind != .release) {
            switch (event.key.code) {
                .down => {
                    self.list.selectNext(match_count);
                    return .none;
                },
                .up => {
                    self.list.selectPrevious(match_count);
                    return .none;
                },
                .enter => {
                    if (self.list.selected) |sel| {
                        if (sel < match_count) {
                            self.open = false;
                            return .{ .executed = match_buf[sel] };
                        }
                    }
                    return .none;
                },
                else => {},
            }
        }

        if (try self.query.handleEvent(event, true) == .changed) {
            // Recompute match count for updated query so selection stays valid when empty.
            const next_q = self.query.text();
            var next_matches: usize = 0;
            for (commands) |cmd| {
                if (matchesQuery(cmd.name, next_q)) next_matches += 1;
            }
            self.list.selected = if (next_matches > 0) 0 else null;
            self.list.offset = 0;
        }
        return .none;
    }
};

fn matchesQuery(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[i .. i + needle.len], needle)) return true;
    }
    return false;
}

/// Modal fuzzy/substring filterable command launcher (`Ctrl+K` / `Ctrl+P` UX pattern).
pub const CommandPalette = struct {
    commands: []const CommandEntry = &.{},
    title: []const u8 = "Command Palette",
    placeholder: []const u8 = "Type a command...",

    pub fn renderStateful(self: CommandPalette, ui: *Ui, screen: Rect, state: *CommandPaletteState) !void {
        if (!state.open) return;

        const q = state.query.text();
        var filtered_items = try ui.scratchAllocator().alloc(list_mod.ListItem, self.commands.len);
        var count: usize = 0;
        for (self.commands) |cmd| {
            if (matchesQuery(cmd.name, q)) {
                const label = if (cmd.shortcut) |sc|
                    try std.fmt.allocPrint(ui.scratchAllocator(), "{s}  [{s}]", .{ cmd.name, sc })
                else if (cmd.category) |cat|
                    try std.fmt.allocPrint(ui.scratchAllocator(), "{s}  ({s})", .{ cmd.name, cat })
                else
                    cmd.name;
                filtered_items[count] = .{ .raw = label };
                count += 1;
            }
        }

        const Ctx = struct {
            palette: CommandPalette,
            st: *CommandPaletteState,
            items: []const list_mod.ListItem,
        };
        const pop = Popup{
            .title = self.title,
            .footer_hint = "Up/Down Select • Enter Run • Esc Close",
            .width_percent = 65,
            .height_percent = 55,
        };
        try pop.renderWith(ui, screen, Ctx{
            .palette = self,
            .st = state,
            .items = filtered_items[0..count],
        }, struct {
            fn draw(ctx: Ctx, body: *Ui) !void {
                const split = body.rows(2, .{ .{ .length = 3 }, .{ .fill = 1 } }, .{});
                var in_ui = split[0];
                try in_ui.renderStateful(TextInput{
                    .prefix = "> ",
                    .placeholder = ctx.palette.placeholder,
                    .focused = true,
                }, &ctx.st.query, in_ui.area);

                var ls_ui = split[1];
                try ls_ui.renderStateful(List{
                    .items = ctx.items,
                    .highlight_symbol = "▸ ",
                    .focused = true,
                }, &ctx.st.list, ls_ui.area);
            }
        }.draw);
    }
};

/// Compact floating contextual tooltip positioned right below (or above) `anchor_rect`.
pub const Tooltip = struct {
    text: []const u8,
    anchor_rect: Rect,

    pub fn render(self: Tooltip, ui: *Ui, screen: Rect) !void {
        const bounds = screen.intersection(ui.buffer.area);
        if (bounds.isEmpty() or self.text.len == 0) return;

        const w = @min(bounds.width, text_root.displayWidth(self.text) + 4);
        const h: u16 = 3;
        if (w < 4 or bounds.height < 3) return;

        const y: u16 = if (self.anchor_rect.bottom() + h <= bounds.bottom())
            self.anchor_rect.bottom()
        else
            self.anchor_rect.top() -| h;
        const x = @min(self.anchor_rect.left(), bounds.right() - w);
        const box = Rect.init(x, y, w, h);

        (clear_mod.Clear{ .style = ui.theme.surface }).renderToBuffer(ui.buffer, box);
        const blk = Block{
            .border_type = .rounded,
            .border_style = ui.theme.info,
            .style = ui.theme.surface,
            .fill_background = true,
        };
        var full_ui = ui.*;
        full_ui.area = bounds;
        try blk.render(&full_ui, box);
        const inner = blk.inner(box);
        if (!inner.isEmpty()) {
            _ = full_ui.buffer.setStringClipped(inner.left(), inner.top(), self.text, inner.width, ui.theme.text, inner);
        }
    }
};

test "bigtext, markdown, command palette, and tooltip render accurately" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 50, 14));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    try (BigText{ .text = "ZIG" }).render(&ui, Rect.init(0, 0, 20, 5));
    try (Markdown{ .source = "# Heading\n- **Bold** and `inline`" }).render(&ui, Rect.init(0, 5, 36, 4));
    try (Tooltip{ .text = "Quick Tip", .anchor_rect = Rect.init(2, 1, 5, 1) }).render(&ui, buf.area);

    var cp = CommandPaletteState.init(alloc);
    defer cp.deinit();
    cp.open = true;
    try cp.query.insertSlice("quit");
    const cmds = [_]CommandEntry{
        .{ .name = "Save File" },
        .{ .name = "Quit Application" },
    };
    const res = try cp.handleEvent(.{ .key = .{ .code = .enter } }, &cmds);
    try testing.expectEqual(@as(usize, 1), res.executed);

    // Mouse click on filtered entry inside CommandPaletteState.handleEventAt.
    cp.toggle();
    const res2 = try cp.handleEventAt(.{ .mouse = .{ .kind = .down, .button = .left, .x = 12, .y = 0 } }, Rect.init(0, 0, 50, 14), &cmds);
    try testing.expectEqual(CommandPaletteResult.cancelled, res2);

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Heading") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "Quick Tip") != null);
}
