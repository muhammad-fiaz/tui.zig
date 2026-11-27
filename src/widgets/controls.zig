//! Modern interactive UI controls: `Switch` (Toggle), `Slider`, `Accordion`, and `Badge`.

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
pub const Event = event_root.Event;
pub const symbols = style_root.symbols;

/// Semantic tone for `Badge` / pill tags.
pub const BadgeVariant = enum {
    accent,
    neutral,
    success,
    warning,
    danger,
    info,
};

/// Compact single-row pill badge (`[ LIVE ]`).
pub const Badge = struct {
    label: []const u8,
    variant: BadgeVariant = .accent,
    style: ?Style = null,

    pub fn width(self: Badge) u16 {
        return text_root.displayWidth(self.label) +| 2;
    }

    pub fn render(self: Badge, ui: *Ui, area: Rect) void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty() or bounds.width < 3) return;

        const base_s: Style = self.style orelse switch (self.variant) {
            .accent => ui.theme.accent.patch(.{ .reverse = true, .bold = true }),
            .neutral => ui.theme.button,
            .success => ui.theme.success.patch(.{ .reverse = true, .bold = true }),
            .warning => ui.theme.warning.patch(.{ .reverse = true, .bold = true }),
            .danger => ui.theme.err.patch(.{ .reverse = true, .bold = true }),
            .info => ui.theme.info.patch(.{ .reverse = true, .bold = true }),
        };

        var pos = ui.buffer.setStringClipped(bounds.left(), bounds.top(), " ", bounds.width, base_s, bounds);
        pos = ui.buffer.setStringClipped(pos.x, bounds.top(), self.label, bounds.right() -| pos.x, base_s, bounds);
        if (pos.x < bounds.right()) {
            _ = ui.buffer.setStringClipped(pos.x, bounds.top(), " ", 1, base_s, bounds);
        }
    }
};

/// Binary ON/OFF switch pill (`Switch` / `Toggle`).
pub const Switch = struct {
    label: []const u8,
    on: bool = false,
    focused: bool = false,
    disabled: bool = false,
    on_text: []const u8 = "ON ",
    off_text: []const u8 = "OFF",
    style: ?Style = null,

    /// Handles Space/Enter/left-click inside `bounds`, toggling `*on`. Returns `true` if toggled.
    pub fn handleEvent(on: *bool, event: Event, bounds: Rect, focused: bool) bool {
        const hit = switch (event) {
            .mouse => |m| m.isLeftClickInside(bounds),
            .key => |k| focused and k.kind != .release and (k.code == .enter or k.isChar(' ')),
            else => false,
        };
        if (hit) {
            on.* = !on.*;
            return true;
        }
        return false;
    }

    pub fn render(self: Switch, ui: *Ui, area: Rect) void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        const track_s = if (self.disabled)
            ui.theme.disabled
        else if (self.on)
            ui.theme.success.patch(.{ .reverse = true, .bold = true })
        else
            ui.theme.muted.patch(.{ .reverse = true });

        const lbl_s = if (self.disabled)
            ui.theme.disabled
        else if (self.focused)
            self.style orelse ui.theme.accent.patch(.{ .bold = true })
        else
            self.style orelse ui.theme.text;

        const y = bounds.top();
        var buf: [24]u8 = undefined;
        const pill = if (self.on)
            std.fmt.bufPrint(&buf, " {s} ● ", .{self.on_text}) catch " ON ● "
        else
            std.fmt.bufPrint(&buf, " ○ {s} ", .{self.off_text}) catch " ○ OFF ";

        var pos = ui.buffer.setStringClipped(bounds.left(), y, pill, bounds.width, track_s, bounds);
        if (self.label.len > 0 and pos.x + 1 < bounds.right()) {
            pos = ui.buffer.setStringClipped(pos.x, y, " ", 1, lbl_s, bounds);
            _ = ui.buffer.setStringClipped(pos.x, y, self.label, bounds.right() -| pos.x, lbl_s, bounds);
        }
    }
};

/// Mutable numeric range state for `Slider`.
pub const SliderState = struct {
    value: f64 = 0.0,
    min: f64 = 0.0,
    max: f64 = 100.0,
    step: f64 = 5.0,

    pub fn clamp(self: *SliderState) void {
        if (std.math.isNan(self.value)) self.value = self.min;
        self.value = std.math.clamp(self.value, self.min, self.max);
    }

    pub fn ratio(self: SliderState) f64 {
        const span = self.max - self.min;
        if (span <= 0.0) return 0.0;
        return std.math.clamp((self.value - self.min) / span, 0.0, 1.0);
    }

    pub fn handleEvent(self: *SliderState, event: Event, bounds: Rect, focused: bool) bool {
        switch (event) {
            .mouse => |m| {
                if ((m.isLeftClickInside(bounds) or (m.kind == .drag and m.button == .left and m.isInside(bounds))) and bounds.width > 1) {
                    const rel = @as(f64, @floatFromInt(m.x - bounds.left())) / @as(f64, @floatFromInt(bounds.width - 1));
                    self.value = self.min + rel * (self.max - self.min);
                    self.clamp();
                    return true;
                }
                if (m.isInside(bounds) and (m.kind == .scroll_up or m.kind == .scroll_right)) {
                    self.value += self.step;
                    self.clamp();
                    return true;
                }
                if (m.isInside(bounds) and (m.kind == .scroll_down or m.kind == .scroll_left)) {
                    self.value -= self.step;
                    self.clamp();
                    return true;
                }
                return false;
            },
            .key => |k| {
                if (!focused or k.kind == .release) return false;
                switch (k.code) {
                    .right, .up => {
                        self.value += self.step;
                        self.clamp();
                        return true;
                    },
                    .left, .down => {
                        self.value -= self.step;
                        self.clamp();
                        return true;
                    },
                    .home => {
                        self.value = self.min;
                        return true;
                    },
                    .end => {
                        self.value = self.max;
                        return true;
                    },
                    else => return false,
                }
            },
            else => return false,
        }
    }
};

/// Interactive horizontal value slider (`Label ───●────── 50%`).
pub const Slider = struct {
    label: ?[]const u8 = null,
    focused: bool = false,
    disabled: bool = false,
    show_value: bool = true,
    precision: u8 = 0,
    unit: ?[]const u8 = null,
    knob: []const u8 = "●",
    filled_style: ?Style = null,
    track_style: ?Style = null,

    fn formatValue(self: Slider, val: f64, buf: []u8) []const u8 {
        if (!self.show_value) return "";
        const u = self.unit orelse "";
        return switch (self.precision) {
            0 => std.fmt.bufPrint(buf, " {d:.0}{s}", .{ val, u }) catch "",
            1 => std.fmt.bufPrint(buf, " {d:.1}{s}", .{ val, u }) catch "",
            else => std.fmt.bufPrint(buf, " {d:.2}{s}", .{ val, u }) catch "",
        };
    }

    /// Computes exact interactive track `Rect` excluding label, formatted number, and optional unit suffix.
    pub fn trackRect(self: Slider, area: Rect, state: SliderState) Rect {
        if (area.isEmpty()) return Rect.zero;
        var start_x = area.left();
        if (self.label) |lbl| {
            const lw = @min(text_root.displayWidth(lbl), area.width / 2);
            start_x +|= lw;
            if (start_x < area.right()) start_x += 1;
        }
        var val_buf: [32]u8 = undefined;
        const val_str = self.formatValue(state.value, &val_buf);
        const val_w = text_root.displayWidth(val_str);
        const track_w = area.right() -| start_x -| val_w;
        return Rect.init(start_x, area.top() + area.height / 2, track_w, 1);
    }

    /// Handles keyboard, wheel, click, and drag interactions aligned to the exact track span inside `area`.
    pub fn handleEvent(self: Slider, state: *SliderState, event: Event, area: Rect) bool {
        if (self.disabled) return false;
        if (event == .mouse) {
            const m = event.mouse;
            if (!m.isInside(area)) return false;
            const trk = self.trackRect(area, state.*);
            if ((m.kind == .down or m.kind == .drag) and m.button == .left and !trk.isEmpty()) {
                if (m.x <= trk.left()) {
                    state.value = state.min;
                } else if (m.x >= trk.right() - 1) {
                    state.value = state.max;
                } else if (trk.width > 1) {
                    const rel = @as(f64, @floatFromInt(m.x - trk.left())) / @as(f64, @floatFromInt(trk.width - 1));
                    state.value = state.min + rel * (state.max - state.min);
                }
                state.clamp();
                return true;
            }
            if (m.kind == .scroll_up or m.kind == .scroll_right) {
                state.value += state.step;
                state.clamp();
                return true;
            }
            if (m.kind == .scroll_down or m.kind == .scroll_left) {
                state.value -= state.step;
                state.clamp();
                return true;
            }
            return false;
        }
        return state.handleEvent(event, area, self.focused);
    }

    pub fn renderStateful(self: Slider, ui: *Ui, area: Rect, state: *SliderState) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        state.clamp();
        const y = bounds.top() + bounds.height / 2;
        var start_x = bounds.left();

        if (self.label) |lbl| {
            const lbl_s = if (self.disabled)
                ui.theme.disabled
            else if (self.focused)
                ui.theme.accent.patch(.{ .bold = true })
            else
                ui.theme.text;
            start_x = ui.buffer.setStringClipped(start_x, y, lbl, bounds.width / 2, lbl_s, bounds).x;
            if (start_x < bounds.right()) {
                start_x = ui.buffer.setStringClipped(start_x, y, " ", 1, lbl_s, bounds).x;
            }
        }

        var val_buf: [32]u8 = undefined;
        const val_str = self.formatValue(state.value, &val_buf);
        const val_w = text_root.displayWidth(val_str);
        const track_w = bounds.right() -| start_x -| val_w;
        if (track_w < 2) return;

        const r = state.ratio();
        const knob_idx: u16 = @intFromFloat(@round(r * @as(f64, @floatFromInt(track_w - 1))));
        const fill_s = if (self.disabled) ui.theme.disabled else self.filled_style orelse ui.theme.accent;
        const trk_s = if (self.disabled) ui.theme.disabled else self.track_style orelse ui.theme.muted;

        var i: u16 = 0;
        while (i < track_w) : (i += 1) {
            const gx = start_x + i;
            if (ui.buffer.getMut(gx, y)) |cell| {
                if (i == knob_idx) {
                    try ui.buffer.setCellSymbol(cell, self.knob);
                    cell.setStyle(if (self.focused and !self.disabled) fill_s.patch(.{ .bold = true }) else fill_s);
                } else {
                    try ui.buffer.setCellSymbol(cell, symbols.line.thick.horizontal);
                    cell.setStyle(if (i < knob_idx) fill_s else trk_s);
                }
                cell.diff_option = .none;
            }
        }

        if (val_w > 0) {
            _ = ui.buffer.setStringClipped(start_x + track_w, y, val_str, val_w, if (self.disabled) ui.theme.disabled else ui.theme.text, bounds);
        }
    }
};

/// Expandable / collapsible header container (`▾ Section` / `▸ Section`).
pub const Accordion = struct {
    title: []const u8,
    expanded: bool = true,
    focused: bool = false,
    bordered: bool = true,

    /// Handles Space / Enter / header click toggling `*expanded`.
    pub fn handleEvent(expanded: *bool, event: Event, header_bounds: Rect, focused: bool) bool {
        const toggled = switch (event) {
            .mouse => |m| m.isLeftClickInside(Rect.init(header_bounds.x, header_bounds.y, header_bounds.width, 1)),
            .key => |k| focused and k.kind != .release and (k.code == .enter or k.isChar(' ')),
            else => false,
        };
        if (toggled) {
            expanded.* = !expanded.*;
            return true;
        }
        return false;
    }

    /// Renders collapsible header and (when `expanded`) invokes `draw_fn(ctx, *Ui)` inside body.
    pub fn renderWith(
        self: Accordion,
        ui: *Ui,
        area: Rect,
        ctx: anytype,
        comptime draw_fn: anytype,
    ) !u16 {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return 0;

        const arrow = if (self.expanded) symbols.tree.unicode.expanded else symbols.tree.unicode.collapsed;
        const hdr_s = if (self.focused) ui.theme.accent.patch(.{ .bold = true }) else ui.theme.title;
        const pos = ui.buffer.setStringClipped(bounds.left(), bounds.top(), arrow, bounds.width, hdr_s, bounds);
        _ = ui.buffer.setStringClipped(pos.x, bounds.top(), self.title, bounds.right() -| pos.x, hdr_s, bounds);

        if (!self.expanded or bounds.height <= 1) return 1;

        const body_area = Rect.init(bounds.left() +| 2, bounds.top() + 1, bounds.width -| 2, bounds.height - 1);
        var body_ui = ui.region(body_area);
        const start_y = body_ui.flow_y;
        const ret_err = @typeInfo(@typeInfo(@TypeOf(draw_fn)).@"fn".return_type.?) == .error_union;
        if (ret_err) {
            try draw_fn(ctx, &body_ui);
        } else {
            draw_fn(ctx, &body_ui);
        }
        const used_body = @max(@as(u16, 1), body_ui.flow_y -| start_y);
        return @min(bounds.height, 1 + used_body);
    }
};

test "switch, slider, accordion, and badge render and react cleanly" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 36, 7));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    var on = false;
    try testing.expect(Switch.handleEvent(&on, .{ .key = .{ .code = .{ .char = ' ' } } }, buf.area, true));
    (Switch{ .label = "Turbo", .on = on, .focused = true }).render(&ui, Rect.init(0, 0, 30, 1));

    var sl = SliderState{ .value = 50, .step = 10 };
    try testing.expect(sl.handleEvent(.{ .key = .{ .code = .right } }, buf.area, true));
    try testing.expectEqual(@as(f64, 60.0), sl.value);
    const slider = Slider{ .label = "Vol", .focused = true };
    const sl_area = Rect.init(0, 1, 30, 1);
    const trk = slider.trackRect(sl_area, sl);
    try testing.expect(slider.handleEvent(&sl, .{ .mouse = .{ .kind = .drag, .button = .left, .x = trk.right() - 1, .y = trk.top() } }, sl_area));
    try testing.expectEqual(@as(f64, 100.0), sl.value);
    try slider.renderStateful(&ui, sl_area, &sl);

    (Badge{ .label = "LIVE", .variant = .success }).render(&ui, Rect.init(0, 2, 10, 1));

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Turbo") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "100") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "LIVE") != null);
}
