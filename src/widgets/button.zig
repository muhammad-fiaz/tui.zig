//! Interactive `Button` widget supporting compact 1-row pills and 3-row bordered cards.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const event_root = @import("../event/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Alignment = core_root.Alignment;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const BorderSides = style_root.BorderSides;
pub const BorderType = style_root.BorderType;
pub const Block = block_mod.Block;
pub const Event = event_root.Event;

/// Visual emphasis variant for a `Button`.
pub const ButtonVariant = enum {
    primary,
    secondary,
    outline,
    ghost,
    danger,
    success,
};

/// Clickable / focusable button widget.
///
/// Renders either as a 3-row bordered box when `area.height >= 3 and !compact`,
/// or a single-row interactive badge `[ Label ]` when compact or `area.height < 3`.
pub const Button = struct {
    label: []const u8,
    focused: bool = false,
    disabled: bool = false,
    pressed: bool = false,
    variant: ButtonVariant = .secondary,
    border_type: BorderType = .rounded,
    compact: bool = false,
    alignment: Alignment = .center,
    icon: ?[]const u8 = null,
    shortcut: ?[]const u8 = null,
    style: ?Style = null,
    focused_style: ?Style = null,

    /// Returns `true` if `event` represents a mouse left-click inside `bounds`
    /// or `Enter` / `Space` while `focused`.
    pub fn isActivated(event: Event, bounds: Rect, focused: bool) bool {
        switch (event) {
            .mouse => |m| return m.isLeftClickInside(bounds),
            .key => |k| {
                if (!focused or k.kind == .release) return false;
                return k.code == .enter or k.isChar(' ');
            },
            else => return false,
        }
    }

    /// Respects `self.disabled` and `self.focused` when checking activation inside `bounds`.
    pub fn handleEvent(self: Button, event: Event, bounds: Rect) bool {
        if (self.disabled) return false;
        return isActivated(event, bounds, self.focused);
    }

    /// Computes recommended compact width in columns (`<= max_cap`).
    pub fn preferredWidth(self: Button) u16 {
        var w = text_root.displayWidth(self.label);
        if (self.icon) |ic| w +|= text_root.displayWidth(ic) + 1;
        if (self.shortcut) |sc| w +|= text_root.displayWidth(sc) + 3;
        return w +| 4;
    }

    /// Renders this button onto `ui` inside `area`.
    pub fn render(self: Button, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        const base_style = self.resolveBaseStyle(ui.theme);
        const eff_compact = self.compact or bounds.height < 3 or self.variant == .ghost;

        var content_buf: [256]u8 = undefined;
        const caption = self.formatCaption(&content_buf, eff_compact);

        if (eff_compact) {
            ui.buffer.fill(bounds, " ", base_style);
            const cap_w = text_root.displayWidth(caption);
            const draw_w = @min(cap_w, bounds.width);
            const x: u16 = switch (self.alignment) {
                .left => bounds.left(),
                .center => bounds.left() + (bounds.width - draw_w) / 2,
                .right => bounds.right() - draw_w,
            };
            const y = bounds.top() + bounds.height / 2;
            _ = ui.buffer.setStringClipped(x, y, caption, draw_w, base_style, bounds);
            return;
        }

        const border_s: Style = if (self.disabled)
            ui.theme.disabled
        else if (self.focused)
            ui.theme.border_focused
        else switch (self.variant) {
            .primary => ui.theme.accent,
            .danger => ui.theme.err,
            .success => ui.theme.success,
            else => ui.theme.border,
        };

        const blk = Block{
            .borders = BorderSides.all,
            .border_type = self.border_type,
            .border_style = border_s,
            .style = base_style,
            .fill_background = true,
            .focused = self.focused,
        };
        try blk.render(ui, bounds);
        const inner = blk.inner(bounds);
        if (inner.isEmpty()) return;

        const cap_w = text_root.displayWidth(caption);
        const draw_w = @min(cap_w, inner.width);
        const x: u16 = switch (self.alignment) {
            .left => inner.left(),
            .center => inner.left() + (inner.width - draw_w) / 2,
            .right => inner.right() - draw_w,
        };
        const y = inner.top() + inner.height / 2;
        _ = ui.buffer.setStringClipped(x, y, caption, draw_w, base_style, inner);
    }

    fn resolveBaseStyle(self: Button, theme: *const style_root.Theme) Style {
        if (self.disabled) return theme.disabled;
        if (self.focused) {
            if (self.focused_style) |fs| return fs;
            return switch (self.variant) {
                .danger => theme.err.patch(.{ .reverse = true, .bold = true }),
                .success => theme.success.patch(.{ .reverse = true, .bold = true }),
                else => theme.button_focused,
            };
        }
        if (self.style) |s| return s;
        var s = switch (self.variant) {
            .primary => theme.accent.patch(.{ .bold = true }),
            .danger => theme.err.patch(.{ .bold = true }),
            .success => theme.success.patch(.{ .bold = true }),
            .outline, .ghost => theme.text,
            .secondary => theme.button,
        };
        if (self.pressed) s = s.patch(.{ .reverse = true });
        return s;
    }

    fn formatCaption(self: Button, out: *[256]u8, compact_mode: bool) []const u8 {
        var fbs = std.Io.Writer.fixed(out);
        if (compact_mode) {
            fbs.writeAll(if (self.focused) "[ " else "  ") catch return self.label;
        }
        if (self.icon) |ic| {
            fbs.writeAll(ic) catch {};
            fbs.writeByte(' ') catch {};
        }
        fbs.writeAll(self.label) catch {};
        if (self.shortcut) |sc| {
            fbs.print(" ({s})", .{sc}) catch {};
        }
        if (compact_mode) {
            fbs.writeAll(if (self.focused) " ]" else "  ") catch {};
        }
        return fbs.buffered();
    }
};

test "button renders compact and bordered modes and checks activation" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 20, 4));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    const btn = Button{ .label = "Save", .focused = true, .variant = .primary };
    try ui.renderWidget(btn, Rect.init(0, 0, 14, 3));

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Save") != null);

    try testing.expect(Button.isActivated(.{ .key = .{ .code = .enter } }, Rect.init(0, 0, 14, 3), true));
    try testing.expect(Button.isActivated(.{ .mouse = .{ .kind = .down, .button = .left, .x = 3, .y = 1 } }, Rect.init(0, 0, 14, 3), false));
    try testing.expect(!Button.isActivated(.{ .mouse = .{ .kind = .down, .button = .left, .x = 18, .y = 1 } }, Rect.init(0, 0, 14, 3), true));
}
