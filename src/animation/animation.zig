//! Animation system for TUI.zig
//!
//! Provides timing utilities, easing functions, and animation primitives.

const std = @import("std");
const math = std.math;

/// Easing functions for animations
pub const Easing = struct {
    /// Linear interpolation (no easing)
    pub fn linear(t: f32) f32 {
        return t;
    }

    /// Ease in (accelerate)
    pub fn easeIn(t: f32) f32 {
        return t * t;
    }

    /// Ease out (decelerate)
    pub fn easeOut(t: f32) f32 {
        return 1.0 - (1.0 - t) * (1.0 - t);
    }

    /// Ease in-out (accelerate then decelerate)
    pub fn easeInOut(t: f32) f32 {
        return if (t < 0.5)
            2.0 * t * t
        else
            1.0 - std.math.pow(f32, -2.0 * t + 2.0, 2) / 2.0;
    }

    /// Cubic ease in
    pub fn easeInCubic(t: f32) f32 {
        return t * t * t;
    }

    /// Cubic ease out
    pub fn easeOutCubic(t: f32) f32 {
        return 1.0 - std.math.pow(f32, 1.0 - t, 3);
    }

    /// Cubic ease in-out
    pub fn easeInOutCubic(t: f32) f32 {
        return if (t < 0.5)
            4.0 * t * t * t
        else
            1.0 - std.math.pow(f32, -2.0 * t + 2.0, 3) / 2.0;
    }

    // --- Sine ---
    pub fn easeInSine(t: f32) f32 {
        return 1.0 - math.cos((t * math.pi) / 2.0);
    }
    pub fn easeOutSine(t: f32) f32 {
        return math.sin((t * math.pi) / 2.0);
    }
    pub fn easeInOutSine(t: f32) f32 {
        return -(math.cos(math.pi * t) - 1.0) / 2.0;
    }

    // --- Quad (Same as existing easeIn/Out/InOut but named explicitly) ---
    pub fn easeInQuad(t: f32) f32 {
        return t * t;
    }
    pub fn easeOutQuad(t: f32) f32 {
        return 1.0 - (1.0 - t) * (1.0 - t);
    }
    pub fn easeInOutQuad(t: f32) f32 {
        return if (t < 0.5) 2.0 * t * t else 1.0 - std.math.pow(f32, -2.0 * t + 2.0, 2) / 2.0;
    }

    // --- Quart ---
    pub fn easeInQuart(t: f32) f32 {
        return t * t * t * t;
    }
    pub fn easeOutQuart(t: f32) f32 {
        return 1.0 - std.math.pow(f32, 1.0 - t, 4);
    }
    pub fn easeInOutQuart(t: f32) f32 {
        return if (t < 0.5) 8.0 * t * t * t * t else 1.0 - std.math.pow(f32, -2.0 * t + 2.0, 4) / 2.0;
    }

    // --- Quint ---
    pub fn easeInQuint(t: f32) f32 {
        return t * t * t * t * t;
    }
    pub fn easeOutQuint(t: f32) f32 {
        return 1.0 - std.math.pow(f32, 1.0 - t, 5);
    }
    pub fn easeInOutQuint(t: f32) f32 {
        return if (t < 0.5) 16.0 * t * t * t * t * t else 1.0 - std.math.pow(f32, -2.0 * t + 2.0, 5) / 2.0;
    }

    // --- Expo ---
    pub fn easeInExpo(t: f32) f32 {
        return if (t == 0.0) 0.0 else std.math.pow(f32, 2.0, 10.0 * t - 10.0);
    }
    pub fn easeOutExpo(t: f32) f32 {
        return if (t == 1.0) 1.0 else 1.0 - std.math.pow(f32, 2.0, -10.0 * t);
    }
    pub fn easeInOutExpo(t: f32) f32 {
        if (t == 0.0) return 0.0;
        if (t == 1.0) return 1.0;
        if (t < 0.5) return std.math.pow(f32, 2.0, 20.0 * t - 10.0) / 2.0;
        return (2.0 - std.math.pow(f32, 2.0, -20.0 * t + 10.0)) / 2.0;
    }

    // --- Circ ---
    pub fn easeInCirc(t: f32) f32 {
        return 1.0 - math.sqrt(1.0 - math.pow(f32, t, 2));
    }
    pub fn easeOutCirc(t: f32) f32 {
        return math.sqrt(1.0 - math.pow(f32, t - 1.0, 2));
    }
    pub fn easeInOutCirc(t: f32) f32 {
        return if (t < 0.5)
            (1.0 - math.sqrt(1.0 - math.pow(f32, 2.0 * t, 2))) / 2.0
        else
            (math.sqrt(1.0 - math.pow(f32, -2.0 * t + 2.0, 2)) + 1.0) / 2.0;
    }

    // --- Back ---
    pub fn easeInBack(t: f32) f32 {
        const c1 = 1.70158;
        const c3 = c1 + 1.0;
        return c3 * t * t * t - c1 * t * t;
    }
    pub fn easeOutBack(t: f32) f32 {
        const c1 = 1.70158;
        const c3 = c1 + 1.0;
        const t2 = t - 1.0;
        return 1.0 + c3 * std.math.pow(f32, t2, 3) + c1 * std.math.pow(f32, t2, 2);
    }
    pub fn easeInOutBack(t: f32) f32 {
        const c1 = 1.70158;
        const c2 = c1 * 1.525;
        return if (t < 0.5)
            (std.math.pow(f32, 2.0 * t, 2) * ((c2 + 1.0) * 2.0 * t - c2)) / 2.0
        else
            (std.math.pow(f32, 2.0 * t - 2.0, 2) * ((c2 + 1.0) * (2.0 * t - 2.0) + c2) + 2.0) / 2.0;
    }

    // --- Elastic ---
    pub fn easeInElastic(t: f32) f32 {
        const c4 = (2.0 * std.math.pi) / 3.0;
        return if (t == 0.0) 0.0 else if (t == 1.0) 1.0 else -math.pow(f32, 2.0, 10.0 * t - 10.0) * math.sin((t * 10.0 - 10.75) * c4);
    }
    pub fn easeOutElastic(t: f32) f32 {
        const c4 = (2.0 * std.math.pi) / 3.0;
        return if (t == 0.0) 0.0 else if (t == 1.0) 1.0 else math.pow(f32, 2.0, -10.0 * t) * math.sin((t * 10.0 - 0.75) * c4) + 1.0;
    }
    pub fn easeInOutElastic(t: f32) f32 {
        const c5 = (2.0 * std.math.pi) / 4.5;
        if (t == 0.0) return 0.0;
        if (t == 1.0) return 1.0;
        return if (t < 0.5)
            -(math.pow(f32, 2.0, 20.0 * t - 10.0) * math.sin((20.0 * t - 11.125) * c5)) / 2.0
        else
            (math.pow(f32, 2.0, -20.0 * t + 10.0) * math.sin((20.0 * t - 11.125) * c5)) / 2.0 + 1.0;
    }

    // --- Bounce ---
    pub fn easeOutBounce(t: f32) f32 {
        const n1: f32 = 7.5625;
        const d1: f32 = 2.75;
        if (t < 1.0 / d1) {
            return n1 * t * t;
        } else if (t < 2.0 / d1) {
            const t2 = t - 1.5 / d1;
            return n1 * t2 * t2 + 0.75;
        } else if (t < 2.5 / d1) {
            const t2 = t - 2.25 / d1;
            return n1 * t2 * t2 + 0.9375;
        } else {
            const t2 = t - 2.625 / d1;
            return n1 * t2 * t2 + 0.984375;
        }
    }
    pub fn easeInBounce(t: f32) f32 {
        return 1.0 - easeOutBounce(1.0 - t);
    }
    pub fn easeInOutBounce(t: f32) f32 {
        return if (t < 0.5)
            (1.0 - easeOutBounce(1.0 - 2.0 * t)) / 2.0
        else
            (1.0 + easeOutBounce(2.0 * t - 1.0)) / 2.0;
    }
};

/// Easing function type
pub const EasingFn = *const fn (f32) f32;

/// Animation state
pub const AnimationState = enum {
    idle,
    running,
    paused,
    completed,
};

/// A single animation
pub fn Animation(comptime T: type) type {
    return struct {
        /// Start value
        start_value: T,

        /// End value
        end_value: T,

        /// Duration in milliseconds
        duration_ms: u32,

        /// Easing function
        easing: EasingFn = &Easing.linear,

        /// Current progress (0.0 - 1.0)
        progress: f32 = 0.0,

        /// Elapsed time in milliseconds
        elapsed_ms: u32 = 0,

        /// State
        state: AnimationState = .idle,

        /// Loop count (0 = infinite, 1 = once, etc.)
        loop_count: u32 = 1,

        /// Current loop
        current_loop: u32 = 0,

        /// Reverse on alternate loops
        alternate: bool = false,

        /// Completion callback
        on_complete: ?*const fn () void = null,

        const Self = @This();

        /// Create an animation
        pub fn init(start_val: T, end_val: T, duration_ms: u32) Self {
            return .{
                .start_value = start_val,
                .end_value = end_val,
                .duration_ms = duration_ms,
            };
        }

        /// Set easing function
        pub fn withEasing(self: Self, easing: EasingFn) Self {
            var result = self;
            result.easing = easing;
            return result;
        }

        /// Set loop count
        pub fn loop(self: Self, count: u32) Self {
            var result = self;
            result.loop_count = count;
            return result;
        }

        /// Enable infinite looping
        pub fn loopForever(self: Self) Self {
            var result = self;
            result.loop_count = 0;
            return result;
        }

        /// Enable alternating (ping-pong)
        pub fn withAlternate(self: Self) Self {
            var result = self;
            result.alternate = true;
            return result;
        }

        /// Start the animation
        pub fn start(self: *Self) void {
            self.state = .running;
            self.elapsed_ms = 0;
            self.progress = 0.0;
            self.current_loop = 0;
        }

        /// Pause the animation
        pub fn pause(self: *Self) void {
            if (self.state == .running) {
                self.state = .paused;
            }
        }

        /// Resume the animation
        pub fn resumeAnimation(self: *Self) void {
            if (self.state == .paused) {
                self.state = .running;
            }
        }

        /// Reset the animation
        pub fn reset(self: *Self) void {
            self.state = .idle;
            self.elapsed_ms = 0;
            self.progress = 0.0;
            self.current_loop = 0;
        }

        /// Update the animation
        pub fn update(self: *Self, delta_ms: u32) void {
            if (self.state != .running) return;

            self.elapsed_ms += delta_ms;

            if (self.elapsed_ms >= self.duration_ms) {
                self.current_loop += 1;

                if (self.loop_count == 0 or self.current_loop < self.loop_count) {
                    self.elapsed_ms = 0;
                    if (self.alternate) {
                        const temp = self.start_value;
                        self.start_value = self.end_value;
                        self.end_value = temp;
                    }
                } else {
                    self.state = .completed;
                    self.progress = 1.0;
                    if (self.on_complete) |cb| cb.*();
                    return;
                }
            }

            self.progress = @as(f32, self.elapsed_ms) / @as(f32, self.duration_ms);
        }

        /// Get current value
        pub fn getValue(self: *Self) T {
            const t = self.easing.*(self.progress);
            return lerp(T, self.start_value, self.end_value, t);
        }
    };
}

/// Linear interpolation
fn lerp(comptime T: type, a: T, b: T, t: f32) T {
    return switch (@typeInfo(T)) {
        .Float => a + (b - a) * t,
        .Int => @as(T, @as(f32, a) + (@as(f32, b) - @as(f32, a)) * t),
        else => a,
    };
}

/// FPS counter
pub const FpsCounter = struct {
    frame_times: [60]u32 = undefined,
    index: usize = 0,
    total_time: u32 = 0,

    pub fn init() FpsCounter {
        var f: FpsCounter = .{};
        f.total_time = 0;
        f.index = 0;
        for (0..60) |i| {
            f.frame_times[i] = 16;
            f.total_time += 16;
        }
        return f;
    }

    pub fn update(self: *FpsCounter, delta_ms: u32) void {
        self.total_time -= self.frame_times[self.index];
        self.frame_times[self.index] = delta_ms;
        self.total_time += delta_ms;
        self.index = (self.index + 1) % 60;
    }

    pub fn getFps(self: *FpsCounter) u32 {
        if (self.total_time == 0) return 0;
        const avg_ms: u32 = self.total_time / 60;
        if (avg_ms == 0) return 0;
        return 60000 / avg_ms;
    }
};

test "Animation creation" {
    const anim = Animation(f32).init(0.0, 100.0, 1000);
    try std.testing.expectEqual(@as(f32, 0.0), anim.start_value);
    try std.testing.expectEqual(@as(f32, 100.0), anim.end_value);
}

test "Animation state" {
    var anim = Animation(f32).init(0.0, 1.0, 100);
    try std.testing.expectEqual(AnimationState.idle, anim.state);

    anim.start();
    try std.testing.expectEqual(AnimationState.running, anim.state);

    anim.pause();
    try std.testing.expectEqual(AnimationState.paused, anim.state);
}

test "FPS counter" {
    var fps = FpsCounter.init();
    fps.update(16);
    const result = fps.getFps();
    try std.testing.expect(result > 0);
}
