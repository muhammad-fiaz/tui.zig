//! Structured aligned `KeyValueList` property summary widget.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const Block = block_mod.Block;

/// Key-value pair item displayed inside `KeyValueList`.
pub const KeyValueEntry = struct {
    key: []const u8,
    value: []const u8,
    key_style: ?Style = null,
    value_style: ?Style = null,
};

/// Aligned key/value inspector table.
pub const KeyValueList = struct {
    entries: []const KeyValueEntry = &.{},
    key_width: ?u16 = null,
    separator: []const u8 = ": ",
    block: ?Block = null,

    pub fn render(self: KeyValueList, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        var kw: u16 = self.key_width orelse 0;
        if (self.key_width == null) {
            for (self.entries) |e| kw = @max(kw, text_root.displayWidth(e.key));
        }
        kw = @min(kw, inner.width / 2);
        const sep_w = text_root.displayWidth(self.separator);

        for (self.entries, 0..) |e, i| {
            if (i >= inner.height) break;
            const gy = inner.top() + @as(u16, @intCast(i));
            const ks = e.key_style orelse ui.theme.muted.patch(.{ .bold = true });
            const vs = e.value_style orelse ui.theme.text;
            _ = ui.buffer.setStringClipped(inner.left(), gy, e.key, kw, ks, inner);
            const sep_x = inner.left() +| kw;
            const pos = ui.buffer.setStringClipped(sep_x, gy, self.separator, @min(sep_w, inner.right() -| sep_x), ui.theme.border, inner);
            _ = ui.buffer.setStringClipped(pos.x, gy, e.value, inner.right() -| pos.x, vs, inner);
        }
    }
};

test "key value list aligns keys and values cleanly" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 32, 3));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    try (KeyValueList{
        .entries = &.{ .{ .key = "Host", .value = "localhost" }, .{ .key = "Port", .value = "8080" } },
    }).render(&ui, buf.area);

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Host: localhost") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "Port: 8080") != null);
}
