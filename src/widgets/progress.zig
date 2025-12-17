//! Progress bar widget

const std = @import("std");
const widget = @import("widget.zig");
const layout = @import("../layout/layout.zig");
const style_mod = @import("../style/style.zig");
const unicode = @import("../unicode/unicode.zig");

pub const RenderContext = widget.RenderContext;
pub const StatefulWidget = widget.StatefulWidget;
pub const SizeHint = widget.SizeHint;
pub const Style = style_mod.Style;
pub const Rect = layout.Rect;

/// Progress bar widget
pub const ProgressBar = struct {
    /// Current progress (0.0 - 1.0)
    progress: f32 = 0.0,

    /// Show percentage text
    show_percentage: bool = true,

    /// Filled style
    filled_style: ?Style = null,

    /// Empty style
    empty_style: ?Style = null,

    /// Fill character
    fill_char: []const u8 = "█",

    /// Empty character
    empty_char: []const u8 = "░",

    /// Half-fill character for smoother progress
    half_char: []const u8 = "▌",

    /// Style for the label
    label_style: ?Style = null,

    /// Custom label format
    label: ?[]const u8 = null,

    /// Base widget state
    base: StatefulWidget = .{},

    /// Create a progress bar
    pub fn init() ProgressBar {
        return .{};
    }

    /// Create with initial progress
    pub fn initWithProgress(progress: f32) ProgressBar {
        return .{
            .progress = std.math.clamp(progress, 0.0, 1.0),
        };
    }

    /// Set progress (0.0 - 1.0)
    pub fn setProgress(self: *ProgressBar, progress: f32) void {
        const clamped = std.math.clamp(progress, 0.0, 1.0);
        if (self.progress != clamped) {
            self.progress = clamped;
            self.base.markDirty();
        }
    }

    /// Get progress as percentage (0 - 100)
    pub fn getPercentage(self: *ProgressBar) u8 {
        return @intFromFloat(self.progress * 100.0);
    }

    /// Hide percentage display
    pub fn hidePercentage(self: ProgressBar) ProgressBar {
        var result = self;
        result.show_percentage = false;
        return result;
    }

    /// Set custom characters
    pub fn withChars(self: ProgressBar, fill: []const u8, empty: []const u8) ProgressBar {
        var result = self;
        result.fill_char = fill;
        result.empty_char = empty;
        return result;
    }

    /// Render the progress bar
    pub fn render(self: *ProgressBar, ctx: *RenderContext) void {
        var sub = ctx.getSubScreen();

        // Calculate dimensions
        var bar_width = sub.width;
        var label_width: u16 = 0;

        if (self.show_percentage) {
            label_width = 5; // " 100%"
            bar_width = sub.width -| label_width;
        }

        // Calculate filled portion
        const fill_amount = @as(f32, @floatFromInt(bar_width)) * self.progress;
        const filled_cells: u16 = @intFromFloat(fill_amount);
        const has_half = (fill_amount - @as(f32, @floatFromInt(filled_cells))) >= 0.5;

        // Draw filled portion
        sub.setStyle(self.filled_style orelse ctx.theme.progress_filled);
        sub.moveCursor(0, 0);

        for (0..filled_cells) |_| {
            sub.putString(self.fill_char);
        }

        // Draw half-fill if applicable
        if (has_half and filled_cells < bar_width) {
            sub.putString(self.half_char);
        }

        // Draw empty portion
        sub.setStyle(self.empty_style orelse ctx.theme.progress_empty);
        const empty_start = filled_cells + @as(u16, if (has_half) 1 else 0);

        for (empty_start..bar_width) |_| {
            sub.putString(self.empty_char);
        }

        // Draw percentage
        if (self.show_percentage) {
            sub.setStyle(self.label_style orelse ctx.theme.text);
            const pct = self.getPercentage();
            var buf: [5]u8 = undefined;
            const len = std.fmt.bufPrint(&buf, " {d:>3}%", .{pct}) catch 0;
            sub.putString(buf[0..len]);
        }
    }

    /// Get size hint
    pub fn sizeHint(self: *ProgressBar) SizeHint {
        const min_w: u16 = if (self.show_percentage) 15 else 10;
        return .{
            .min_width = min_w,
            .preferred_width = 40,
            .min_height = 1,
            .preferred_height = 1,
            .expand_x = true,
        };
    }
};

/// Animated spinner widget
pub const Spinner = struct {
    /// Spinner frames
    frames: []const []const u8 = &.{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },

    /// Current frame index
    frame: usize = 0,

    /// Label text
    label: []const u8 = "",

    /// Style
    style: ?Style = null,

    /// Animation speed (frames per second)
    fps: u8 = 10,

    /// Last update time
    last_update: i64 = 0,

    /// Base widget state
    base: StatefulWidget = .{},

    /// Preset spinner styles
    pub const Preset = enum {
        dots,
        line,
        dots_scrolling,
        star,
        box_bounce,
        arrow,

        pub fn frames(self: Preset) []const []const u8 {
            return switch (self) {
                .dots => &.{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
                .line => &.{ "-", "\\", "|", "/" },
                .dots_scrolling => &.{ ".  ", ".. ", "...", " ..", "  .", "   " },
                .star => &.{ "✶", "✸", "✹", "✺", "✹", "✸" },
                .box_bounce => &.{ "▖", "▘", "▝", "▗" },
                .arrow => &.{ "←", "↖", "↑", "↗", "→", "↘", "↓", "↙" },
            };
        }
    };

    /// Create a spinner
    pub fn init() Spinner {
        return .{};
    }

    /// Create with preset
    pub fn initPreset(preset: Preset) Spinner {
        return .{ .frames = preset.frames() };
    }

    /// Create with label
    pub fn initWithLabel(lbl: []const u8) Spinner {
        return .{ .label = lbl };
    }

    /// Advance to next frame
    pub fn tick(self: *Spinner) void {
        self.frame = (self.frame + 1) % self.frames.len;
        self.base.markDirty();
    }

    /// Update based on time
    pub fn update(self: *Spinner, time_ns: i64) bool {
        const frame_duration_ns = @divTrunc(@as(i64, 1_000_000_000), @as(i64, self.fps));
        if (time_ns - self.last_update >= frame_duration_ns) {
            self.tick();
            self.last_update = time_ns;
            return true;
        }
        return false;
    }

    /// Render the spinner
    pub fn render(self: *Spinner, ctx: *RenderContext) void {
        var sub = ctx.getSubScreen();
        sub.setStyle(self.style orelse ctx.theme.text);
        sub.moveCursor(0, 0);

        // Draw current frame
        if (self.frame < self.frames.len) {
            sub.putString(self.frames[self.frame]);
        }

        // Draw label if present
        if (self.label.len > 0) {
            sub.putString(" ");
            sub.putString(self.label);
        }
    }

    /// Get size hint
    pub fn sizeHint(self: *Spinner) SizeHint {
        const spinner_width = if (self.frames.len > 0)
            @as(u16, @intCast(unicode.stringWidth(self.frames[0])))
        else
            1;
        const label_width = @as(u16, @intCast(unicode.stringWidth(self.label)));
        const total_width = spinner_width + (if (self.label.len > 0) label_width + 1 else 0);

        return .{
            .min_width = total_width,
            .preferred_width = total_width,
            .min_height = 1,
            .preferred_height = 1,
        };
    }
};

test "progress bar" {
    var bar = ProgressBar.init();
    bar.setProgress(0.5);
    try std.testing.expectEqual(@as(u8, 50), bar.getPercentage());
}

test "progress bar clamping" {
    var bar = ProgressBar.init();
    bar.setProgress(1.5);
    try std.testing.expect(bar.progress <= 1.0);
    bar.setProgress(-0.5);
    try std.testing.expect(bar.progress >= 0.0);
}

test "spinner" {
    var spinner = Spinner.init();
    const initial_frame = spinner.frame;
    spinner.tick();
    try std.testing.expect(spinner.frame != initial_frame or spinner.frames.len == 1);
}
