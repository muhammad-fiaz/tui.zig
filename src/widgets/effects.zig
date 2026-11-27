//! Animations, easing curves, spring physics, visibility transitions,
//! loading skeletons, toast timers, and zero-allocation buffer effects.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const block_mod = @import("block.zig");
const popup_mod = @import("popup.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Direction = core_root.Direction;
pub const Alignment = core_root.Alignment;
pub const Buffer = core_root.Buffer;
pub const Ui = core_root.Ui;
pub const Color = style_root.Color;
pub const Style = style_root.Style;
pub const symbols = style_root.symbols;
pub const Block = block_mod.Block;
pub const OverlayAnchor = popup_mod.OverlayAnchor;
pub const Toast = popup_mod.Toast;
pub const ToastLevel = popup_mod.ToastLevel;

/// Standard mathematical easing curves for `Tween` and `Transition`.
pub const Easing = enum {
    linear,
    ease_in_quad,
    ease_out_quad,
    ease_in_out_quad,
    ease_in_cubic,
    ease_out_cubic,
    ease_in_out_cubic,
    ease_in_out_sine,
    ease_out_back,
    ease_out_bounce,

    /// Evaluates the easing curve for normalized time `t_in` clamped to `0.0..1.0`.
    pub fn apply(self: Easing, t_in: f64) f64 {
        const t = std.math.clamp(t_in, 0.0, 1.0);
        return switch (self) {
            .linear => t,
            .ease_in_quad => t * t,
            .ease_out_quad => 1.0 - (1.0 - t) * (1.0 - t),
            .ease_in_out_quad => if (t < 0.5)
                2.0 * t * t
            else
                1.0 - std.math.pow(f64, -2.0 * t + 2.0, 2.0) / 2.0,
            .ease_in_cubic => t * t * t,
            .ease_out_cubic => 1.0 - std.math.pow(f64, 1.0 - t, 3.0),
            .ease_in_out_cubic => if (t < 0.5)
                4.0 * t * t * t
            else
                1.0 - std.math.pow(f64, -2.0 * t + 2.0, 3.0) / 2.0,
            .ease_in_out_sine => -(std.math.cos(std.math.pi * t) - 1.0) / 2.0,
            .ease_out_back => blk: {
                const c1 = 1.70158;
                const c3 = c1 + 1.0;
                const u = t - 1.0;
                break :blk 1.0 + c3 * u * u * u + c1 * u * u;
            },
            .ease_out_bounce => blk: {
                const n1 = 7.5625;
                const d1 = 2.75;
                if (t < 1.0 / d1) {
                    break :blk n1 * t * t;
                } else if (t < 2.0 / d1) {
                    const u = t - 1.5 / d1;
                    break :blk n1 * u * u + 0.75;
                } else if (t < 2.5 / d1) {
                    const u = t - 2.25 / d1;
                    break :blk n1 * u * u + 0.9375;
                } else {
                    const u = t - 2.625 / d1;
                    break :blk n1 * u * u + 0.984375;
                }
            },
        };
    }
};

/// Playback repeat mode for `Tween`.
pub const LoopMode = enum {
    once,
    loop,
    ping_pong,
};

/// Time-based numeric interpolator (`from` -> `to`) with easing and loop modes.
pub const Tween = struct {
    from: f64 = 0.0,
    to: f64 = 1.0,
    duration_ms: u64 = 300,
    elapsed_ms: u64 = 0,
    easing: Easing = .ease_out_cubic,
    mode: LoopMode = .once,
    reversed: bool = false,
    paused: bool = false,

    pub fn init(from: f64, to: f64, duration_ms: u64, easing: Easing) Tween {
        return .{
            .from = from,
            .to = to,
            .duration_ms = @max(@as(u64, 1), duration_ms),
            .easing = easing,
        };
    }

    /// Advances playback by `dt_ms` milliseconds. Returns `true` when active/updated.
    pub fn advance(self: *Tween, dt_ms: u64) bool {
        if (self.paused or dt_ms == 0) return false;
        const dur = @max(@as(u64, 1), self.duration_ms);
        if (self.mode == .once and self.elapsed_ms >= dur) return false;

        self.elapsed_ms +|= dt_ms;
        switch (self.mode) {
            .once => {
                if (self.elapsed_ms > dur) self.elapsed_ms = dur;
            },
            .loop => {
                self.elapsed_ms = self.elapsed_ms % dur;
            },
            .ping_pong => {
                while (self.elapsed_ms >= dur) {
                    self.elapsed_ms -= dur;
                    self.reversed = !self.reversed;
                }
            },
        }
        return true;
    }

    pub fn reset(self: *Tween) void {
        self.elapsed_ms = 0;
        self.reversed = false;
    }

    pub fn restart(self: *Tween, from: f64, to: f64, duration_ms: u64) void {
        self.from = from;
        self.to = to;
        self.duration_ms = @max(@as(u64, 1), duration_ms);
        self.reset();
    }

    /// Smoothly redirects from the current interpolated value toward `new_to`.
    pub fn retarget(self: *Tween, new_to: f64) void {
        self.from = self.value();
        self.to = new_to;
        self.elapsed_ms = 0;
        self.reversed = false;
    }

    pub fn rawProgress(self: Tween) f64 {
        const dur = @max(@as(u64, 1), self.duration_ms);
        const linear = std.math.clamp(@as(f64, @floatFromInt(self.elapsed_ms)) / @as(f64, @floatFromInt(dur)), 0.0, 1.0);
        return if (self.reversed) 1.0 - linear else linear;
    }

    pub fn progress(self: Tween) f64 {
        return self.easing.apply(self.rawProgress());
    }

    pub fn value(self: Tween) f64 {
        return self.from + (self.to - self.from) * self.progress();
    }

    pub fn isFinished(self: Tween) bool {
        return self.mode == .once and self.elapsed_ms >= @max(@as(u64, 1), self.duration_ms);
    }
};

/// Critically/under-damped spring integrator for smooth meters, scroll positions, and drawers.
pub const Spring = struct {
    value: f64 = 0.0,
    target: f64 = 0.0,
    velocity: f64 = 0.0,
    stiffness: f64 = 180.0,
    damping: f64 = 20.0,
    epsilon: f64 = 0.002,

    pub fn init(initial: f64) Spring {
        return .{ .value = initial, .target = initial };
    }

    pub fn setTarget(self: *Spring, next: f64) void {
        self.target = next;
    }

    pub fn snap(self: *Spring, v: f64) void {
        self.value = v;
        self.target = v;
        self.velocity = 0.0;
    }

    /// Integrates physics over `dt_ms` using bounded 10ms sub-steps for stability.
    /// Returns `true` if `value` changed during this frame.
    pub fn step(self: *Spring, dt_ms: u64) bool {
        if (dt_ms == 0 or self.isSettled()) {
            self.value = self.target;
            self.velocity = 0.0;
            return false;
        }
        var rem_ms = @min(dt_ms, @as(u64, 250));
        while (rem_ms > 0) {
            const chunk = @min(rem_ms, @as(u64, 10));
            rem_ms -= chunk;
            const dt = @as(f64, @floatFromInt(chunk)) / 1000.0;
            const force = (self.target - self.value) * self.stiffness;
            const accel = force - self.velocity * self.damping;
            self.velocity += accel * dt;
            self.value += self.velocity * dt;
        }
        if (self.isSettled()) {
            self.value = self.target;
            self.velocity = 0.0;
        }
        return true;
    }

    pub fn isSettled(self: Spring) bool {
        return @abs(self.target - self.value) < self.epsilon and @abs(self.velocity) < self.epsilon;
    }
};

/// Anchor origin used when expanding or collapsing a `Transition` rect.
pub const RevealOrigin = enum {
    center,
    top,
    bottom,
    left,
    right,
};

/// Bidirectional open/close visibility transition (`0.0` hidden .. `1.0` visible).
pub const Transition = struct {
    active: bool = false,
    progress: f64 = 0.0,
    duration_ms: u64 = 200,
    easing: Easing = .ease_out_cubic,

    pub fn shown() Transition {
        return .{ .active = true, .progress = 1.0 };
    }

    pub fn open(self: *Transition) void {
        self.active = true;
    }

    pub fn close(self: *Transition) void {
        self.active = false;
    }

    pub fn toggle(self: *Transition) void {
        self.active = !self.active;
    }

    /// Steps visibility toward `1.0` (when `active`) or `0.0` (when closed).
    pub fn update(self: *Transition, dt_ms: u64) bool {
        if (dt_ms == 0) return false;
        const dur = @max(@as(u64, 1), self.duration_ms);
        const step_f = @as(f64, @floatFromInt(dt_ms)) / @as(f64, @floatFromInt(dur));
        if (self.active) {
            if (self.progress >= 1.0) return false;
            self.progress = @min(1.0, self.progress + step_f);
            return true;
        } else {
            if (self.progress <= 0.0) return false;
            self.progress = @max(0.0, self.progress - step_f);
            return true;
        }
    }

    pub fn isVisible(self: Transition) bool {
        return self.active or self.progress > 0.001;
    }

    pub fn eased(self: Transition) f64 {
        return self.easing.apply(self.progress);
    }

    /// Computes intermediate animated reveal rectangle inside `full_rect`.
    pub fn animatedRect(self: Transition, full_rect: Rect, origin: RevealOrigin) Rect {
        if (full_rect.isEmpty()) return Rect.zero;
        const f = self.eased();
        if (f <= 0.001) return Rect.zero;
        if (f >= 0.999) return full_rect;
        return switch (origin) {
            .center => blk: {
                const w: u16 = @max(@as(u16, 1), @as(u16, @intFromFloat(@round(@as(f64, @floatFromInt(full_rect.width)) * f))));
                const h: u16 = @max(@as(u16, 1), @as(u16, @intFromFloat(@round(@as(f64, @floatFromInt(full_rect.height)) * f))));
                break :blk full_rect.centered(w, h);
            },
            .top => Rect.init(
                full_rect.x,
                full_rect.y,
                full_rect.width,
                @max(@as(u16, 1), @as(u16, @intFromFloat(@round(@as(f64, @floatFromInt(full_rect.height)) * f)))),
            ),
            .bottom => blk: {
                const h: u16 = @max(@as(u16, 1), @as(u16, @intFromFloat(@round(@as(f64, @floatFromInt(full_rect.height)) * f))));
                break :blk Rect.init(full_rect.x, full_rect.bottom() -| h, full_rect.width, h);
            },
            .left => Rect.init(
                full_rect.x,
                full_rect.y,
                @max(@as(u16, 1), @as(u16, @intFromFloat(@round(@as(f64, @floatFromInt(full_rect.width)) * f)))),
                full_rect.height,
            ),
            .right => blk: {
                const w: u16 = @max(@as(u16, 1), @as(u16, @intFromFloat(@round(@as(f64, @floatFromInt(full_rect.width)) * f))));
                break :blk Rect.init(full_rect.right() -| w, full_rect.y, w, full_rect.height);
            },
        };
    }
};

/// Auto-dismissing toast notification controller with smooth slide/fade transition.
pub const ToastState = struct {
    title: ?[]const u8 = null,
    message: []const u8 = "",
    level: ToastLevel = .info,
    anchor: OverlayAnchor = .bottom_right,
    duration_ms: u64 = 2500,
    elapsed_ms: u64 = 0,
    transition: Transition = .{ .duration_ms = 220, .easing = .ease_out_cubic },

    pub fn show(self: *ToastState, title: ?[]const u8, message: []const u8, level: ToastLevel) void {
        self.title = title;
        self.message = message;
        self.level = level;
        self.elapsed_ms = 0;
        self.transition.open();
    }

    pub fn dismiss(self: *ToastState) void {
        self.transition.close();
    }

    /// Advances toast lifetime and open/close transition by `dt_ms`. Returns `true` if redraw needed.
    pub fn update(self: *ToastState, dt_ms: u64) bool {
        var changed = self.transition.update(dt_ms);
        if (self.transition.active and self.duration_ms > 0) {
            self.elapsed_ms +|= dt_ms;
            if (self.elapsed_ms >= self.duration_ms) {
                self.transition.close();
                changed = true;
            }
        }
        return changed or self.transition.isVisible();
    }

    pub fn isVisible(self: ToastState) bool {
        return self.transition.isVisible() and self.message.len > 0;
    }

    /// Renders animated toast banner inside `screen` when visible without horizontal/vertical overflow.
    pub fn render(self: ToastState, ui: *Ui, screen: Rect) !void {
        if (!self.isVisible()) return;
        const bounds = screen.intersection(ui.buffer.area);
        const toast = Toast{
            .title = self.title,
            .message = self.message,
            .level = self.level,
            .anchor = self.anchor,
            .max_width = 44,
        };
        const target = toast.computeRect(bounds);
        if (target.isEmpty()) return;

        try toast.render(ui, bounds);

        const p = self.transition.eased();
        if (p < 0.999) {
            fade(ui.buffer, target, ui.theme.surface.background, p);
        }
        // Subtle lifetime indicator along bottom border edge inside clamped `target`.
        if (self.duration_ms > 0 and self.transition.active and target.width > 2) {
            const rem = 1.0 - std.math.clamp(@as(f64, @floatFromInt(self.elapsed_ms)) / @as(f64, @floatFromInt(self.duration_ms)), 0.0, 1.0);
            const bar_len: u16 = @intFromFloat(@round(@as(f64, @floatFromInt(target.width - 2)) * rem));
            const accent = switch (self.level) {
                .info => ui.theme.info,
                .success => ui.theme.success,
                .warning => ui.theme.warning,
                .err => ui.theme.err,
            };
            var x: u16 = 0;
            while (x < bar_len and target.left() + 1 + x < target.right() - 1) : (x += 1) {
                _ = ui.buffer.setStringClipped(target.left() + 1 + x, target.bottom() - 1, symbols.line.thick.horizontal, 1, accent, target);
            }
        }
    }
};

/// Multi-toast stack manager preventing vertical (`yflow`) and horizontal (`xflow`) collisions or overflows.
pub fn ToastManager(comptime capacity: usize) type {
    return struct {
        const Self = @This();
        items: [capacity]ToastState = @splat(.{}),
        anchor: OverlayAnchor = .bottom_right,
        default_duration_ms: u64 = 2800,
        gap: u16 = 1,

        /// Enqueues a toast (overwriting the oldest expired or head entry if full).
        pub fn push(self: *Self, title: ?[]const u8, message: []const u8, level: ToastLevel) void {
            for (&self.items) |*slot| {
                if (!slot.isVisible()) {
                    slot.* = .{ .anchor = self.anchor, .duration_ms = self.default_duration_ms };
                    slot.show(title, message, level);
                    return;
                }
            }
            // Shift oldest out if full.
            if (capacity > 1) {
                var i: usize = 0;
                while (i + 1 < capacity) : (i += 1) {
                    self.items[i] = self.items[i + 1];
                }
            }
            self.items[capacity - 1] = .{ .anchor = self.anchor, .duration_ms = self.default_duration_ms };
            self.items[capacity - 1].show(title, message, level);
        }

        pub fn clear(self: *Self) void {
            for (&self.items) |*slot| slot.* = .{};
        }

        /// Advances all active toast timers by `dt_ms`. Returns `true` while any toast needs redrawing.
        pub fn update(self: *Self, dt_ms: u64) bool {
            var active = false;
            for (&self.items) |*slot| {
                if (slot.isVisible()) {
                    if (slot.update(dt_ms)) active = true;
                }
            }
            return active;
        }

        /// Renders active toasts stacked safely inside `screen`, clipping before any `yflow` overflow occurs.
        pub fn render(self: *const Self, ui: *Ui, screen: Rect) !void {
            var remaining = screen.intersection(ui.buffer.area);
            if (remaining.height < 3 or remaining.width < 10) return;

            for (self.items) |slot| {
                if (!slot.isVisible()) continue;
                var copy = slot;
                copy.anchor = self.anchor;
                const toast = Toast{
                    .title = copy.title,
                    .message = copy.message,
                    .level = copy.level,
                    .anchor = self.anchor,
                    .max_width = 44,
                };
                const box = toast.computeRect(remaining);
                if (box.isEmpty() or box.height > remaining.height) break;
                try copy.render(ui, remaining);

                const consume = box.height +| self.gap;
                if (consume >= remaining.height) break;
                switch (self.anchor) {
                    .bottom_left, .bottom_right, .center => {
                        remaining.height -= consume;
                    },
                    .top_left, .top_right => {
                        remaining.y += consume;
                        remaining.height -= consume;
                    },
                }
            }
        }
    };
}

/// Animated loading skeleton placeholder block with horizontal shimmer wave.
pub const Skeleton = struct {
    rows: u16 = 3,
    phase: f64 = 0.0,
    block: ?Block = null,
    base_color: ?Color = null,
    highlight_color: ?Color = null,
    bar_glyph: []const u8 = symbols.block.seven_eighths,

    /// Renders staggered animated shimmer loading bars inside `area`.
    pub fn render(self: Skeleton, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        const base_c = self.base_color orelse ui.theme.border.foreground;
        const hi_c = self.highlight_color orelse ui.theme.accent.foreground;
        const n = @min(self.rows, inner.height);
        const pct_lut = [_]u16{ 88, 72, 94, 60, 80, 52 };

        var r: u16 = 0;
        while (r < n) : (r += 1) {
            const y = inner.top() + r;
            const pct = pct_lut[r % pct_lut.len];
            const bar_w: u16 = @max(@as(u16, 4), @as(u16, @intCast((@as(u32, inner.width) * pct) / 100)));
            var x: u16 = 0;
            while (x < bar_w and x < inner.width) : (x += 1) {
                const pos = @as(f64, @floatFromInt(x)) / @as(f64, @floatFromInt(@max(@as(u16, 1), bar_w)));
                const wave = 0.5 + 0.5 * @sin((pos - self.phase) * std.math.tau);
                const c = base_c.mix(hi_c, wave * 0.75);
                if (ui.buffer.getMut(inner.left() + x, y)) |cell| {
                    try ui.buffer.setCellSymbol(cell, self.bar_glyph);
                    cell.diff_option = .none;
                    cell.setStyle(.{ .foreground = c, .background = ui.theme.surface.background });
                }
            }
        }
    }
};

/// Interpolates foreground and background colors of `area` between `backdrop` (`alpha = 0`)
/// and rendered cell colors (`alpha = 1`).
pub fn fade(buf: *Buffer, area: Rect, backdrop: Color, alpha: f64) void {
    const a = std.math.clamp(alpha, 0.0, 1.0);
    if (a >= 0.999) return;
    const bounds = area.intersection(buf.area);
    if (bounds.isEmpty()) return;

    const target = if (!backdrop.isInherit()) backdrop else Color.black;
    var y = bounds.top();
    while (y < bounds.bottom()) : (y += 1) {
        var x = bounds.left();
        while (x < bounds.right()) : (x += 1) {
            const cell = buf.getMut(x, y) orelse continue;
            if (!cell.fg.isInherit() and !cell.fg.isReset()) {
                cell.fg = target.mix(cell.fg, a);
            }
            if (!cell.bg.isInherit() and !cell.bg.isReset()) {
                cell.bg = target.mix(cell.bg, a);
            }
            if (a < 0.45) cell.modifiers.dim = true;
        }
    }
}

/// Smoothly darkens/dims all cells inside `area` (`strength` in `0.0..1.0`).
pub fn dimBackdrop(buf: *Buffer, area: Rect, strength: f64) void {
    const s = std.math.clamp(strength, 0.0, 1.0);
    if (s <= 0.001) return;
    fade(buf, area, Color.black, 1.0 - s * 0.65);
}

/// Deterministic terminal cell dissolve transition (`progress` `0.0` hidden .. `1.0` fully revealed).
pub fn dissolve(buf: *Buffer, area: Rect, progress: f64, seed: u64) void {
    const p = std.math.clamp(progress, 0.0, 1.0);
    if (p >= 0.999) return;
    const bounds = area.intersection(buf.area);
    if (bounds.isEmpty()) return;

    var y = bounds.top();
    while (y < bounds.bottom()) : (y += 1) {
        var x = bounds.left();
        while (x < bounds.right()) : (x += 1) {
            const cell = buf.getMut(x, y) orelse continue;
            if (p <= 0.001) {
                cell.reset();
                continue;
            }
            const rx = @as(u64, x - bounds.left()) + 1;
            const ry = @as(u64, y - bounds.top()) + 1;
            var h = seed ^ (rx *% 0x9E3779B97F4A7C15) ^ (ry *% 0xBF58476D1CE4E5B9);
            h = (h ^ (h >> 30)) *% 0x94D049BB133111EB;
            h = h ^ (h >> 27);
            const thresh = @as(f64, @floatFromInt(h & 0xFFFF)) / 65535.0;
            if (thresh > p) {
                if (thresh - p < 0.08) {
                    cell.setSymbol("░");
                    cell.modifiers.dim = true;
                } else {
                    cell.reset();
                }
            }
        }
    }
}

/// Directional wipe transition (`progress` `0.0` hidden .. `1.0` revealed) with optional glowing edge.
pub fn sweepWipe(buf: *Buffer, area: Rect, direction: Direction, progress: f64, edge_color: ?Color) void {
    const p = std.math.clamp(progress, 0.0, 1.0);
    if (p >= 0.999) return;
    const bounds = area.intersection(buf.area);
    if (bounds.isEmpty()) return;

    const span: u16 = if (direction == .horizontal) bounds.width else bounds.height;
    const limit: u16 = @intFromFloat(@round(@as(f64, @floatFromInt(span)) * p));

    var y = bounds.top();
    while (y < bounds.bottom()) : (y += 1) {
        var x = bounds.left();
        while (x < bounds.right()) : (x += 1) {
            const pos = if (direction == .horizontal) x - bounds.left() else y - bounds.top();
            const cell = buf.getMut(x, y) orelse continue;
            if (pos > limit) {
                cell.reset();
            } else if (pos == limit and limit < span) {
                if (edge_color) |ec| {
                    cell.fg = ec;
                    cell.modifiers.bold = true;
                }
            }
        }
    }
}

/// Sweeps a diagonal shimmer highlight band across existing non-empty glyphs in `area`.
pub fn shimmer(buf: *Buffer, area: Rect, phase: f64, highlight: Color, band_width: f64) void {
    const bounds = area.intersection(buf.area);
    if (bounds.isEmpty() or highlight.isInherit()) return;

    const span = @as(f64, @floatFromInt(bounds.width + bounds.height));
    const norm_phase = @mod(phase, 1.0);
    const center = -band_width + norm_phase * (span + band_width * 2.0);
    const bw = @max(1.0, band_width);

    var y = bounds.top();
    while (y < bounds.bottom()) : (y += 1) {
        var x = bounds.left();
        while (x < bounds.right()) : (x += 1) {
            const cell = buf.getMut(x, y) orelse continue;
            const diag = @as(f64, @floatFromInt(x - bounds.left())) + @as(f64, @floatFromInt(y - bounds.top())) * 0.5;
            const dist = @abs(diag - center);
            if (dist <= bw) {
                const intensity = 1.0 - (dist / bw);
                const base_fg = if (!cell.fg.isInherit() and !cell.fg.isReset()) cell.fg else Color.white;
                cell.fg = base_fg.mix(highlight, intensity * 0.85);
            }
        }
    }
}

/// Applies a smooth sinusoidal pulse glow to foreground colors inside `area`.
pub fn pulseHighlight(buf: *Buffer, area: Rect, phase: f64, glow_color: Color) void {
    const bounds = area.intersection(buf.area);
    if (bounds.isEmpty() or glow_color.isInherit()) return;
    const strength = 0.2 + 0.55 * (0.5 + 0.5 * @sin(phase));

    var y = bounds.top();
    while (y < bounds.bottom()) : (y += 1) {
        var x = bounds.left();
        while (x < bounds.right()) : (x += 1) {
            const cell = buf.getMut(x, y) orelse continue;
            if (cell.symbol_len == 0 and cell.bg.isInherit()) continue;
            if (!cell.fg.isInherit() and !cell.fg.isReset()) {
                cell.fg = cell.fg.mix(glow_color, strength);
            }
        }
    }
}

/// Returns a UTF-8 prefix slicing on valid grapheme cluster boundaries (`<= max_graphemes`) for typewriter effects.
pub fn typewriterSlice(text: []const u8, max_graphemes: usize) []const u8 {
    if (max_graphemes == 0 or text.len == 0) return text[0..0];
    var git = text_root.GraphemeIterator.init(text);
    var count: usize = 0;
    var end_idx: usize = 0;
    while (git.next()) |_| {
        count += 1;
        end_idx = git.index;
        if (count >= max_graphemes) break;
    }
    return text[0..end_idx];
}

/// Renders horizontally scrolling marquee UTF-8 text into `out` up to `view_width` columns (zero heap allocations).
pub fn marqueeSlice(text: []const u8, offset_cols: usize, view_width: u16, out: []u8) []const u8 {
    if (text.len == 0 or view_width == 0 or out.len == 0) return out[0..0];
    const tw = text_root.displayWidth(text);
    if (tw <= view_width) {
        const len = @min(text.len, out.len);
        @memcpy(out[0..len], text[0..len]);
        return out[0..len];
    }
    const separator = "   •   ";
    const gap_w: usize = text_root.displayWidth(separator);
    const cycle: usize = @as(usize, tw) + gap_w;
    var col_idx: usize = offset_cols % cycle;

    var pos: usize = 0;
    var filled_w: u16 = 0;
    while (filled_w < view_width and pos < out.len) {
        if (col_idx < tw) {
            var c: usize = 0;
            var git = text_root.GraphemeIterator.init(text);
            while (git.next()) |g| {
                if (c < col_idx) {
                    c += g.width;
                    continue;
                }
                if (filled_w + g.width > view_width or pos + g.slice.len > out.len) {
                    return out[0..pos];
                }
                @memcpy(out[pos .. pos + g.slice.len], g.slice);
                pos += g.slice.len;
                filled_w += g.width;
                col_idx += g.width;
                if (col_idx >= tw) break;
            }
            if (c < col_idx) col_idx = tw;
        } else {
            const sep_off = col_idx - tw;
            var sc: usize = 0;
            var git = text_root.GraphemeIterator.init(separator);
            while (git.next()) |g| {
                if (sc < sep_off) {
                    sc += g.width;
                    continue;
                }
                if (filled_w + g.width > view_width or pos + g.slice.len > out.len) {
                    return out[0..pos];
                }
                @memcpy(out[pos .. pos + g.slice.len], g.slice);
                pos += g.slice.len;
                filled_w += g.width;
                col_idx = (col_idx + g.width) % cycle;
                if (col_idx == 0) break;
            }
            if (col_idx >= cycle) col_idx = 0;
        }
    }
    return out[0..pos];
}

test "easing, tween, spring, transition, and buffer effects work cleanly" {
    var tw = Tween.init(10.0, 110.0, 100, .ease_out_cubic);
    try testing.expectEqual(@as(f64, 10.0), tw.value());
    try testing.expect(tw.advance(50));
    try testing.expect(tw.value() > 60.0 and tw.value() < 110.0);
    try testing.expect(tw.advance(50));
    try testing.expectEqual(@as(f64, 110.0), tw.value());
    try testing.expect(tw.isFinished());

    var sp = Spring.init(0.0);
    sp.setTarget(100.0);
    for (0..30) |_| _ = sp.step(16);
    try testing.expect(sp.value > 50.0);

    var tr = Transition{ .duration_ms = 100 };
    tr.open();
    _ = tr.update(50);
    const r = tr.animatedRect(Rect.init(0, 0, 20, 10), .center);
    try testing.expect(r.width > 0 and r.width <= 20);

    const alloc = testing.allocator;
    var buf = try Buffer.init(alloc, Rect.init(0, 0, 20, 4));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;
    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);

    try (Skeleton{ .rows = 2, .phase = 0.4 }).render(&ui, buf.area);
    shimmer(&buf, buf.area, 0.5, .white, 4.0);
    fade(&buf, buf.area, .black, 0.5);
    try testing.expectEqualStrings("He", typewriterSlice("Hello", 2));

    var m_buf: [32]u8 = undefined;
    try testing.expectEqualStrings("lo", marqueeSlice("Hello", 3, 2, &m_buf));

    // Multi-toast manager stacks vertically inside small viewport without overflowing.
    var tm = ToastManager(4){ .anchor = .bottom_right };
    tm.push("A", "First", .info);
    tm.push("B", "Second", .success);
    try testing.expect(tm.update(16));
    buf.clear();
    try tm.render(&ui, buf.area);
}
