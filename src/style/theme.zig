//! Semantic theme and palette definitions wrapping `tint.theme`.
//!
//! A `Theme` pairs a `tint.theme.Theme` color scheme with cohesive widget styles
//! so applications can switch visual palettes consistently without editing
//! individual components.

const std = @import("std");
const tint = @import("tint");
const color_mod = @import("color.zig");
const style_mod = @import("style.zig");
const border_mod = @import("border.zig");
const testing = std.testing;

pub const Color = color_mod.Color;
pub const Style = style_mod.Style;
pub const BorderType = border_mod.BorderType;
pub const TintTheme = tint.theme.Theme;
pub const Role = tint.theme.Role;

/// Re-export `tint.palette` for gradients, ramps, color schemes, and WCAG checks.
pub const palette = tint.palette;

/// Semantic UI theme derived from a `tint.theme.Theme` with explicit overrides.
pub const Theme = struct {
    /// Underlying `tint` color theme.
    base: TintTheme,
    /// Default canvas/background style.
    surface: Style,
    /// Default text style on primary background.
    text: Style,
    /// Secondary / muted text style.
    muted: Style,
    /// Default block border style.
    border: Style,
    /// Focused block or widget border style.
    border_focused: Style,
    /// Title text style.
    title: Style,
    /// Accent / primary brand style.
    accent: Style,
    /// Secondary accent style.
    secondary: Style,
    /// Selected item highlight style (lists, tables, tabs, menus).
    selection: Style,
    /// Unfocused button style.
    button: Style,
    /// Focused button style.
    button_focused: Style,
    /// Disabled control style.
    disabled: Style,
    /// Input field style.
    input: Style,
    /// Focused input field style.
    input_focused: Style,
    /// Success status style.
    success: Style,
    /// Warning status style.
    warning: Style,
    /// Error status style.
    err: Style,
    /// Informational status style.
    info: Style,
    /// Default border style preset used by panels and popups.
    default_border: BorderType = .rounded,

    /// Builds a complete `Theme` from a `tint.theme.Theme`.
    pub fn fromTint(t: TintTheme) Theme {
        const bg = Color.fromTint(t.background);
        const surf = Color.fromTint(t.surface);
        const fg = Color.fromTint(t.text);
        const muted_c = Color.fromTint(t.muted);
        const primary = Color.fromTint(t.primary);
        const secondary = Color.fromTint(t.secondary);
        const ok = Color.fromTint(t.success);
        const warn = Color.fromTint(t.warning);
        const bad = Color.fromTint(t.err);
        const inf = Color.fromTint(t.info);

        return .{
            .base = t,
            .surface = .{ .foreground = fg, .background = bg },
            .text = .{ .foreground = fg },
            .muted = .{ .foreground = muted_c },
            .border = .{ .foreground = muted_c },
            .border_focused = .{ .foreground = primary, .bold = true },
            .title = .{ .foreground = primary, .bold = true },
            .accent = .{ .foreground = primary, .bold = true },
            .secondary = .{ .foreground = secondary },
            .selection = .{ .foreground = bg, .background = primary, .bold = true },
            .button = .{ .foreground = fg, .background = surf },
            .button_focused = .{ .foreground = bg, .background = primary, .bold = true },
            .disabled = .{ .foreground = muted_c, .dim = true },
            .input = .{ .foreground = fg, .background = surf },
            .input_focused = .{ .foreground = fg, .background = surf, .underline = true },
            .success = .{ .foreground = ok, .bold = true },
            .warning = .{ .foreground = warn, .bold = true },
            .err = .{ .foreground = bad, .bold = true },
            .info = .{ .foreground = inf },
            .default_border = .rounded,
        };
    }

    /// Returns the color for a semantic `tint.theme.Role`.
    pub fn role(self: Theme, r: Role) Color {
        return Color.fromTint(self.base.role(r));
    }

    /// Returns a foreground `Style` for `r`.
    pub fn styled(self: Theme, r: Role) Style {
        return .{ .foreground = self.role(r) };
    }

    /// Built-in theme presets backed by `tint.theme`.
    pub const dark = Theme.fromTint(tint.theme.dark);
    pub const light = Theme.fromTint(tint.theme.light);
    pub const dracula = Theme.fromTint(tint.theme.dracula);
    pub const nord = Theme.fromTint(tint.theme.nord);
    pub const monokai = Theme.fromTint(tint.theme.monokai);
    pub const tokyo_night = Theme.fromTint(tint.theme.tokyoNight);
    pub const gruvbox = Theme.fromTint(tint.theme.gruvbox);
    pub const solarized = Theme.fromTint(tint.theme.solarized);
    pub const rose_pine = Theme.fromTint(tint.theme.rosePine);
    pub const catppuccin = Theme.fromTint(tint.theme.catppuccin);
    pub const github = Theme.fromTint(tint.theme.github);
    pub const one_dark = Theme.fromTint(tint.theme.oneDark);
    pub const material = Theme.fromTint(tint.theme.material);
    pub const palenight = Theme.fromTint(tint.theme.palenight);
    pub const everforest = Theme.fromTint(tint.theme.everforest);
    pub const kanagawa = Theme.fromTint(tint.theme.kanagawa);
    pub const cyberdream = Theme.fromTint(tint.theme.cyberdream);
};

test "themes derive styles from tint presets" {
    try testing.expectEqualStrings("dark", Theme.dark.base.name);
    try testing.expectEqualStrings("tokyoNight", Theme.tokyo_night.base.name);
    try testing.expect(!Theme.dark.selection.background.isInherit());
    try testing.expect(Theme.dark.base.contrast(.text, .background) > 5.0);
}
