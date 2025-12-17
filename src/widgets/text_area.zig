//! Text area widget for multi-line text editing

const std = @import("std");
const widget = @import("widget.zig");
const layout = @import("../layout/layout.zig");
const style_mod = @import("../style/style.zig");
const events = @import("../event/events.zig");
const input_mod = @import("../event/input.zig");
const unicode = @import("../unicode/unicode.zig");

pub const RenderContext = widget.RenderContext;
pub const StatefulWidget = widget.StatefulWidget;
pub const SizeHint = widget.SizeHint;
pub const EventResult = widget.EventResult;
pub const Style = style_mod.Style;
pub const Event = events.Event;
pub const Key = input_mod.Key;
pub const Rect = layout.Rect;

/// Text area widget for multi-line text editing
pub const TextArea = struct {
    allocator: std.mem.Allocator,

    /// Lines of text
    lines: std.ArrayListUnmanaged(std.ArrayListUnmanaged(u8)),

    /// Cursor position
    cursor_line: usize = 0,
    cursor_col: usize = 0,

    /// Scroll offset
    scroll_x: usize = 0,
    scroll_y: usize = 0,

    /// Show line numbers
    show_line_numbers: bool = false,

    /// Line number width
    line_number_width: u16 = 4,

    /// Word wrap
    word_wrap: bool = false,

    /// Read-only mode
    read_only: bool = false,

    /// Placeholder
    placeholder: []const u8 = "",

    /// Style
    style: Style = .{},
    focused_style: ?Style = null,
    line_number_style: ?Style = null,
    cursor_line_style: ?Style = null,

    /// Change callback
    on_change: ?*const fn () void = null,

    /// Base widget state
    base: StatefulWidget = .{},

    /// Create a text area
    pub fn init(allocator: std.mem.Allocator) TextArea {
        var lines = std.ArrayListUnmanaged(std.ArrayListUnmanaged(u8)){};
        // Start with one empty line
        lines.append(allocator, .{}) catch {};

        return .{
            .allocator = allocator,
            .lines = lines,
        };
    }

    /// Create with initial content
    pub fn initWithContent(allocator: std.mem.Allocator, content: []const u8) !TextArea {
        var result = init(allocator);
        try result.setText(content);
        return result;
    }

    /// Clean up
    pub fn deinit(self: *TextArea) void {
        for (self.lines.items) |*line| {
            line.deinit(self.allocator);
        }
        self.lines.deinit(self.allocator);
    }

    /// Set text content
    pub fn setText(self: *TextArea, content: []const u8) !void {
        // Clear existing lines
        for (self.lines.items) |*line| {
            line.deinit(self.allocator);
        }
        self.lines.clearRetainingCapacity();

        // Split content into lines
        var iter = std.mem.splitScalar(u8, content, '\n');
        while (iter.next()) |line_content| {
            var line = std.ArrayListUnmanaged(u8){};
            try line.appendSlice(self.allocator, line_content);
            try self.lines.append(self.allocator, line);
        }

        // Ensure at least one line
        if (self.lines.items.len == 0) {
            try self.lines.append(self.allocator, .{});
        }

        self.cursor_line = 0;
        self.cursor_col = 0;
        self.scroll_x = 0;
        self.scroll_y = 0;
        self.base.markDirty();
    }

    /// Get text content
    pub fn getText(self: *TextArea, allocator: std.mem.Allocator) ![]u8 {
        var total_len: usize = 0;
        for (self.lines.items) |line| {
            total_len += line.items.len + 1; // +1 for newline
        }
        if (total_len > 0) total_len -= 1; // Remove last newline

        var result = try allocator.alloc(u8, total_len);
        var pos: usize = 0;

        for (self.lines.items, 0..) |line, i| {
            @memcpy(result[pos..][0..line.items.len], line.items);
            pos += line.items.len;
            if (i + 1 < self.lines.items.len) {
                result[pos] = '\n';
                pos += 1;
            }
        }

        return result;
    }

    /// Clear all content
    pub fn clear(self: *TextArea) void {
        for (self.lines.items) |*line| {
            line.clearRetainingCapacity();
        }
        self.lines.clearRetainingCapacity();
        self.lines.append(self.allocator, .{}) catch {};
        self.cursor_line = 0;
        self.cursor_col = 0;
        self.base.markDirty();
    }

    /// Get current line
    fn getCurrentLine(self: *TextArea) *std.ArrayListUnmanaged(u8) {
        return &self.lines.items[self.cursor_line];
    }

    /// Get line count
    pub fn getLineCount(self: *TextArea) usize {
        return self.lines.items.len;
    }

    /// Enable line numbers
    pub fn withLineNumbers(self: TextArea) TextArea {
        var result = self;
        result.show_line_numbers = true;
        return result;
    }

    /// Enable word wrap
    pub fn withWordWrap(self: TextArea) TextArea {
        var result = self;
        result.word_wrap = true;
        return result;
    }

    /// Set read-only
    pub fn asReadOnly(self: TextArea) TextArea {
        var result = self;
        result.read_only = true;
        return result;
    }

    /// Render the text area
    pub fn render(self: *TextArea, ctx: *RenderContext) void {
        var sub = ctx.getSubScreen();

        const current_style = if (self.base.state.focused)
            self.focused_style orelse ctx.theme.input_focus
        else
            self.style.merge(ctx.theme.input);

        sub.setStyle(current_style);
        sub.clear();

        // Calculate text area offset for line numbers
        const text_x: u16 = if (self.show_line_numbers) self.line_number_width + 1 else 0;
        const text_width = sub.width -| text_x;

        // Update scroll to ensure cursor is visible
        self.ensureCursorVisible(sub.height, text_width);

        // Render visible lines
        const visible_lines = @min(self.lines.items.len - self.scroll_y, sub.height);

        for (0..visible_lines) |i| {
            const line_idx = self.scroll_y + i;
            const is_cursor_line = line_idx == self.cursor_line;

            // Draw line number
            if (self.show_line_numbers) {
                sub.setStyle(self.line_number_style orelse ctx.theme.muted);
                sub.moveCursor(0, @intCast(i));

                var num_buf: [8]u8 = undefined;
                const num_str = std.fmt.bufPrint(&num_buf, "{d:>4}", .{line_idx + 1}) catch "????";
                sub.putString(num_str);
                sub.putString(" ");
            }

            // Set line style
            if (is_cursor_line and self.cursor_line_style != null) {
                sub.setStyle(self.cursor_line_style.?);
            } else {
                sub.setStyle(current_style);
            }

            // Draw line content
            sub.moveCursor(text_x, @intCast(i));

            const line = self.lines.items[line_idx];
            const visible_start = @min(self.scroll_x, line.items.len);
            const visible_end = @min(visible_start + text_width, line.items.len);

            if (visible_end > visible_start) {
                sub.putString(line.items[visible_start..visible_end]);
            }
        }
    }

    fn ensureCursorVisible(self: *TextArea, height: u16, width: u16) void {
        // Vertical scrolling
        if (self.cursor_line < self.scroll_y) {
            self.scroll_y = self.cursor_line;
        } else if (self.cursor_line >= self.scroll_y + height) {
            self.scroll_y = self.cursor_line - height + 1;
        }

        // Horizontal scrolling
        if (self.cursor_col < self.scroll_x) {
            self.scroll_x = self.cursor_col;
        } else if (self.cursor_col >= self.scroll_x + width) {
            self.scroll_x = self.cursor_col - width + 1;
        }
    }

    /// Handle events
    pub fn handleEvent(self: *TextArea, event: Event) EventResult {
        if (self.base.state.disabled) return .ignored;

        switch (event) {
            .key => |key_event| {
                return self.handleKeyEvent(key_event);
            },
            .paste => |paste_event| {
                if (!self.read_only) {
                    self.insertText(paste_event.content) catch {};
                    return .consumed;
                }
            },
            else => {},
        }

        return .ignored;
    }

    fn handleKeyEvent(self: *TextArea, key_event: events.KeyEvent) EventResult {
        switch (key_event.key) {
            .char => |c| {
                if (!self.read_only) {
                    self.insertChar(c) catch {};
                    return .consumed;
                }
            },
            .enter => {
                if (!self.read_only) {
                    self.insertNewline() catch {};
                    return .consumed;
                }
            },
            .backspace => {
                if (!self.read_only) {
                    self.deleteBackward();
                    return .consumed;
                }
            },
            .delete => {
                if (!self.read_only) {
                    self.deleteForward();
                    return .consumed;
                }
            },
            .up => {
                self.moveCursorUp();
                return .consumed;
            },
            .down => {
                self.moveCursorDown();
                return .consumed;
            },
            .left => {
                self.moveCursorLeft();
                return .consumed;
            },
            .right => {
                self.moveCursorRight();
                return .consumed;
            },
            .home => {
                self.cursor_col = 0;
                self.base.markDirty();
                return .consumed;
            },
            .end => {
                self.cursor_col = self.getCurrentLine().items.len;
                self.base.markDirty();
                return .consumed;
            },
            .page_up => {
                const jump = @min(self.cursor_line, 10);
                self.cursor_line -= jump;
                self.clampCursorCol();
                self.base.markDirty();
                return .consumed;
            },
            .page_down => {
                const jump = @min(self.lines.items.len - 1 - self.cursor_line, 10);
                self.cursor_line += jump;
                self.clampCursorCol();
                self.base.markDirty();
                return .consumed;
            },
            .tab => {
                if (!self.read_only) {
                    self.insertText("    ") catch {};
                    return .consumed;
                }
            },
            else => {},
        }

        return .ignored;
    }

    fn insertChar(self: *TextArea, char: u21) !void {
        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(char, &buf) catch return;

        const line = self.getCurrentLine();
        try line.insertSlice(self.allocator, self.cursor_col, buf[0..len]);
        self.cursor_col += len;
        self.base.markDirty();
        self.notifyChange();
    }

    fn insertText(self: *TextArea, text: []const u8) !void {
        var iter = std.mem.splitScalar(u8, text, '\n');
        var first = true;

        while (iter.next()) |segment| {
            if (!first) {
                try self.insertNewline();
            }
            first = false;

            const line = self.getCurrentLine();
            try line.insertSlice(self.allocator, self.cursor_col, segment);
            self.cursor_col += segment.len;
        }

        self.base.markDirty();
        self.notifyChange();
    }

    fn insertNewline(self: *TextArea) !void {
        const current = self.getCurrentLine();
        const rest = current.items[self.cursor_col..];

        // Create new line with rest of current line
        var new_line = std.ArrayListUnmanaged(u8){};
        try new_line.appendSlice(self.allocator, rest);

        // Truncate current line
        current.shrinkRetainingCapacity(self.cursor_col);

        // Insert new line
        try self.lines.insert(self.allocator, self.cursor_line + 1, new_line);

        self.cursor_line += 1;
        self.cursor_col = 0;
        self.base.markDirty();
        self.notifyChange();
    }

    fn deleteBackward(self: *TextArea) void {
        if (self.cursor_col > 0) {
            const line = self.getCurrentLine();
            // Find previous character boundary
            var prev = self.cursor_col - 1;
            while (prev > 0 and (line.items[prev] & 0xC0) == 0x80) : (prev -= 1) {}

            for (0..(self.cursor_col - prev)) |_| {
                _ = line.orderedRemove(prev);
            }
            self.cursor_col = prev;
        } else if (self.cursor_line > 0) {
            // Join with previous line
            const current = self.getCurrentLine();
            const prev_line = &self.lines.items[self.cursor_line - 1];
            const prev_len = prev_line.items.len;

            prev_line.appendSlice(self.allocator, current.items) catch {};
            current.deinit(self.allocator);
            _ = self.lines.orderedRemove(self.cursor_line);

            self.cursor_line -= 1;
            self.cursor_col = prev_len;
        }

        self.base.markDirty();
        self.notifyChange();
    }

    fn deleteForward(self: *TextArea) void {
        const line = self.getCurrentLine();

        if (self.cursor_col < line.items.len) {
            // Find next character boundary
            var next = self.cursor_col + 1;
            while (next < line.items.len and (line.items[next] & 0xC0) == 0x80) : (next += 1) {}

            for (0..(next - self.cursor_col)) |_| {
                _ = line.orderedRemove(self.cursor_col);
            }
        } else if (self.cursor_line + 1 < self.lines.items.len) {
            // Join with next line
            const next_line = &self.lines.items[self.cursor_line + 1];
            line.appendSlice(self.allocator, next_line.items) catch {};
            next_line.deinit(self.allocator);
            _ = self.lines.orderedRemove(self.cursor_line + 1);
        }

        self.base.markDirty();
        self.notifyChange();
    }

    fn moveCursorUp(self: *TextArea) void {
        if (self.cursor_line > 0) {
            self.cursor_line -= 1;
            self.clampCursorCol();
            self.base.markDirty();
        }
    }

    fn moveCursorDown(self: *TextArea) void {
        if (self.cursor_line + 1 < self.lines.items.len) {
            self.cursor_line += 1;
            self.clampCursorCol();
            self.base.markDirty();
        }
    }

    fn moveCursorLeft(self: *TextArea) void {
        if (self.cursor_col > 0) {
            self.cursor_col -= 1;
            const line = self.getCurrentLine();
            while (self.cursor_col > 0 and (line.items[self.cursor_col] & 0xC0) == 0x80) {
                self.cursor_col -= 1;
            }
            self.base.markDirty();
        } else if (self.cursor_line > 0) {
            self.cursor_line -= 1;
            self.cursor_col = self.getCurrentLine().items.len;
            self.base.markDirty();
        }
    }

    fn moveCursorRight(self: *TextArea) void {
        const line = self.getCurrentLine();
        if (self.cursor_col < line.items.len) {
            self.cursor_col += 1;
            while (self.cursor_col < line.items.len and (line.items[self.cursor_col] & 0xC0) == 0x80) {
                self.cursor_col += 1;
            }
            self.base.markDirty();
        } else if (self.cursor_line + 1 < self.lines.items.len) {
            self.cursor_line += 1;
            self.cursor_col = 0;
            self.base.markDirty();
        }
    }

    fn clampCursorCol(self: *TextArea) void {
        const line_len = self.getCurrentLine().items.len;
        self.cursor_col = @min(self.cursor_col, line_len);
    }

    fn notifyChange(self: *TextArea) void {
        if (self.on_change) |callback| {
            callback();
        }
    }

    /// Check if focusable
    pub fn isFocusable(self: *TextArea) bool {
        return !self.base.state.disabled;
    }

    /// Set focus
    pub fn setFocus(self: *TextArea, focused: bool) void {
        self.base.state.focused = focused;
        self.base.markDirty();
    }

    /// Get size hint
    pub fn sizeHint(self: *TextArea) SizeHint {
        _ = self;
        return .{
            .min_width = 20,
            .preferred_width = 80,
            .min_height = 5,
            .preferred_height = 20,
            .expand_x = true,
            .expand_y = true,
        };
    }
};

test "text area creation" {
    const allocator = std.testing.allocator;
    var ta = TextArea.init(allocator);
    defer ta.deinit();

    try std.testing.expectEqual(@as(usize, 1), ta.getLineCount());
}

test "text area set text" {
    const allocator = std.testing.allocator;
    var ta = TextArea.init(allocator);
    defer ta.deinit();

    try ta.setText("Line 1\nLine 2\nLine 3");
    try std.testing.expectEqual(@as(usize, 3), ta.getLineCount());
}
