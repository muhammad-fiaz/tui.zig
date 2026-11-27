//! Multi-step progress `Stepper` pipeline indicator (`✓ Build ── ● Test ── ○ Deploy`).

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Direction = core_root.Direction;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const Block = block_mod.Block;

/// State of a stage in `Stepper`.
pub const StepStatus = enum {
    pending,
    active,
    completed,
    err,
};

/// Stage item inside `Stepper`.
pub const StepItem = struct {
    label: []const u8,
    description: ?[]const u8 = null,
    status: StepStatus = .pending,
};

/// Horizontal or vertical step progress tracker.
pub const Stepper = struct {
    steps: []const StepItem = &.{},
    direction: Direction = .horizontal,
    block: ?Block = null,

    pub fn render(self: Stepper, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty() or self.steps.len == 0) return;

        const StepVisual = struct { glyph: []const u8, style: Style };
        switch (self.direction) {
            .horizontal => {
                var x = inner.left();
                const y = inner.top() + inner.height / 2;
                for (self.steps, 0..) |st, i| {
                    if (x >= inner.right()) break;
                    if (i > 0) {
                        x = ui.buffer.setStringClipped(x, y, " ── ", inner.right() -| x, ui.theme.border, inner).x;
                        if (x >= inner.right()) break;
                    }
                    const info: StepVisual = switch (st.status) {
                        .completed => .{ .glyph = "✓ ", .style = ui.theme.success },
                        .active => .{ .glyph = "● ", .style = ui.theme.accent.patch(.{ .bold = true }) },
                        .err => .{ .glyph = "✖ ", .style = ui.theme.err.patch(.{ .bold = true }) },
                        .pending => .{ .glyph = "○ ", .style = ui.theme.muted },
                    };
                    x = ui.buffer.setStringClipped(x, y, info.glyph, inner.right() -| x, info.style, inner).x;
                    x = ui.buffer.setStringClipped(x, y, st.label, inner.right() -| x, info.style, inner).x;
                }
            },
            .vertical => {
                var y = inner.top();
                for (self.steps, 0..) |st, i| {
                    if (y >= inner.bottom()) break;
                    const info: StepVisual = switch (st.status) {
                        .completed => .{ .glyph = "✓ ", .style = ui.theme.success },
                        .active => .{ .glyph = "● ", .style = ui.theme.accent.patch(.{ .bold = true }) },
                        .err => .{ .glyph = "✖ ", .style = ui.theme.err.patch(.{ .bold = true }) },
                        .pending => .{ .glyph = "○ ", .style = ui.theme.muted },
                    };
                    var x = ui.buffer.setStringClipped(inner.left(), y, info.glyph, inner.width, info.style, inner).x;
                    x = ui.buffer.setStringClipped(x, y, st.label, inner.right() -| x, info.style, inner).x;
                    if (st.description) |desc| {
                        x = ui.buffer.setStringClipped(x, y, " — ", inner.right() -| x, ui.theme.muted, inner).x;
                        _ = ui.buffer.setStringClipped(x, y, desc, inner.right() -| x, ui.theme.muted, inner);
                    }
                    y += 1;
                    if (i + 1 < self.steps.len and y < inner.bottom()) {
                        _ = ui.buffer.setStringClipped(inner.left(), y, "│", 1, ui.theme.border, inner);
                        y += 1;
                    }
                }
            },
        }
    }
};

test "stepper renders horizontal pipeline statuses" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 40, 2));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    try (Stepper{
        .steps = &.{
            .{ .label = "Build", .status = .completed },
            .{ .label = "Deploy", .status = .active },
        },
    }).render(&ui, buf.area);

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Build") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "Deploy") != null);
}
