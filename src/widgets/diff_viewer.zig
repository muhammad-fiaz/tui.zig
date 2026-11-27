//! Unified `DiffViewer` inspector with old/new line numbers and semantic highlighting.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const event_root = @import("../event/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const Block = block_mod.Block;
pub const Event = event_root.Event;

/// Unified diff line category.
pub const DiffKind = enum {
    context,
    added,
    removed,
    hunk,
};

/// Single row inside `DiffViewer`.
pub const DiffLine = struct {
    kind: DiffKind = .context,
    old_line: ?u32 = null,
    new_line: ?u32 = null,
    text: []const u8,
};

/// Scroll and line selection state for `DiffViewer`.
pub const DiffViewerState = struct {
    scroll_y: usize = 0,
    selected: ?usize = null,

    pub fn handleEvent(self: *DiffViewerState, event: Event, line_count: usize, viewport_rows: u16, bounds: Rect, focused: bool) bool {
        if (line_count == 0) return false;
        const max_off = line_count -| viewport_rows;
        switch (event) {
            .mouse => |m| {
                if (!m.isInside(bounds)) return false;
                if (m.kind == .scroll_up) {
                    self.scroll_y -|= 3;
                    return true;
                }
                if (m.kind == .scroll_down) {
                    self.scroll_y = @min(max_off, self.scroll_y + 3);
                    return true;
                }
                if (m.isLeftClickInside(bounds)) {
                    const row = self.scroll_y + (m.y - bounds.top());
                    if (row < line_count) {
                        self.selected = row;
                        return true;
                    }
                }
                return false;
            },
            .key => |k| {
                if (!focused or k.kind == .release) return false;
                const page = @max(@as(usize, 1), viewport_rows);
                switch (k.code) {
                    .down => {
                        self.scroll_y = @min(max_off, self.scroll_y + 1);
                        return true;
                    },
                    .up => {
                        self.scroll_y -|= 1;
                        return true;
                    },
                    .page_down => {
                        self.scroll_y = @min(max_off, self.scroll_y + page);
                        return true;
                    },
                    .page_up => {
                        self.scroll_y -|= page;
                        return true;
                    },
                    .home => {
                        self.scroll_y = 0;
                        return true;
                    },
                    .end => {
                        self.scroll_y = max_off;
                        return true;
                    },
                    .char => |cp| {
                        if (cp == 'j') {
                            self.scroll_y = @min(max_off, self.scroll_y + 1);
                            return true;
                        }
                        if (cp == 'k') {
                            self.scroll_y -|= 1;
                            return true;
                        }
                        return false;
                    },
                    else => return false,
                }
            },
            else => return false,
        }
    }
};

/// Unified diff viewer with old/new line numbers and semantic `+`/`-`/`@@` highlighting.
pub const DiffViewer = struct {
    lines: []const DiffLine = &.{},
    block: ?Block = .{ .title = "Diff" },
    show_line_numbers: bool = true,
    focused: bool = true,

    /// Handles keyboard & mouse scroll/selection events using inner content bounds.
    pub fn handleEvent(self: DiffViewer, state: *DiffViewerState, event: Event, bounds: Rect) bool {
        const inner = if (self.block) |b| b.inner(bounds) else bounds;
        return state.handleEvent(event, self.lines.len, inner.height, inner, self.focused);
    }

    pub fn renderStateful(self: DiffViewer, ui: *Ui, area: Rect, state: *DiffViewerState) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        const max_off = self.lines.len -| inner.height;
        if (state.scroll_y > max_off) state.scroll_y = max_off;

        var drawn: u16 = 0;
        var num_buf: [16]u8 = undefined;
        var idx = state.scroll_y;
        while (idx < self.lines.len and drawn < inner.height) : ({
            idx += 1;
            drawn += 1;
        }) {
            const dl = self.lines[idx];
            const gy = inner.top() + drawn;
            const row_rect = Rect.init(inner.left(), gy, inner.width, 1);

            const is_sel = if (state.selected) |sel| sel == idx else false;
            const line_style: Style = if (is_sel)
                ui.theme.selection
            else switch (dl.kind) {
                .context => ui.theme.text,
                .added => .{ .foreground = ui.theme.success.foreground, .background = style_root.palette.emerald.c950 },
                .removed => .{ .foreground = ui.theme.err.foreground, .background = style_root.palette.rose.c950 },
                .hunk => ui.theme.info.patch(.{ .bold = true }),
            };
            ui.buffer.fill(row_rect, " ", line_style);

            var x = inner.left();
            if (self.show_line_numbers and inner.width > 12) {
                const old_s = if (dl.old_line) |n| std.fmt.bufPrint(&num_buf, "{d:>4}", .{n}) catch "    " else "    ";
                x = ui.buffer.setStringClipped(x, gy, old_s, 4, ui.theme.muted, row_rect).x;
                x = ui.buffer.setStringClipped(x, gy, " ", 1, ui.theme.muted, row_rect).x;
                var num2_buf: [16]u8 = undefined;
                const new_s = if (dl.new_line) |n| std.fmt.bufPrint(&num2_buf, "{d:>4}", .{n}) catch "    " else "    ";
                x = ui.buffer.setStringClipped(x, gy, new_s, 4, ui.theme.muted, row_rect).x;
                x = ui.buffer.setStringClipped(x, gy, " │ ", 3, ui.theme.border, row_rect).x;
            }
            const prefix = switch (dl.kind) {
                .context => "  ",
                .added => "+ ",
                .removed => "- ",
                .hunk => "",
            };
            x = ui.buffer.setStringClipped(x, gy, prefix, inner.right() -| x, line_style.patch(.{ .bold = true }), row_rect).x;
            _ = ui.buffer.setStringClipped(x, gy, dl.text, inner.right() -| x, line_style, row_rect);
        }
    }
};

test "diff viewer renders hunks, removals, and additions" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 36, 6));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    var diff_st = DiffViewerState{};
    try (DiffViewer{
        .lines = &.{
            .{ .kind = .hunk, .text = "@@ -1,2 +1,2 @@" },
            .{ .kind = .removed, .old_line = 1, .text = "old_line" },
            .{ .kind = .added, .new_line = 1, .text = "new_line" },
        },
    }).renderStateful(&ui, buf.area, &diff_st);

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "- old_line") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "+ new_line") != null);
}
