//! Interactive `Checkbox` widget supporting boolean and tri-state toggles.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const event_root = @import("../event/root.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const CheckboxSet = style_root.CheckboxSet;
pub const symbols = style_root.symbols;
pub const Event = event_root.Event;

/// Tri-state checkbox indicator.
pub const CheckState = enum {
    unchecked,
    checked,
    indeterminate,
};

/// Single-row toggleable checkbox with label.
pub const Checkbox = struct {
    label: []const u8,
    checked: bool = false,
    /// Optional explicit tri-state overriding `checked` when non-null.
    tristate: ?CheckState = null,
    focused: bool = false,
    disabled: bool = false,
    symbols_set: CheckboxSet = symbols.checkbox.unicode,
    style: ?Style = null,
    box_style: ?Style = null,
    focused_style: ?Style = null,

    /// Handles Space / Enter / left click inside `bounds` and toggles `*checked`.
    /// Returns `true` when state changed.
    pub fn handleEvent(checked: *bool, event: Event, bounds: Rect, focused: bool) bool {
        const triggered = switch (event) {
            .mouse => |m| m.isLeftClickInside(bounds),
            .key => |k| focused and k.kind != .release and (k.code == .enter or k.isChar(' ')),
            else => false,
        };
        if (triggered) {
            checked.* = !checked.*;
            return true;
        }
        return false;
    }

    /// Renders checkbox glyph + label into `ui` within `area`.
    pub fn render(self: Checkbox, ui: *Ui, area: Rect) void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        const state: CheckState = self.tristate orelse if (self.checked) .checked else .unchecked;
        const indicator = switch (state) {
            .unchecked => self.symbols_set.unchecked,
            .checked => self.symbols_set.checked,
            .indeterminate => self.symbols_set.indeterminate,
        };

        const row_style: Style = if (self.disabled)
            ui.theme.disabled
        else if (self.focused)
            self.focused_style orelse ui.theme.accent.patch(.{ .bold = true })
        else
            self.style orelse ui.theme.text;

        const glyph_style: Style = if (self.disabled)
            ui.theme.disabled
        else if (self.box_style) |bs|
            bs
        else if (state != .unchecked)
            ui.theme.success.patch(.{ .bold = true })
        else if (self.focused)
            ui.theme.accent
        else
            ui.theme.muted;

        const y = bounds.top();
        var pos = ui.buffer.setStringClipped(bounds.left(), y, indicator, bounds.width, glyph_style, bounds);
        if (self.label.len > 0 and pos.x < bounds.right()) {
            pos = ui.buffer.setStringClipped(pos.x, y, " ", 1, row_style, bounds);
            if (pos.x < bounds.right()) {
                _ = ui.buffer.setStringClipped(pos.x, y, self.label, bounds.right() - pos.x, row_style, bounds);
            }
        }
    }
};

test "checkbox renders state glyphs and toggles on click or space" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 24, 2));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    var checked = false;
    try ui.renderWidget(Checkbox{ .label = "Enable TLS", .checked = checked, .focused = true }, Rect.init(0, 0, 24, 1));

    const bounds = Rect.init(0, 0, 24, 1);
    try testing.expect(Checkbox.handleEvent(&checked, .{ .key = .{ .code = .{ .char = ' ' } } }, bounds, true));
    try testing.expect(checked);

    try ui.renderWidget(Checkbox{ .label = "Enable TLS", .checked = checked }, Rect.init(0, 1, 24, 1));
    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "[ ] Enable TLS") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "[✓] Enable TLS") != null);
}
