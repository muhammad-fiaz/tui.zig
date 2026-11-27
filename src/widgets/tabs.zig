//! Horizontal `Tabs` bar widget with customizable separators, padding, and keyboard/mouse switching.

const std = @import("std");
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
pub const Line = text_root.Line;
pub const Event = event_root.Event;

/// Horizontal tab navigation bar.
pub const Tabs = struct {
    titles: []const []const u8 = &.{},
    lines: []const Line = &.{},
    selected: usize = 0,
    divider: []const u8 = " │ ",
    padding_left: []const u8 = " ",
    padding_right: []const u8 = " ",
    block: ?Block = null,
    style: ?Style = null,
    highlight_style: ?Style = null,
    focused: bool = true,

    /// Advances `selected` on Left/Right arrows, Tab/BackTab, or direct mouse click over a tab.
    /// Returns `true` when `selected.*` changed.
    pub fn handleEvent(
        self: Tabs,
        selected: *usize,
        event: Event,
        area: Rect,
        focused: bool,
    ) bool {
        const count = if (self.lines.len > 0) self.lines.len else self.titles.len;
        if (count == 0) return false;

        switch (event) {
            .mouse => |m| {
                const inner = if (self.block) |b| b.inner(area) else area;
                if (!m.isLeftClickInside(inner)) return false;
                var x = inner.left();
                const div_w = text_root.displayWidth(self.divider);
                const pl_w = text_root.displayWidth(self.padding_left);
                const pr_w = text_root.displayWidth(self.padding_right);

                for (0..count) |i| {
                    const tw: u16 = if (self.lines.len > 0)
                        self.lines[i].width()
                    else
                        text_root.displayWidth(self.titles[i]);
                    const full_w = pl_w +| tw +| pr_w;
                    if (m.x >= x and m.x < x +| full_w) {
                        if (selected.* != i) {
                            selected.* = i;
                            return true;
                        }
                        return false;
                    }
                    x +|= full_w +| div_w;
                }
                return false;
            },
            .key => |k| {
                if (!focused or k.kind == .release) return false;
                switch (k.code) {
                    .right => {
                        selected.* = (selected.* + 1) % count;
                        return true;
                    },
                    .left => {
                        selected.* = if (selected.* == 0) count - 1 else selected.* - 1;
                        return true;
                    },
                    else => return false,
                }
            },
            else => return false,
        }
    }

    /// Renders tabs strip into `ui` within `area`.
    pub fn render(self: Tabs, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        const base_style = self.style orelse ui.theme.muted;
        const active_style = self.highlight_style orelse if (self.focused)
            ui.theme.accent.patch(.{ .bold = true, .underline = true })
        else
            ui.theme.text.patch(.{ .bold = true });

        if (self.style != null) {
            ui.buffer.setStyle(inner, base_style);
        }

        const count = if (self.lines.len > 0) self.lines.len else self.titles.len;
        if (count == 0) return;

        var x = inner.left();
        const y = inner.top() + inner.height / 2;

        for (0..count) |i| {
            if (x >= inner.right()) break;
            if (i > 0 and self.divider.len > 0) {
                x = ui.buffer.setStringClipped(x, y, self.divider, inner.right() - x, ui.theme.border, inner).x;
                if (x >= inner.right()) break;
            }

            const tab_s = if (i == self.selected) active_style else base_style;
            x = ui.buffer.setStringClipped(x, y, self.padding_left, inner.right() - x, tab_s, inner).x;
            if (x >= inner.right()) break;

            if (self.lines.len > 0) {
                const lw = @min(self.lines[i].width(), inner.right() - x);
                self.lines[i].render(ui.buffer, Rect.init(x, y, lw, 1), .left, tab_s);
                x += lw;
            } else {
                x = ui.buffer.setStringClipped(x, y, self.titles[i], inner.right() - x, tab_s, inner).x;
            }
            if (x >= inner.right()) break;
            x = ui.buffer.setStringClipped(x, y, self.padding_right, inner.right() - x, tab_s, inner).x;
        }
    }
};

test "tabs render selection and switch on left click and arrow keys" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 30, 3));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    var sel: usize = 0;
    const tabs = Tabs{ .titles = &.{ "Overview", "Logs", "Metrics" }, .selected = sel };
    try testing.expect(tabs.handleEvent(&sel, .{ .key = .{ .code = .right } }, buf.area, true));
    try testing.expectEqual(@as(usize, 1), sel);

    try ui.renderWidget(Tabs{ .titles = tabs.titles, .selected = sel }, Rect.init(0, 0, 30, 1));
    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Overview  │") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "Logs") != null);
}
