//! Table widget

const std = @import("std");
const widget = @import("widget.zig");
const layout = @import("../layout/layout.zig");
const style_mod = @import("../style/style.zig");
const events = @import("../event/events.zig");
const unicode = @import("../unicode/unicode.zig");

pub const RenderContext = widget.RenderContext;
pub const StatefulWidget = widget.StatefulWidget;
pub const SizeHint = widget.SizeHint;
pub const EventResult = widget.EventResult;
pub const Style = style_mod.Style;
pub const Event = events.Event;
pub const Rect = layout.Rect;
pub const BorderStyle = style_mod.BorderStyle;

/// Table column definition
pub const Column = struct {
    header: []const u8,
    width: ColumnWidth = .auto,
    alignment: style_mod.Alignment = .left,
};

/// Column width specification
pub const ColumnWidth = union(enum) {
    auto,
    fixed: u16,
    percent: u8,
    flex: u16,
};

/// Table widget for displaying tabular data
pub fn Table(comptime T: type) type {
    return struct {
        /// Column definitions
        columns: []const Column,

        /// Data rows
        rows: []const T,

        /// Cell renderer
        render_cell: *const fn (row: T, col_index: usize, buf: []u8) []const u8,

        /// Selected row
        selected_row: usize = 0,

        /// Scroll offset
        scroll_offset: usize = 0,

        /// Show header row
        show_header: bool = true,

        /// Show row separators
        show_row_separators: bool = false,

        /// Border style
        border: BorderStyle = .none,

        /// Header style
        header_style: ?Style = null,

        /// Row styles
        row_style: ?Style = null,
        selected_row_style: ?Style = null,
        alternate_row_style: ?Style = null,

        /// Selection callback
        on_select: ?*const fn (row: T, index: usize) void = null,

        /// Base widget state
        base: StatefulWidget = .{},

        const Self = @This();

        /// Create a table
        pub fn init(
            columns: []const Column,
            rows: []const T,
            render_cell: *const fn (T, usize, []u8) []const u8,
        ) Self {
            return .{
                .columns = columns,
                .rows = rows,
                .render_cell = render_cell,
            };
        }

        /// Add border
        pub fn withBorder(self: Self, b: BorderStyle) Self {
            var result = self;
            result.border = b;
            return result;
        }

        /// Show row separators
        pub fn withRowSeparators(self: Self) Self {
            var result = self;
            result.show_row_separators = true;
            return result;
        }

        /// Set selection callback
        pub fn onSelect(self: Self, callback: *const fn (T, usize) void) Self {
            var result = self;
            result.on_select = callback;
            return result;
        }

        /// Select a row
        pub fn selectRow(self: *Self, index: usize) void {
            if (index >= self.rows.len) return;

            self.selected_row = index;
            self.ensureVisible();
            self.base.markDirty();

            if (self.on_select) |callback| {
                callback(self.rows[index], index);
            }
        }

        fn ensureVisible(self: *Self) void {
            const visible_count = self.getVisibleRows();

            if (self.selected_row < self.scroll_offset) {
                self.scroll_offset = self.selected_row;
            } else if (self.selected_row >= self.scroll_offset + visible_count) {
                self.scroll_offset = self.selected_row - visible_count + 1;
            }
        }

        fn getVisibleRows(self: *Self) usize {
            var available = self.base.bounds.height;
            if (self.show_header) available -= 1;
            if (self.border != .none) available -= 2;
            return @min(self.rows.len, available);
        }

        /// Calculate column widths
        fn calculateColumnWidths(self: *Self, total_width: u16) []u16 {
            var widths: [32]u16 = undefined;
            const col_count = @min(self.columns.len, 32);

            var fixed_total: u32 = 0;
            var flex_total: u32 = 0;

            for (self.columns[0..col_count], 0..) |col, i| {
                switch (col.width) {
                    .fixed => |w| {
                        widths[i] = w;
                        fixed_total += w;
                    },
                    .percent => |p| {
                        widths[i] = @intCast((@as(u32, total_width) * @as(u32, p)) / 100);
                        fixed_total += widths[i];
                    },
                    .flex => |f| {
                        flex_total += f;
                        widths[i] = 0;
                    },
                    .auto => {
                        widths[i] = @intCast(unicode.stringWidth(col.header) + 2);
                        fixed_total += widths[i];
                    },
                }
            }

            // Distribute remaining space to flex columns
            if (flex_total > 0 and total_width > fixed_total) {
                const remaining = total_width - @as(u16, @intCast(fixed_total));
                for (self.columns[0..col_count], 0..) |col, i| {
                    if (col.width == .flex) {
                        widths[i] = @intCast((@as(u32, remaining) * col.width.flex) / flex_total);
                    }
                }
            }

            return widths[0..col_count];
        }

        /// Render the table
        pub fn render(self: *Self, ctx: *RenderContext) void {
            var sub = ctx.getSubScreen();
            var y: u16 = 0;

            const widths = self.calculateColumnWidths(sub.width);
            var cell_buf: [256]u8 = undefined;

            // Draw header
            if (self.show_header) {
                sub.setStyle(self.header_style orelse ctx.theme.table_header);
                sub.moveCursor(0, y);

                var x: u16 = 0;
                for (self.columns, widths) |col, width| {
                    self.renderCellPadded(&sub, col.header, x, width, col.alignment);
                    x += width;
                }
                y += 1;

                // Header separator
                if (self.border != .none and y < sub.height) {
                    sub.setStyle(ctx.theme.border);
                    sub.moveCursor(0, y);
                    for (0..sub.width) |_| {
                        sub.putString("─");
                    }
                    y += 1;
                }
            }

            // Draw rows
            const visible_rows = self.getVisibleRows();
            for (0..visible_rows) |i| {
                if (y >= sub.height) break;

                const row_idx = self.scroll_offset + i;
                const is_selected = row_idx == self.selected_row;
                const is_alternate = i % 2 == 1;

                // Set row style
                if (is_selected) {
                    sub.setStyle(self.selected_row_style orelse ctx.theme.list_item_selected);
                } else if (is_alternate and self.alternate_row_style != null) {
                    sub.setStyle(self.alternate_row_style.?);
                } else {
                    sub.setStyle(self.row_style orelse ctx.theme.table_row_even);
                }

                sub.moveCursor(0, y);

                var x: u16 = 0;
                for (self.columns, widths, 0..) |col, width, col_idx| {
                    const cell_text = self.render_cell(self.rows[row_idx], col_idx, cell_buf[0..]);
                    self.renderCellPadded(&sub, cell_text, x, width, col.alignment);
                    x += width;
                }

                y += 1;
            }
        }

        fn renderCellPadded(
            self: *Self,
            sub: *widget.SubScreen,
            text: []const u8,
            x: u16,
            width: u16,
            alignment: style_mod.Alignment,
        ) void {
            _ = self;

            const text_width = unicode.stringWidth(text);
            const pad_left = alignment.calculate(text_width, width);

            sub.moveCursor(x + @as(u16, @intCast(pad_left)), sub.cursor_y);

            // Truncate if needed
            if (text_width > width) {
                const truncated = unicode.truncateToWidth(text, width -| 1);
                sub.putString(text[0..truncated]);
                sub.putString("…");
            } else {
                sub.putString(text);
            }
        }

        /// Handle events
        pub fn handleEvent(self: *Self, event: Event) EventResult {
            if (self.base.state.disabled or self.rows.len == 0) return .ignored;

            switch (event) {
                .key => |key_event| {
                    switch (key_event.key) {
                        .up => {
                            if (self.selected_row > 0) {
                                self.selectRow(self.selected_row - 1);
                            }
                            return .consumed;
                        },
                        .down => {
                            if (self.selected_row + 1 < self.rows.len) {
                                self.selectRow(self.selected_row + 1);
                            }
                            return .consumed;
                        },
                        .home => {
                            self.selectRow(0);
                            return .consumed;
                        },
                        .end => {
                            self.selectRow(self.rows.len - 1);
                            return .consumed;
                        },
                        else => {},
                    }
                },
                else => {},
            }

            return .ignored;
        }

        /// Check if focusable
        pub fn isFocusable(self: *Self) bool {
            return !self.base.state.disabled and self.rows.len > 0;
        }

        /// Get size hint
        pub fn sizeHint(self: *Self) SizeHint {
            var min_width: u16 = 0;
            for (self.columns) |col| {
                min_width += @as(u16, @intCast(unicode.stringWidth(col.header) + 2));
            }

            return .{
                .min_width = min_width,
                .preferred_width = @max(min_width, 60),
                .min_height = @intCast(@min(self.rows.len, 10) + (if (self.show_header) @as(usize, 1) else 0)),
                .preferred_height = @intCast(self.rows.len + (if (self.show_header) @as(usize, 1) else 0)),
            };
        }
    };
}

test "table creation" {
    const Person = struct { name: []const u8, age: u8 };
    const columns = [_]Column{
        .{ .header = "Name", .width = .{ .fixed = 20 } },
        .{ .header = "Age", .width = .{ .fixed = 5 } },
    };
    const rows = [_]Person{
        .{ .name = "Alice", .age = 30 },
        .{ .name = "Bob", .age = 25 },
    };

    const table = Table(Person).init(&columns, &rows, struct {
        fn render(row: Person, col: usize, buf: []u8) []const u8 {
            return switch (col) {
                0 => row.name,
                1 => std.fmt.bufPrint(buf, "{d}", .{row.age}) catch "?",
                else => "",
            };
        }
    }.render);

    try std.testing.expectEqual(@as(usize, 2), table.rows.len);
    try std.testing.expectEqual(@as(usize, 2), table.columns.len);
}
