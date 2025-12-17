//! Input field widget for text entry

const std = @import("std");
const widget = @import("widget.zig");
const layout = @import("../layout/layout.zig");
const style_mod = @import("../style/style.zig");
const events = @import("../event/events.zig");
const input_mod = @import("../event/input.zig");
const unicode = @import("../unicode/unicode.zig");
const screen_mod = @import("../core/screen.zig");

pub const RenderContext = widget.RenderContext;
pub const StatefulWidget = widget.StatefulWidget;
pub const SizeHint = widget.SizeHint;
pub const EventResult = widget.EventResult;
pub const Style = style_mod.Style;
pub const Event = events.Event;
pub const Key = input_mod.Key;
pub const Rect = layout.Rect;

/// Input field widget
pub const InputField = struct {
    /// Allocator
    allocator: std.mem.Allocator,

    /// Current text value
    value: std.ArrayListUnmanaged(u8),

    /// Placeholder text
    placeholder: []const u8 = "",

    /// Cursor position (in bytes)
    cursor: usize = 0,

    /// Scroll offset for long text
    scroll_offset: usize = 0,

    /// Is password mode
    password: bool = false,

    /// Maximum length (0 = unlimited)
    max_length: usize = 0,

    /// Change callback
    on_change: ?*const fn ([]const u8) void = null,

    /// Submit callback (on Enter)
    on_submit: ?*const fn ([]const u8) void = null,

    /// Style
    style: Style = .{},

    /// Focused style
    focused_style: ?Style = null,

    /// Base widget state
    base: StatefulWidget = .{},

    /// Create an input field
    pub fn init(allocator: std.mem.Allocator) InputField {
        return .{
            .allocator = allocator,
            .value = .{},
        };
    }

    /// Create with initial value
    pub fn initWithValue(allocator: std.mem.Allocator, initial: []const u8) !InputField {
        var result = init(allocator);
        try result.value.appendSlice(allocator, initial);
        result.cursor = initial.len;
        return result;
    }

    /// Clean up
    pub fn deinit(self: *InputField) void {
        self.value.deinit(self.allocator);
    }

    /// Set placeholder
    pub fn withPlaceholder(self: InputField, text: []const u8) InputField {
        var result = self;
        result.placeholder = text;
        return result;
    }

    /// Set maximum length
    pub fn withMaxLength(self: InputField, length: usize) InputField {
        var result = self;
        result.max_length = length;
        return result;
    }

    /// Enable password mode
    pub fn withPasswordMode(self: InputField) InputField {
        var result = self;
        result.password = true;
        return result;
    }

    /// Get current value
    pub fn getValue(self: *const InputField) []const u8 {
        return self.value.items;
    }

    /// Set value
    pub fn setValue(self: *InputField, text: []const u8) !void {
        self.value.clearRetainingCapacity();
        try self.value.appendSlice(self.allocator, text);
        self.cursor = @min(self.cursor, text.len);
        self.notifyChange();
    }

    /// Clear the field
    pub fn clear(self: *InputField) void {
        self.value.clearRetainingCapacity();
        self.cursor = 0;
        self.scroll_offset = 0;
        self.notifyChange();
    }

    /// Render the input field
    pub fn render(self: *InputField, ctx: *RenderContext) void {
        const current_style = if (self.base.state.focused)
            self.focused_style orelse ctx.theme.input_focus
        else
            self.style.merge(ctx.theme.input);

        var sub = ctx.getSubScreen();
        sub.setStyle(current_style);

        // Clear background
        sub.clear();

        // Determine what to display
        const display_text = if (self.value.items.len == 0)
            self.placeholder
        else if (self.password)
            self.getPasswordMask()
        else
            self.value.items;

        // Calculate visible portion
        self.updateScrollOffset(sub.width);
        const visible_start = self.scroll_offset;
        const visible_end = @min(display_text.len, visible_start + sub.width);

        // Draw text
        sub.moveCursor(0, 0);
        if (visible_end > visible_start) {
            sub.putString(display_text[visible_start..visible_end]);
        }

        // Draw cursor if focused
        if (self.base.state.focused and sub.width > 0) {
            // Cursor rendering would be done here
            // For now, the cursor position is calculated for potential future use
        }
    }

    fn getPasswordMask(self: *InputField) []const u8 {
        // Return a string of asterisks matching the input length
        _ = self;
        return "********"; // Simplified - would need dynamic allocation
    }

    fn getCursorDisplayX(self: *InputField) u16 {
        // Calculate display position of cursor
        return @intCast(unicode.stringWidth(self.value.items[0..self.cursor]));
    }

    fn updateScrollOffset(self: *InputField, visible_width: u16) void {
        const cursor_x = self.getCursorDisplayX();

        // Scroll right if cursor is past visible area
        if (cursor_x >= self.scroll_offset + visible_width) {
            self.scroll_offset = cursor_x - visible_width + 1;
        }

        // Scroll left if cursor is before visible area
        if (cursor_x < self.scroll_offset) {
            self.scroll_offset = cursor_x;
        }
    }

    /// Handle events
    pub fn handleEvent(self: *InputField, event: Event) EventResult {
        if (self.base.state.disabled) return .ignored;

        switch (event) {
            .key => |key_event| {
                return self.handleKeyEvent(key_event);
            },
            .paste => |paste_event| {
                self.insertText(paste_event.content) catch {};
                return .consumed;
            },
            else => {},
        }

        return .ignored;
    }

    fn handleKeyEvent(self: *InputField, key_event: events.KeyEvent) EventResult {
        switch (key_event.key) {
            .char => |c| {
                self.insertChar(c) catch {};
                return .consumed;
            },
            .backspace => {
                self.deleteBackward();
                return .consumed;
            },
            .delete => {
                self.deleteForward();
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
                self.cursor = 0;
                self.base.markDirty();
                return .consumed;
            },
            .end => {
                self.cursor = self.value.items.len;
                self.base.markDirty();
                return .consumed;
            },
            .enter => {
                if (self.on_submit) |callback| {
                    callback(self.value.items);
                }
                return .consumed;
            },
            else => {},
        }

        return .ignored;
    }

    fn insertChar(self: *InputField, char: u21) !void {
        if (self.max_length > 0 and self.value.items.len >= self.max_length) return;

        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(char, &buf) catch return;

        try self.value.insertSlice(self.allocator, self.cursor, buf[0..len]);
        self.cursor += len;
        self.base.markDirty();
        self.notifyChange();
    }

    fn insertText(self: *InputField, text: []const u8) !void {
        try self.value.insertSlice(self.allocator, self.cursor, text);
        self.cursor += text.len;
        self.base.markDirty();
        self.notifyChange();
    }

    fn deleteBackward(self: *InputField) void {
        if (self.cursor == 0) return;

        // Find previous character boundary
        var prev = self.cursor - 1;
        while (prev > 0 and (self.value.items[prev] & 0xC0) == 0x80) : (prev -= 1) {}

        _ = self.value.orderedRemove(prev);
        for (0..(self.cursor - prev - 1)) |_| {
            _ = self.value.orderedRemove(prev);
        }
        self.cursor = prev;
        self.base.markDirty();
        self.notifyChange();
    }

    fn deleteForward(self: *InputField) void {
        if (self.cursor >= self.value.items.len) return;

        // Find next character boundary
        var next = self.cursor + 1;
        while (next < self.value.items.len and (self.value.items[next] & 0xC0) == 0x80) : (next += 1) {}

        for (0..(next - self.cursor)) |_| {
            _ = self.value.orderedRemove(self.cursor);
        }
        self.base.markDirty();
        self.notifyChange();
    }

    fn moveCursorLeft(self: *InputField) void {
        if (self.cursor == 0) return;

        self.cursor -= 1;
        while (self.cursor > 0 and (self.value.items[self.cursor] & 0xC0) == 0x80) : (self.cursor -= 1) {}
        self.base.markDirty();
    }

    fn moveCursorRight(self: *InputField) void {
        if (self.cursor >= self.value.items.len) return;

        self.cursor += 1;
        while (self.cursor < self.value.items.len and (self.value.items[self.cursor] & 0xC0) == 0x80) : (self.cursor += 1) {}
        self.base.markDirty();
    }

    fn notifyChange(self: *InputField) void {
        if (self.on_change) |callback| {
            callback(self.value.items);
        }
    }

    /// Check if focusable
    pub fn isFocusable(self: *InputField) bool {
        return !self.base.state.disabled;
    }

    /// Set focus
    pub fn setFocus(self: *InputField, focused: bool) void {
        self.base.state.focused = focused;
        self.base.markDirty();
    }

    /// Get size hint
    pub fn sizeHint(self: *InputField) SizeHint {
        _ = self;
        return .{
            .min_width = 10,
            .preferred_width = 30,
            .min_height = 1,
            .preferred_height = 1,
            .expand_x = true,
        };
    }
};

test "input field creation" {
    const allocator = std.testing.allocator;
    var field = InputField.init(allocator);
    defer field.deinit();

    try std.testing.expectEqualStrings("", field.getValue());
}

test "input field with value" {
    const allocator = std.testing.allocator;
    var field = try InputField.initWithValue(allocator, "Hello");
    defer field.deinit();

    try std.testing.expectEqualStrings("Hello", field.getValue());
}
