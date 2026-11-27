//! Interactive `Pagination` bar widget (`◀ Prev  1  [2]  3  Next ▶`) with mouse & keyboard support.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const event_root = @import("../event/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Ui = core_root.Ui;
pub const Block = block_mod.Block;
pub const Event = event_root.Event;

/// Interactive page control bar (`◀ Prev  [1]  2  3  Next ▶`) with sliding window, mouse, and keyboard navigation.
pub const Pagination = struct {
    total_pages: usize = 1,
    max_visible_pages: usize = 7,
    focused: bool = true,
    prev_label: []const u8 = "◀ Prev",
    next_label: []const u8 = "Next ▶",
    block: ?Block = null,

    fn pageWindow(total: usize, current: usize, max_btns: usize) struct { start: usize, end: usize } {
        const cap = @max(@as(usize, 1), @min(total, max_btns));
        if (total <= cap) return .{ .start = 1, .end = total };
        const half = cap / 2;
        var start = if (current > half) current - half else 1;
        var end = start + cap - 1;
        if (end > total) {
            end = total;
            start = end - cap + 1;
        }
        return .{ .start = start, .end = end };
    }

    pub fn handleEvent(self: Pagination, page: *usize, event: Event, area: Rect) bool {
        const total = @max(@as(usize, 1), self.total_pages);
        page.* = std.math.clamp(page.*, 1, total);

        switch (event) {
            .mouse => |m| {
                const inner = if (self.block) |b| b.inner(area) else area;
                if (!m.isLeftClickInside(inner)) return false;
                const y = inner.top() + inner.height / 2;
                if (m.y != y) return false;

                var x = inner.left();
                const prev_w = text_root.displayWidth(self.prev_label) +| 2;
                if (m.x >= x and m.x < x +| prev_w) {
                    if (page.* > 1) {
                        page.* -= 1;
                        return true;
                    }
                    return false;
                }
                x +|= prev_w + 1;

                const win = pageWindow(total, page.*, self.max_visible_pages);
                var num_buf: [24]u8 = undefined;
                if (win.start > 1) {
                    x +|= 2; // "… "
                }
                var p = win.start;
                while (p <= win.end) : (p += 1) {
                    const txt = std.fmt.bufPrint(&num_buf, " {d} ", .{p}) catch "";
                    const bw = text_root.displayWidth(txt);
                    if (m.x >= x and m.x < x +| bw) {
                        if (page.* != p) {
                            page.* = p;
                            return true;
                        }
                        return false;
                    }
                    x +|= bw + 1;
                }
                if (win.end < total) {
                    const sum_s = std.fmt.bufPrint(&num_buf, "… {d} ", .{total}) catch "";
                    x +|= text_root.displayWidth(sum_s);
                }
                const next_w = text_root.displayWidth(self.next_label) +| 2;
                if (m.x >= x and m.x < x +| next_w and page.* < total) {
                    page.* += 1;
                    return true;
                }
                return false;
            },
            .key => |k| {
                if (!self.focused or k.kind == .release) return false;
                switch (k.code) {
                    .left => {
                        if (page.* > 1) {
                            page.* -= 1;
                            return true;
                        }
                        return false;
                    },
                    .right => {
                        if (page.* < total) {
                            page.* += 1;
                            return true;
                        }
                        return false;
                    },
                    .home => {
                        page.* = 1;
                        return true;
                    },
                    .end => {
                        page.* = total;
                        return true;
                    },
                    else => return false,
                }
            },
            else => return false,
        }
    }

    pub fn renderStateful(self: Pagination, ui: *Ui, area: Rect, page: *usize) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        const total = @max(@as(usize, 1), self.total_pages);
        page.* = std.math.clamp(page.*, 1, total);

        const y = inner.top() + inner.height / 2;
        var x = inner.left();
        const prev_s = if (page.* <= 1) ui.theme.disabled else ui.theme.button;
        x = ui.buffer.setStringClipped(x, y, " ", inner.right() -| x, prev_s, inner).x;
        x = ui.buffer.setStringClipped(x, y, self.prev_label, inner.right() -| x, prev_s, inner).x;
        x = ui.buffer.setStringClipped(x, y, " ", inner.right() -| x, prev_s, inner).x;
        x +|= 1;

        const win = pageWindow(total, page.*, self.max_visible_pages);
        var num_buf: [24]u8 = undefined;
        if (win.start > 1 and x < inner.right()) {
            x = ui.buffer.setStringClipped(x, y, "… ", inner.right() -| x, ui.theme.muted, inner).x;
        }
        var p = win.start;
        while (p <= win.end and x < inner.right()) : (p += 1) {
            const txt = std.fmt.bufPrint(&num_buf, " {d} ", .{p}) catch "";
            const bs = if (p == page.*)
                (if (self.focused) ui.theme.accent.patch(.{ .reverse = true, .bold = true }) else ui.theme.selection)
            else
                ui.theme.text;
            x = ui.buffer.setStringClipped(x, y, txt, inner.right() -| x, bs, inner).x;
            x +|= 1;
        }
        if (win.end < total and x < inner.right()) {
            const sum_s = std.fmt.bufPrint(&num_buf, "… {d} ", .{total}) catch "";
            x = ui.buffer.setStringClipped(x, y, sum_s, inner.right() -| x, ui.theme.muted, inner).x;
        }
        if (x < inner.right()) {
            const next_s = if (page.* >= total) ui.theme.disabled else ui.theme.button;
            x = ui.buffer.setStringClipped(x, y, " ", inner.right() -| x, next_s, inner).x;
            x = ui.buffer.setStringClipped(x, y, self.next_label, inner.right() -| x, next_s, inner).x;
            _ = ui.buffer.setStringClipped(x, y, " ", inner.right() -| x, next_s, inner);
        }
    }
};

test "pagination navigates pages on key, sliding window, and renders buttons" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 48, 1));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    var page: usize = 9;
    const pager = Pagination{ .total_pages = 12 };
    try pager.renderStateful(&ui, buf.area, &page);
    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, " 9 ") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "12") != null);

    try testing.expect(pager.handleEvent(&page, .{ .key = .{ .code = .right } }, buf.area));
    try testing.expectEqual(@as(usize, 10), page);
}
