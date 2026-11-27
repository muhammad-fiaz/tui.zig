//! Floating overlays and modal dialogs: `Popup`, `Dialog`, `ConfirmDialog`, and `Toast`.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const event_root = @import("../event/root.zig");
const clear_mod = @import("clear.zig");
const block_mod = @import("block.zig");
const paragraph_mod = @import("paragraph.zig");
const button_mod = @import("button.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Alignment = core_root.Alignment;
pub const Padding = core_root.Padding;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const Clear = clear_mod.Clear;
pub const Block = block_mod.Block;
pub const Paragraph = paragraph_mod.Paragraph;
pub const Button = button_mod.Button;
pub const Event = event_root.Event;

/// Corner or center screen anchor for floating overlays and toasts.
pub const OverlayAnchor = enum {
    center,
    top_left,
    top_right,
    bottom_left,
    bottom_right,
};

/// Modal / floating container calculating centered or anchored screen rects, clearing backdrop,
/// optional dimming behind overlay, and painting bordered shadowed frames.
pub const Popup = struct {
    title: ?[]const u8 = null,
    footer_hint: ?[]const u8 = null,
    /// Fixed width (`null` derives from `width_percent`).
    width: ?u16 = null,
    /// Fixed height (`null` derives from `height_percent`).
    height: ?u16 = null,
    width_percent: u16 = 60,
    height_percent: u16 = 45,
    anchor: OverlayAnchor = .center,
    dim_backdrop: bool = true,
    shadow: bool = true,
    padding: Padding = .{ .left = 1, .right = 1, .top = 0, .bottom = 0 },
    block: ?Block = null,

    /// Computes the centered or anchored popup `Rect` inside `screen`.
    pub fn computeRect(self: Popup, screen: Rect) Rect {
        if (screen.isEmpty()) return Rect.zero;
        const w = @min(screen.width, self.width orelse @max(@as(u16, 12), @as(u16, @intCast((@as(u32, screen.width) * self.width_percent) / 100))));
        const h = @min(screen.height, self.height orelse @max(@as(u16, 5), @as(u16, @intCast((@as(u32, screen.height) * self.height_percent) / 100))));
        return switch (self.anchor) {
            .center => Rect.init(
                screen.left() + (screen.width - w) / 2,
                screen.top() + (screen.height - h) / 2,
                w,
                h,
            ),
            .top_left => Rect.init(screen.left() +| 1, screen.top() +| 1, w, h),
            .top_right => Rect.init(screen.right() -| w -| 1, screen.top() +| 1, w, h),
            .bottom_left => Rect.init(screen.left() +| 1, screen.bottom() -| h -| 1, w, h),
            .bottom_right => Rect.init(screen.right() -| w -| 1, screen.bottom() -| h -| 1, w, h),
        };
    }

    /// Renders backdrop clear + bordered frame and invokes `draw_fn(ctx, *Ui)` inside interior.
    pub fn renderWith(self: Popup, ui: *Ui, screen: Rect, ctx: anytype, comptime draw_fn: anytype) !void {
        const bounds = screen.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        if (self.dim_backdrop) {
            ui.buffer.setStyle(bounds, .{ .dim = true });
        }

        const box = self.computeRect(bounds);
        if (box.isEmpty()) return;

        (Clear{ .style = ui.theme.surface }).renderToBuffer(ui.buffer, box);
        var blk = self.block orelse Block{
            .title = self.title,
            .title_alignment = .center,
            .title_bottom = self.footer_hint,
            .title_bottom_alignment = .center,
            .border_type = .rounded,
            .focused = true,
            .style = ui.theme.surface,
            .fill_background = true,
            .padding = self.padding,
            .shadow = .{ .enabled = self.shadow },
        };
        if (blk.title == null) blk.title = self.title;
        if (blk.title_bottom == null) blk.title_bottom = self.footer_hint;
        blk.shadow.enabled = self.shadow;

        var full_ui = ui.*;
        full_ui.area = bounds;
        try blk.render(&full_ui, box);
        const inner = blk.inner(box);
        if (inner.isEmpty()) return;

        var inner_ui = full_ui.region(inner);
        const ret_err = @typeInfo(@typeInfo(@TypeOf(draw_fn)).@"fn".return_type.?) == .error_union;
        if (ret_err) {
            try draw_fn(ctx, &inner_ui);
        } else {
            draw_fn(ctx, &inner_ui);
        }
    }
};

/// Result of user interaction with `ConfirmDialog`.
pub const ConfirmOutcome = enum {
    pending,
    confirmed,
    cancelled,
};

/// Focus state for two-action modal dialogs (`Confirm` vs `Cancel`).
pub const ConfirmState = struct {
    open: bool = true,
    focus_confirm: bool = true,

    /// Handles Left/Right/Tab/Enter/Esc/y/n keys and returns `ConfirmOutcome`.
    pub fn handleEvent(self: *ConfirmState, event: Event) ConfirmOutcome {
        return self.handleEventImpl(event, null, null, null, false);
    }

    /// Handles keyboard actions, mouse button clicks, and optional outside backdrop dismissal inside `screen`.
    pub fn handleEventAt(self: *ConfirmState, event: Event, screen: Rect, dialog: ConfirmDialog) ConfirmOutcome {
        const rects = dialog.layout(screen);
        return self.handleEventImpl(event, rects.box, rects.confirm_rect, rects.cancel_rect, dialog.backdrop_dismiss);
    }

    fn handleEventImpl(
        self: *ConfirmState,
        event: Event,
        box_rect: ?Rect,
        confirm_rect: ?Rect,
        cancel_rect: ?Rect,
        backdrop_dismiss: bool,
    ) ConfirmOutcome {
        if (!self.open) return .pending;
        switch (event) {
            .mouse => |m| {
                if (m.kind == .moved or m.kind == .drag) {
                    if (confirm_rect) |cr| {
                        if (m.isInside(cr)) self.focus_confirm = true;
                    }
                    if (cancel_rect) |xr| {
                        if (m.isInside(xr)) self.focus_confirm = false;
                    }
                    return .pending;
                }
                if (confirm_rect) |cr| {
                    if (m.isLeftClickInside(cr)) {
                        self.focus_confirm = true;
                        self.open = false;
                        return .confirmed;
                    }
                }
                if (cancel_rect) |xr| {
                    if (m.isLeftClickInside(xr)) {
                        self.focus_confirm = false;
                        self.open = false;
                        return .cancelled;
                    }
                }
                if (backdrop_dismiss and m.kind == .down and m.button == .left) {
                    if (box_rect) |bx| {
                        if (!m.isInside(bx)) {
                            self.open = false;
                            return .cancelled;
                        }
                    }
                }
                return .pending;
            },
            .key => |k| {
                if (k.kind == .release) return .pending;
                switch (k.code) {
                    .escape => {
                        self.open = false;
                        return .cancelled;
                    },
                    .left, .right, .tab, .back_tab => {
                        self.focus_confirm = !self.focus_confirm;
                        return .pending;
                    },
                    .enter => {
                        self.open = false;
                        return if (self.focus_confirm) .confirmed else .cancelled;
                    },
                    .char => |cp| {
                        if (cp == 'y' or cp == 'Y') {
                            self.open = false;
                            return .confirmed;
                        }
                        if (cp == 'n' or cp == 'N') {
                            self.open = false;
                            return .cancelled;
                        }
                        if (cp == ' ') {
                            self.open = false;
                            return if (self.focus_confirm) .confirmed else .cancelled;
                        }
                        return .pending;
                    },
                    else => return .pending,
                }
            },
            else => return .pending,
        }
    }
};

/// Modal confirmation dialog with body message and Confirm / Cancel buttons.
pub const ConfirmDialog = struct {
    title: []const u8 = "Confirm",
    message: []const u8,
    confirm_label: []const u8 = "Confirm",
    cancel_label: []const u8 = "Cancel",
    destructive: bool = false,
    backdrop_dismiss: bool = false,
    width: ?u16 = 44,
    height: ?u16 = 8,

    /// Computes exact modal frame and Confirm / Cancel button hit-test rectangles inside `screen`.
    pub fn layout(self: ConfirmDialog, screen: Rect) struct {
        box: Rect,
        confirm_rect: Rect,
        cancel_rect: Rect,
    } {
        const pop = Popup{
            .title = self.title,
            .footer_hint = "Enter select • Esc cancel",
            .width = self.width,
            .height = self.height,
        };
        const box = pop.computeRect(screen);
        const blk = Block{
            .title = pop.title,
            .title_alignment = .center,
            .title_bottom = pop.footer_hint,
            .title_bottom_alignment = .center,
            .border_type = .rounded,
            .padding = pop.padding,
        };
        const body = blk.inner(box);
        if (body.isEmpty()) return .{ .box = box, .confirm_rect = Rect.zero, .cancel_rect = Rect.zero };
        const split = core_root.layout.splitFixed(2, body, .{ .{ .fill = 1 }, .{ .length = 1 } }, .{ .direction = .vertical });
        const btns = core_root.layout.splitFixed(2, split[1], .{ .{ .fill = 1 }, .{ .fill = 1 } }, .{ .direction = .horizontal, .spacing = .{ .space = 2 } });
        return .{ .box = box, .confirm_rect = btns[0], .cancel_rect = btns[1] };
    }

    /// Renders centered modal dialog synchronized with `state`.
    pub fn renderStateful(self: ConfirmDialog, ui: *Ui, area: Rect, state: *ConfirmState) !void {
        if (!state.open) return;
        const pop = Popup{
            .title = self.title,
            .footer_hint = "Enter select • Esc cancel",
            .width = self.width,
            .height = self.height,
        };
        const Ctx = struct {
            dlg: ConfirmDialog,
            st: *ConfirmState,
        };
        try pop.renderWith(ui, area, Ctx{ .dlg = self, .st = state }, struct {
            fn draw(ctx: Ctx, body: *Ui) !void {
                const split = body.rows(2, .{ .{ .fill = 1 }, .{ .length = 1 } }, .{});
                var msg_ui = split[0];
                try msg_ui.renderWidget(Paragraph.fromSlice(ctx.dlg.message).wrapped(.word), msg_ui.area);

                var btn_ui = split[1];
                const btns = btn_ui.cols(2, .{ .{ .fill = 1 }, .{ .fill = 1 } }, .{ .spacing = .{ .space = 2 } });
                var left_ui = btns[0];
                var right_ui = btns[1];
                try left_ui.renderWidget(Button{
                    .label = ctx.dlg.confirm_label,
                    .focused = ctx.st.focus_confirm,
                    .compact = true,
                    .variant = if (ctx.dlg.destructive) .danger else .primary,
                }, left_ui.area);
                try right_ui.renderWidget(Button{
                    .label = ctx.dlg.cancel_label,
                    .focused = !ctx.st.focus_confirm,
                    .compact = true,
                    .variant = .secondary,
                }, right_ui.area);
            }
        }.draw);
    }
};

/// Severity styling level for non-blocking `Toast` notifications.
pub const ToastLevel = enum {
    info,
    success,
    warning,
    err,
};

/// Non-blocking floating notification banner positioned at any `OverlayAnchor`.
/// Automatically word-wraps long or multi-line messages and clamps geometry & drop shadow
/// strictly inside `screen` so neither `xflow` (horizontal) nor `yflow` (vertical) overflows occur.
pub const Toast = struct {
    title: ?[]const u8 = null,
    message: []const u8,
    level: ToastLevel = .info,
    anchor: OverlayAnchor = .bottom_right,
    max_width: u16 = 44,
    max_height: u16 = 8,
    wrap: bool = true,
    shadow: bool = true,

    fn resolvedPrefix(level: ToastLevel) []const u8 {
        return switch (level) {
            .info => "ℹ ",
            .success => "✓ ",
            .warning => "⚠ ",
            .err => "✖ ",
        };
    }

    fn countWrappedLines(message: []const u8, line0_w: u16, cont_w: u16, wrap: bool) u16 {
        if (line0_w == 0 or cont_w == 0) return 1;
        if (!wrap) return 1;
        var total: u16 = 0;
        var para_it = text_root.splitLinesIter(message);
        while (para_it.next()) |para| {
            const avail_w = if (total == 0) line0_w else cont_w;
            if (para.len == 0) {
                total +|= 1;
                continue;
            }
            var wit = text_root.WrapIterator.init(para, avail_w, .{ .mode = .word });
            var em: u16 = 0;
            while (wit.next()) |_| {
                em +|= 1;
                if (total +| em >= 32) break;
            }
            total +|= @max(@as(u16, 1), em);
        }
        return @max(@as(u16, 1), total);
    }

    /// Computes exact outer `Rect` strictly inside `screen`, preventing any horizontal (`xflow`) or vertical (`yflow`) overflow.
    pub fn computeRect(self: Toast, screen: Rect) Rect {
        if (screen.width < 10 or screen.height < 3) return Rect.zero;

        const margin_x: u16 = if (self.shadow and screen.width >= 16) 1 else 0;
        const margin_y: u16 = if (self.shadow and screen.height >= 5) 1 else 0;
        const max_box_w = screen.width -| (margin_x * 2);
        const max_box_h = screen.height -| (margin_y * 2);
        if (max_box_w < 8 or max_box_h < 3) return Rect.zero;

        const prefix_w = text_root.displayWidth(resolvedPrefix(self.level));
        // Longest single logical line determines ideal unwrapped width.
        var longest_line_w: u16 = 0;
        var line_it = text_root.splitLinesIter(self.message);
        while (line_it.next()) |ln| {
            longest_line_w = @max(longest_line_w, text_root.displayWidth(ln));
        }
        const title_w: u16 = if (self.title) |t| text_root.displayWidth(t) else 0;
        const needed_w = @max(longest_line_w +| 4 +| prefix_w, title_w +| 4);
        const w = @min(max_box_w, @max(@as(u16, 18), @min(self.max_width, needed_w)));

        const inner_w = w -| 4; // 2 border + 2 padding
        const line0_w = @max(@as(u16, 1), inner_w -| prefix_w);
        const cont_w = @max(@as(u16, 1), inner_w);
        const n_lines = countWrappedLines(self.message, line0_w, cont_w, self.wrap);

        const cap_h = @min(max_box_h, @max(@as(u16, 3), self.max_height));
        const h = @min(cap_h, @max(@as(u16, 3), n_lines +| 2));

        // Shadow offset (x+2, y+1): ensure bottom_right / right anchors keep shadow inside screen too.
        const right_lim = screen.right() -| (if (self.shadow) @min(@as(u16, 2), screen.width -| w) else 0);
        const bot_lim = screen.bottom() -| (if (self.shadow) @min(@as(u16, 1), screen.height -| h) else 0);

        const x: u16 = switch (self.anchor) {
            .center => screen.left() + (screen.width -| w) / 2,
            .top_left, .bottom_left => @min(screen.left() +| margin_x, right_lim -| w),
            .top_right, .bottom_right => @max(screen.left(), right_lim -| w),
        };
        const y: u16 = switch (self.anchor) {
            .center => screen.top() + (screen.height -| h) / 2,
            .top_left, .top_right => @min(screen.top() +| margin_y, bot_lim -| h),
            .bottom_left, .bottom_right => @max(screen.top(), bot_lim -| h),
        };
        return Rect.init(x, y, w, h).intersection(screen);
    }

    /// Renders floating wrapped toast overlay safely clamped inside `screen`.
    pub fn render(self: Toast, ui: *Ui, screen: Rect) !void {
        const bounds = screen.intersection(ui.buffer.area);
        const box = self.computeRect(bounds);
        if (box.isEmpty() or box.width < 8 or box.height < 3) return;

        const accent_s = switch (self.level) {
            .info => ui.theme.info,
            .success => ui.theme.success,
            .warning => ui.theme.warning,
            .err => ui.theme.err,
        };
        const prefix = resolvedPrefix(self.level);

        (Clear{ .style = ui.theme.surface }).renderToBuffer(ui.buffer, box);
        const blk = Block{
            .title = self.title,
            .border_type = .rounded,
            .border_style = accent_s,
            .style = ui.theme.surface,
            .fill_background = true,
            .padding = Padding.symmetric(1, 0),
            .shadow = .{ .enabled = self.shadow },
        };
        var full_ui = ui.*;
        full_ui.area = bounds;
        try blk.render(&full_ui, box);
        const inner = blk.inner(box);
        if (inner.isEmpty()) return;

        const pos0 = full_ui.buffer.setStringClipped(inner.left(), inner.top(), prefix, inner.width, accent_s.patch(.{ .bold = true }), inner);
        const first_line_w = inner.right() -| pos0.x;

        if (!self.wrap) {
            _ = full_ui.buffer.setStringClipped(pos0.x, inner.top(), self.message, first_line_w, ui.theme.text, inner);
            return;
        }

        var row_idx: u16 = 0;
        var para_it = text_root.splitLinesIter(self.message);
        while (para_it.next()) |para| {
            if (row_idx >= inner.height) break;
            if (para.len == 0) {
                row_idx += 1;
                continue;
            }
            const first_avail = if (row_idx == 0) first_line_w else inner.width;
            var wit = text_root.WrapIterator.init(para, @max(@as(u16, 1), first_avail), .{ .mode = .word });
            while (wit.next()) |seg| {
                if (row_idx >= inner.height) break;
                const draw_x = if (row_idx == 0) pos0.x else inner.left();
                const draw_w = inner.right() -| draw_x;
                _ = full_ui.buffer.setStringClipped(draw_x, inner.top() + row_idx, seg.slice, draw_w, ui.theme.text, inner);
                row_idx += 1;
                // Update wrap width to full interior width for subsequent wrapped lines after line 0.
                wit.max_width = inner.width;
            }
        }
    }
};

test "popup, confirm dialog, and toast render centered overlays cleanly" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 50, 12));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    var state = ConfirmState{};
    try ui.renderStateful(ConfirmDialog{
        .title = "Delete File",
        .message = "Proceed with deletion?",
        .destructive = true,
    }, &state, buf.area);
    try ui.renderWidget(Toast{ .message = "Saved!", .level = .success, .anchor = .top_right }, buf.area);

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Delete File") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "Saved!") != null);
    try testing.expectEqual(ConfirmOutcome.confirmed, state.handleEvent(.{ .key = .{ .code = .{ .char = 'y' } } }));

    // Mouse left-click directly on Cancel button inside modal layout cancels dialog.
    var mouse_st = ConfirmState{};
    const dlg = ConfirmDialog{ .title = "Delete File", .message = "Proceed?" };
    const lay = dlg.layout(buf.area);
    try testing.expectEqual(ConfirmOutcome.cancelled, mouse_st.handleEventAt(.{
        .mouse = .{ .kind = .down, .button = .left, .x = lay.cancel_rect.left(), .y = lay.cancel_rect.top() },
    }, buf.area, dlg));
    try testing.expect(!mouse_st.open);

    // Long multi-line Toast never overflows small viewport bounds (xflow / yflow safe).
    buf.clear();
    const tiny = Rect.init(0, 0, 24, 7);
    const long_toast = Toast{
        .title = "Alert",
        .message = "This long notification message automatically wraps inside narrow terminals without overflowing.",
        .anchor = .bottom_right,
        .level = .warning,
    };
    const t_box = long_toast.computeRect(tiny);
    try testing.expect(t_box.left() >= tiny.left() and t_box.right() <= tiny.right());
    try testing.expect(t_box.top() >= tiny.top() and t_box.bottom() <= tiny.bottom());
    try ui.renderWidget(long_toast, tiny);
}
