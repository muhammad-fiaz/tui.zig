//! Single-line `TextInput` widget, UTF-8 `TextInputState`, search/command/password presets,
//! hardware cursor integration, and optional zero-alloc `zigantic` schema validation.

const std = @import("std");
const z = @import("zigantic");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const event_root = @import("../event/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const Block = block_mod.Block;
pub const Event = event_root.Event;

/// Validation feedback state for input fields.
pub const ValidationStatus = enum {
    none,
    valid,
    invalid,
};

/// Result produced by validating a `TextInputState` against a `zigantic` schema.
pub const ValidationResult = struct {
    valid: bool,
    message: ?[]const u8 = null,
};

/// Event reaction returned by `TextInputState.handleEvent`.
pub const InputAction = enum {
    none,
    changed,
    submitted,
    cursor_moved,
};

/// Allocator-owned mutable text buffer and grapheme-aware cursor state for `TextInput`.
pub const TextInputState = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayListUnmanaged(u8) = .empty,
    /// Current cursor byte offset in `buffer.items` (always aligned to a UTF-8 grapheme boundary).
    cursor: usize = 0,
    /// Horizontal viewport scroll offset in display columns.
    scroll_offset: u16 = 0,
    /// Optional start byte of active selection (`null` = no selection).
    selection_anchor: ?usize = null,

    /// Initializes an empty `TextInputState`. Caller must call `deinit()`.
    pub fn init(allocator: std.mem.Allocator) TextInputState {
        return .{ .allocator = allocator };
    }

    /// Initializes with pre-filled UTF-8 `initial` content.
    pub fn initWithText(allocator: std.mem.Allocator, initial: []const u8) !TextInputState {
        var st = init(allocator);
        errdefer st.deinit();
        try st.setText(initial);
        return st;
    }

    /// Frees owned text buffer memory.
    pub fn deinit(self: *TextInputState) void {
        self.buffer.deinit(self.allocator);
        self.* = undefined;
    }

    /// Returns the current text slice (borrowed; valid until next mutation).
    pub fn text(self: *const TextInputState) []const u8 {
        return self.buffer.items;
    }

    /// Replaces the buffer content and places the cursor at the end.
    pub fn setText(self: *TextInputState, value: []const u8) !void {
        self.buffer.clearRetainingCapacity();
        try self.buffer.appendSlice(self.allocator, value);
        self.cursor = self.buffer.items.len;
        self.selection_anchor = null;
        self.scroll_offset = 0;
    }

    /// Clears text while preserving allocated capacity.
    pub fn clear(self: *TextInputState) void {
        self.buffer.clearRetainingCapacity();
        self.cursor = 0;
        self.scroll_offset = 0;
        self.selection_anchor = null;
    }

    /// Selects the entire buffer.
    pub fn selectAll(self: *TextInputState) void {
        self.selection_anchor = 0;
        self.cursor = self.buffer.items.len;
    }

    /// Deletes currently selected range (if any) and returns `true` if deleted.
    pub fn deleteSelection(self: *TextInputState) bool {
        const anchor = self.selection_anchor orelse return false;
        const start = @min(anchor, self.cursor);
        const end = @max(anchor, self.cursor);
        if (end > start) {
            self.buffer.replaceRangeAssumeCapacity(start, end - start, &.{});
            self.cursor = start;
        }
        self.selection_anchor = null;
        return end > start;
    }

    /// Inserts a Unicode scalar at `self.cursor`, replacing active selection if present.
    pub fn insertCodepoint(self: *TextInputState, cp: u21) !void {
        var utf8_buf: [4]u8 = undefined;
        const n = std.unicode.utf8Encode(cp, &utf8_buf) catch return;
        try self.insertSlice(utf8_buf[0..n]);
    }

    /// Inserts UTF-8 text (single-line: newlines/tabs converted to spaces) at `self.cursor`.
    pub fn insertSlice(self: *TextInputState, slice: []const u8) !void {
        _ = self.deleteSelection();
        if (slice.len == 0) return;
        for (slice) |b| {
            if (b == '\r') continue;
            const ch: u8 = if (b == '\n' or b == '\t') ' ' else b;
            try self.buffer.insert(self.allocator, self.cursor, ch);
            self.cursor += 1;
        }
    }

    /// Deletes one grapheme before the cursor (or active selection).
    pub fn backspace(self: *TextInputState) bool {
        if (self.deleteSelection()) return true;
        if (self.cursor == 0) return false;
        const prev = self.prevGraphemeStart(self.cursor);
        self.buffer.replaceRangeAssumeCapacity(prev, self.cursor - prev, &.{});
        self.cursor = prev;
        return true;
    }

    /// Deletes one grapheme under/after the cursor (or active selection).
    pub fn deleteForward(self: *TextInputState) bool {
        if (self.deleteSelection()) return true;
        if (self.cursor >= self.buffer.items.len) return false;
        const next_end = self.nextGraphemeEnd(self.cursor);
        self.buffer.replaceRangeAssumeCapacity(self.cursor, next_end - self.cursor, &.{});
        return true;
    }

    /// Deletes one word backward (Ctrl+W / Alt+Backspace style).
    pub fn deleteWordBackward(self: *TextInputState) bool {
        if (self.deleteSelection()) return true;
        if (self.cursor == 0) return false;
        var pos = self.cursor;
        while (pos > 0 and self.buffer.items[pos - 1] == ' ') pos -= 1;
        while (pos > 0 and self.buffer.items[pos - 1] != ' ') pos -= 1;
        self.buffer.replaceRangeAssumeCapacity(pos, self.cursor - pos, &.{});
        self.cursor = pos;
        self.selection_anchor = null;
        return true;
    }

    /// Returns ordered active selection byte range `[start, end)`, or `null` when empty.
    pub fn selectedRange(self: *const TextInputState) ?struct { start: usize, end: usize } {
        const anchor = self.selection_anchor orelse return null;
        const start = @min(anchor, self.cursor);
        const end = @max(anchor, self.cursor);
        if (end <= start) return null;
        return .{ .start = start, .end = end };
    }

    /// Returns the currently selected UTF-8 slice, or `null` if no selection is active.
    pub fn selectedText(self: *const TextInputState) ?[]const u8 {
        const r = self.selectedRange() orelse return null;
        return self.buffer.items[r.start..r.end];
    }

    /// Moves cursor (optionally extending selection when `extend` is true).
    fn moveCursorTo(self: *TextInputState, target: usize, extend: bool) void {
        if (extend) {
            if (self.selection_anchor == null) self.selection_anchor = self.cursor;
        } else {
            self.selection_anchor = null;
        }
        self.cursor = @min(target, self.buffer.items.len);
    }

    pub fn moveLeft(self: *TextInputState) void {
        self.moveLeftEx(false);
    }

    pub fn moveLeftEx(self: *TextInputState, extend: bool) void {
        const target = if (self.cursor > 0) self.prevGraphemeStart(self.cursor) else 0;
        self.moveCursorTo(target, extend);
    }

    pub fn moveRight(self: *TextInputState) void {
        self.moveRightEx(false);
    }

    pub fn moveRightEx(self: *TextInputState, extend: bool) void {
        const target = if (self.cursor < self.buffer.items.len) self.nextGraphemeEnd(self.cursor) else self.buffer.items.len;
        self.moveCursorTo(target, extend);
    }

    pub fn moveWordLeft(self: *TextInputState) void {
        self.moveWordLeftEx(false);
    }

    pub fn moveWordLeftEx(self: *TextInputState, extend: bool) void {
        var pos = self.cursor;
        while (pos > 0 and self.buffer.items[pos - 1] == ' ') pos -= 1;
        while (pos > 0 and self.buffer.items[pos - 1] != ' ') pos -= 1;
        self.moveCursorTo(pos, extend);
    }

    pub fn moveWordRight(self: *TextInputState) void {
        self.moveWordRightEx(false);
    }

    pub fn moveWordRightEx(self: *TextInputState, extend: bool) void {
        var pos = self.cursor;
        const len = self.buffer.items.len;
        while (pos < len and self.buffer.items[pos] != ' ') pos += 1;
        while (pos < len and self.buffer.items[pos] == ' ') pos += 1;
        self.moveCursorTo(pos, extend);
    }

    pub fn moveHome(self: *TextInputState) void {
        self.moveHomeEx(false);
    }

    pub fn moveHomeEx(self: *TextInputState, extend: bool) void {
        self.moveCursorTo(0, extend);
    }

    pub fn moveEnd(self: *TextInputState) void {
        self.moveEndEx(false);
    }

    pub fn moveEndEx(self: *TextInputState, extend: bool) void {
        self.moveCursorTo(self.buffer.items.len, extend);
    }

    /// Display width from byte `0` up to `self.cursor`.
    pub fn cursorDisplayCol(self: *const TextInputState) u16 {
        return text_root.displayWidth(self.buffer.items[0..self.cursor]);
    }

    /// Validates `self.text()` against a `zigantic` schema (`z.string(...)`) without heap allocations.
    pub fn validateWithSchema(
        self: *const TextInputState,
        comptime schema: anytype,
        message_buf: []u8,
    ) ValidationResult {
        const issue = z.checkFirst(schema, self.text(), message_buf, .{}) catch {
            return .{ .valid = false, .message = "Validation error" };
        };
        if (issue) |err| {
            return .{ .valid = false, .message = err.message };
        }
        return .{ .valid = true, .message = null };
    }

    /// Processes keyboard/paste input when `focused`. Returns action kind.
    pub fn handleEvent(self: *TextInputState, event: Event, focused: bool) !InputAction {
        if (!focused) return .none;
        switch (event) {
            .paste => |p| {
                try self.insertSlice(p);
                return .changed;
            },
            .key => |k| {
                if (k.kind == .release) return .none;
                switch (k.code) {
                    .enter => return .submitted,
                    .backspace => return if (k.modifiers.alt or k.modifiers.ctrl)
                        (if (self.deleteWordBackward()) .changed else .none)
                    else
                        (if (self.backspace()) .changed else .none),
                    .delete => return if (self.deleteForward()) .changed else .none,
                    .left => {
                        if (k.modifiers.ctrl) {
                            self.moveWordLeftEx(k.modifiers.shift);
                        } else {
                            self.moveLeftEx(k.modifiers.shift);
                        }
                        return .cursor_moved;
                    },
                    .right => {
                        if (k.modifiers.ctrl) {
                            self.moveWordRightEx(k.modifiers.shift);
                        } else {
                            self.moveRightEx(k.modifiers.shift);
                        }
                        return .cursor_moved;
                    },
                    .home => {
                        self.moveHomeEx(k.modifiers.shift);
                        return .cursor_moved;
                    },
                    .end => {
                        self.moveEndEx(k.modifiers.shift);
                        return .cursor_moved;
                    },
                    .char => |cp| {
                        if (k.modifiers.ctrl) {
                            switch (cp) {
                                'a' => {
                                    self.selectAll();
                                    return .cursor_moved;
                                },
                                'e' => {
                                    self.moveEndEx(k.modifiers.shift);
                                    return .cursor_moved;
                                },
                                'k' => {
                                    if (self.cursor < self.buffer.items.len) {
                                        self.buffer.shrinkRetainingCapacity(self.cursor);
                                        self.selection_anchor = null;
                                        return .changed;
                                    }
                                    return .none;
                                },
                                'u' => {
                                    self.clear();
                                    return .changed;
                                },
                                'w' => return if (self.deleteWordBackward()) .changed else .none,
                                else => return .none,
                            }
                        }
                        if (!k.modifiers.alt and cp >= 0x20) {
                            try self.insertCodepoint(cp);
                            return .changed;
                        }
                        return .none;
                    },
                    else => return .none,
                }
            },
            else => return .none,
        }
    }

    fn prevGraphemeStart(self: *const TextInputState, offset: usize) usize {
        var it = text_root.GraphemeIterator.init(self.buffer.items[0..offset]);
        var last_start: usize = 0;
        while (it.next()) |g| {
            last_start = it.index - g.slice.len;
        }
        return last_start;
    }

    fn nextGraphemeEnd(self: *const TextInputState, offset: usize) usize {
        if (offset >= self.buffer.items.len) return self.buffer.items.len;
        var it = text_root.GraphemeIterator.init(self.buffer.items[offset..]);
        _ = it.next() orelse return self.buffer.items.len;
        return offset + it.index;
    }
};

/// Single-line text entry widget with optional label, prefix, placeholder, masking,
/// validation border/message indicator, and automatic hardware cursor positioning.
pub const TextInput = struct {
    label: ?[]const u8 = null,
    placeholder: []const u8 = "",
    prefix: ?[]const u8 = null,
    focused: bool = false,
    disabled: bool = false,
    password: bool = false,
    mask_char: []const u8 = "•",
    cursor_visible: bool = true,
    block: ?Block = .{ .border_type = .rounded },
    validation: ValidationStatus = .none,
    error_message: ?[]const u8 = null,
    style: ?Style = null,
    focused_style: ?Style = null,
    placeholder_style: ?Style = null,

    /// Search bar preset (`🔍 ` prefix).
    pub fn search(placeholder: []const u8) TextInput {
        return .{ .prefix = "🔍 ", .placeholder = placeholder };
    }

    /// Command prompt preset (`> ` prefix).
    pub fn command(placeholder: []const u8) TextInput {
        return .{ .prefix = "> ", .placeholder = placeholder };
    }

    /// Password entry preset masking characters with `"•"`.
    pub fn secret(placeholder: []const u8) TextInput {
        return .{ .password = true, .placeholder = placeholder };
    }

    /// Maps display column `target_col` inside `raw_text` to exact UTF-8 grapheme boundary byte offset.
    fn byteOffsetForCol(self: TextInput, raw_text: []const u8, target_col: u16) usize {
        var col: u16 = 0;
        var git = text_root.GraphemeIterator.init(raw_text);
        while (git.next()) |g| {
            const w: u16 = if (self.password) 1 else g.width;
            if (w == 0) continue;
            if (col + (w / 2) >= target_col or col >= target_col) {
                return git.index - g.slice.len;
            }
            col += w;
        }
        return raw_text.len;
    }

    /// Handles mouse click-to-cursor, drag selection, keyboard editing, and `disabled` guards within `area`.
    pub fn handleEvent(self: TextInput, state: *TextInputState, event: Event, area: Rect) !InputAction {
        if (self.disabled) return .none;
        if (event == .mouse) {
            const m = event.mouse;
            const inner = if (self.block) |b| b.inner(area) else area;
            if (!m.isInside(inner)) return .none;
            const pfx_w: u16 = if (self.prefix) |pfx| text_root.displayWidth(pfx) else 0;
            const text_x = inner.left() +| pfx_w;
            if ((m.kind == .down or m.kind == .drag) and m.button == .left) {
                const target_col = (m.x -| text_x) +| state.scroll_offset;
                const byte_off = self.byteOffsetForCol(state.text(), target_col);
                if (m.kind == .down and !m.modifiers.shift) {
                    state.selection_anchor = null;
                } else if (state.selection_anchor == null) {
                    state.selection_anchor = state.cursor;
                }
                state.cursor = byte_off;
                return .cursor_moved;
            }
            return .none;
        }
        return state.handleEvent(event, self.focused);
    }

    /// Renders this text input using `state`.
    pub fn renderStateful(self: TextInput, ui: *Ui, area: Rect, state: *TextInputState) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        const field_style = if (self.disabled)
            ui.theme.disabled
        else if (self.focused)
            self.focused_style orelse ui.theme.input_focused
        else
            self.style orelse ui.theme.input;

        var inner = bounds;
        if (self.block) |blk_base| {
            if (bounds.height >= 3 and bounds.width >= 4) {
                var blk = blk_base;
                if (blk.title == null and self.label != null) blk.title = self.label;
                blk.focused = self.focused;
                blk.style = field_style;
                blk.fill_background = true;
                if (self.validation == .invalid) {
                    blk.border_style = ui.theme.err;
                } else if (self.validation == .valid) {
                    blk.border_style = ui.theme.success;
                }
                if (self.error_message) |err_msg| {
                    if (self.validation == .invalid and blk.title_bottom == null) {
                        blk.title_bottom = err_msg;
                    }
                }
                try blk.render(ui, bounds);
                inner = blk.inner(bounds);
            } else {
                ui.buffer.fill(bounds, " ", field_style);
            }
        } else {
            ui.buffer.fill(bounds, " ", field_style);
        }

        if (inner.isEmpty()) return;
        const y = inner.top() + inner.height / 2;

        var text_start_x = inner.left();
        if (self.prefix) |pfx| {
            text_start_x = ui.buffer.setStringClipped(
                text_start_x,
                y,
                pfx,
                inner.width,
                ui.theme.accent,
                inner,
            ).x;
        }

        const view_w = inner.right() -| text_start_x;
        if (view_w == 0) return;

        const raw_text = state.text();
        if (raw_text.len == 0) {
            if (self.placeholder.len > 0) {
                const ph_style = self.placeholder_style orelse ui.theme.muted;
                _ = ui.buffer.setStringClipped(text_start_x, y, self.placeholder, view_w, ph_style, inner);
            }
            if (self.focused and !self.disabled and self.cursor_visible) {
                ui.setCursor(text_start_x, y);
            }
            return;
        }

        const cursor_col: u16 = if (self.password) blk_col: {
            var c: u16 = 0;
            var git = text_root.GraphemeIterator.init(raw_text[0..state.cursor]);
            while (git.next()) |_| c += 1;
            break :blk_col c;
        } else state.cursorDisplayCol();

        // Keep cursor comfortably visible inside horizontal viewport.
        if (cursor_col < state.scroll_offset) {
            state.scroll_offset = cursor_col;
        } else if (cursor_col >= state.scroll_offset +| view_w) {
            state.scroll_offset = cursor_col - view_w + 1;
        }

        const sel_range = state.selectedRange();
        const sel_style = field_style.patch(ui.theme.selection);

        if (self.password) {
            var vis_col: u16 = 0;
            var git = text_root.GraphemeIterator.init(raw_text);
            while (git.next()) |g| {
                const start_b = git.index - g.slice.len;
                const end_b = git.index;
                if (vis_col < state.scroll_offset) {
                    vis_col += 1;
                    continue;
                }
                const draw_col = vis_col - state.scroll_offset;
                if (draw_col >= view_w) break;
                const is_sel = if (sel_range) |sr| end_b > sr.start and start_b < sr.end else false;
                const ch_style = if (is_sel) sel_style else field_style;
                _ = ui.buffer.setStringClipped(text_start_x + draw_col, y, self.mask_char, 1, ch_style, inner);
                vis_col += 1;
            }
        } else {
            // Skip `state.scroll_offset` columns then render up to `view_w` columns with selection highlights.
            var skipped: u16 = 0;
            var draw_x = text_start_x;
            var git = text_root.GraphemeIterator.init(raw_text);
            while (git.next()) |g| {
                if (g.width == 0) continue;
                const start_b = git.index - g.slice.len;
                const end_b = git.index;
                if (skipped < state.scroll_offset) {
                    skipped += g.width;
                    if (skipped > state.scroll_offset and draw_x < inner.right()) {
                        // A 2-column glyph straddles the left scroll boundary: pad 1 space to keep cursor aligned.
                        draw_x = ui.buffer.setStringClipped(draw_x, y, " ", 1, field_style, inner).x;
                    }
                    continue;
                }
                if (draw_x + g.width > inner.right()) break;
                const is_sel = if (sel_range) |sr| end_b > sr.start and start_b < sr.end else false;
                const ch_style = if (is_sel) sel_style else field_style;
                draw_x = ui.buffer.setStringClipped(draw_x, y, g.slice, g.width, ch_style, inner).x;
            }
        }

        if (self.focused and !self.disabled and self.cursor_visible) {
            const rel_x = cursor_col -| state.scroll_offset;
            const abs_x = @min(text_start_x +| rel_x, inner.right() -| 1);
            ui.setCursor(abs_x, y);
        }
    }
};

test "text input editing, zigantic validation, and cursor tracking" {
    const alloc = testing.allocator;
    var state = TextInputState.init(alloc);
    defer state.deinit();

    _ = try state.handleEvent(.{ .key = .{ .code = .{ .char = 'a' } } }, true);
    _ = try state.handleEvent(.{ .key = .{ .code = .{ .char = 'b' } } }, true);
    _ = try state.handleEvent(.{ .key = .{ .code = .left } }, true);
    _ = try state.handleEvent(.{ .key = .{ .code = .{ .char = 'x' } } }, true);
    try testing.expectEqualStrings("axb", state.text());

    var err_buf: [128]u8 = undefined;
    const min_schema = z.string(.{ .min = 5 });
    const res_fail = state.validateWithSchema(min_schema, &err_buf);
    try testing.expect(!res_fail.valid);

    try state.insertSlice("12");
    const res_ok = state.validateWithSchema(min_schema, &err_buf);
    try testing.expect(res_ok.valid);

    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 20, 3));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    try ui.renderStateful(TextInput{ .label = "User", .focused = true }, &state, buf.area);
    try testing.expect(cursor != null);
    try testing.expectEqual(@as(u16, 1), cursor.?.y);

    // Ctrl+Left word navigation and Shift+Left selection range + replacement.
    try state.setText("hello world");
    _ = try state.handleEvent(.{ .key = .{ .code = .left, .modifiers = event_root.KeyModifiers.ctrl_only } }, true);
    try testing.expectEqual(@as(usize, 6), state.cursor);
    _ = try state.handleEvent(.{ .key = .{ .code = .end, .modifiers = event_root.KeyModifiers.shift_only } }, true);
    try testing.expectEqualStrings("world", state.selectedText().?);
    _ = try state.handleEvent(.{ .key = .{ .code = .{ .char = 'z' } } }, true);
    try testing.expectEqualStrings("hello z", state.text());

    // Mouse click positions cursor cleanly inside bordered TextInput.
    const inp = TextInput{ .label = "User", .focused = true };
    _ = try inp.handleEvent(&state, .{ .mouse = .{ .kind = .down, .button = .left, .x = 3, .y = 1 } }, buf.area);
    try testing.expectEqual(@as(usize, 2), state.cursor);
}
