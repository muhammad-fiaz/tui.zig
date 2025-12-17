//! Theme system for TUI.zig
//!
//! Provides color themes and styling presets for consistent UI appearance.

const std = @import("std");
const color = @import("color.zig");
const style = @import("style.zig");

pub const Color = color.Color;
pub const Style = style.Style;
pub const Colors = color.Colors;

/// Theme definition containing all widget styles
pub const Theme = struct {
    name: []const u8 = "default",

    // ============================================
    // Base Colors
    // ============================================

    /// Primary color for interactive elements
    primary: Color = Colors.blue,

    /// Secondary color for less prominent elements
    secondary: Color = Colors.cyan,

    /// Accent color for highlights
    accent: Color = Colors.magenta,

    /// Background color
    background: Color = .default,

    /// Surface color (for elevated elements)
    surface: Color = .default,

    /// Foreground/text color
    foreground: Color = .default,

    /// Muted text color
    muted: Color = Colors.gray,

    /// Error color
    error_color: Color = Colors.red,

    /// Warning color
    warning: Color = Colors.yellow,

    /// Success color
    success: Color = Colors.green,

    /// Info color
    info: Color = Colors.cyan,

    // ============================================
    // Widget Styles
    // ============================================

    /// Default text style
    text: Style = .{},

    /// Focused element style
    focus: Style = Style{ .attrs = .{ .bold = true } },

    /// Selected element style
    selected: Style = Style{ .attrs = .{ .reverse = true } },

    /// Disabled element style
    disabled: Style = Style{ .fg = Colors.gray },

    /// Button style (normal)
    button: Style = .{},

    /// Button style (hovered)
    button_hover: Style = Style{ .attrs = .{ .bold = true } },

    /// Button style (pressed)
    button_pressed: Style = Style{ .attrs = .{ .reverse = true } },

    /// Input field style
    input: Style = .{},

    /// Input field (focused)
    input_focus: Style = Style{ .attrs = .{ .underline = true } },

    /// Progress bar completed style
    progress_filled: Style = Style{ .fg = Colors.green },

    /// Progress bar empty style
    progress_empty: Style = Style{ .fg = Colors.gray },

    /// Scrollbar track style
    scrollbar_track: Style = Style{ .fg = Colors.gray },

    /// Scrollbar thumb style
    scrollbar_thumb: Style = Style{ .fg = Colors.white },

    /// Tab active style
    tab_active: Style = Style{ .attrs = .{ .bold = true, .underline = true } },

    /// Tab inactive style
    tab_inactive: Style = .{},

    /// Border style
    border: Style = .{},

    /// Title style
    title: Style = Style{ .attrs = .{ .bold = true } },

    /// Header style
    header: Style = Style{ .attrs = .{ .bold = true, .underline = true } },

    /// Footer style
    footer: Style = Style{ .attrs = .{ .dim = true } },

    /// Modal overlay style
    modal_overlay: Style = Style{ .bg = Colors.black },

    /// List item style
    list_item: Style = .{},

    /// List item selected style
    list_item_selected: Style = Style{ .attrs = .{ .reverse = true } },

    /// Table header style
    table_header: Style = Style{ .attrs = .{ .bold = true } },

    /// Table row style (even)
    table_row_even: Style = .{},

    /// Table row style (odd)
    table_row_odd: Style = .{},

    // ============================================
    // Symbols
    // ============================================

    /// Checkbox symbols
    checkbox_checked: []const u8 = "☑",
    checkbox_unchecked: []const u8 = "☐",

    /// Radio button symbols
    radio_selected: []const u8 = "●",
    radio_unselected: []const u8 = "○",

    /// Spinner frames
    spinner_frames: []const []const u8 = &.{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },

    /// Progress bar characters
    progress_full: []const u8 = "█",
    progress_half: []const u8 = "▌",
    progress_empty_char: []const u8 = "░",

    /// Scrollbar characters
    scrollbar_track_char: []const u8 = "│",
    scrollbar_thumb_char: []const u8 = "█",

    /// Arrow characters
    arrow_up: []const u8 = "▲",
    arrow_down: []const u8 = "▼",
    arrow_left: []const u8 = "◀",
    arrow_right: []const u8 = "▶",

    /// Get a style for a specific widget state
    pub fn getButtonStyle(self: Theme, state: ButtonState) Style {
        return switch (state) {
            .normal => self.button,
            .hovered => self.button_hover,
            .pressed => self.button_pressed,
            .disabled => self.disabled,
        };
    }

    /// Get style for input field
    pub fn getInputStyle(self: Theme, focused: bool) Style {
        return if (focused) self.input_focus else self.input;
    }

    /// Get style for list item
    pub fn getListItemStyle(self: Theme, selected: bool) Style {
        return if (selected) self.list_item_selected else self.list_item;
    }

    /// Get style for tab
    pub fn getTabStyle(self: Theme, active: bool) Style {
        return if (active) self.tab_active else self.tab_inactive;
    }

    // ============================================
    // Built-in Themes
    // ============================================

    /// Default theme with basic colors
    pub const default_theme = Theme{};

    /// Dark theme with vibrant colors
    pub const dark = Theme{
        .name = "dark",
        .primary = Color.hex(0x7AA2F7),
        .secondary = Color.hex(0x7DCFFF),
        .accent = Color.hex(0xBB9AF7),
        .background = Color.hex(0x1A1B26),
        .surface = Color.hex(0x24283B),
        .foreground = Color.hex(0xC0CAF5),
        .muted = Color.hex(0x565F89),
        .error_color = Color.hex(0xF7768E),
        .warning = Color.hex(0xE0AF68),
        .success = Color.hex(0x9ECE6A),
        .info = Color.hex(0x7DCFFF),

        .text = Style{ .fg = Color.hex(0xC0CAF5) },
        .focus = Style{ .fg = Color.hex(0x7AA2F7), .attrs = .{ .bold = true } },
        .selected = Style{ .fg = Color.hex(0x1A1B26), .bg = Color.hex(0x7AA2F7) },
        .button = Style{ .fg = Color.hex(0xC0CAF5), .bg = Color.hex(0x24283B) },
        .button_hover = Style{ .fg = Color.hex(0xC0CAF5), .bg = Color.hex(0x3B4261), .attrs = .{ .bold = true } },
        .button_pressed = Style{ .fg = Color.hex(0x1A1B26), .bg = Color.hex(0x7AA2F7) },
        .border = Style{ .fg = Color.hex(0x3B4261) },
        .progress_filled = Style{ .fg = Color.hex(0x9ECE6A) },
        .progress_empty = Style{ .fg = Color.hex(0x3B4261) },
    };

    /// Light theme with soft colors
    pub const light = Theme{
        .name = "light",
        .primary = Color.hex(0x2563EB),
        .secondary = Color.hex(0x0891B2),
        .accent = Color.hex(0x7C3AED),
        .background = Color.hex(0xFAFAFA),
        .surface = Color.hex(0xFFFFFF),
        .foreground = Color.hex(0x18181B),
        .muted = Color.hex(0x71717A),
        .error_color = Color.hex(0xDC2626),
        .warning = Color.hex(0xD97706),
        .success = Color.hex(0x16A34A),
        .info = Color.hex(0x0891B2),

        .text = Style{ .fg = Color.hex(0x18181B) },
        .focus = Style{ .fg = Color.hex(0x2563EB), .attrs = .{ .bold = true } },
        .selected = Style{ .fg = Color.hex(0xFAFAFA), .bg = Color.hex(0x2563EB) },
        .button = Style{ .fg = Color.hex(0x18181B), .bg = Color.hex(0xE4E4E7) },
        .button_hover = Style{ .fg = Color.hex(0x18181B), .bg = Color.hex(0xD4D4D8), .attrs = .{ .bold = true } },
        .border = Style{ .fg = Color.hex(0xD4D4D8) },
        .progress_filled = Style{ .fg = Color.hex(0x16A34A) },
        .progress_empty = Style{ .fg = Color.hex(0xE4E4E7) },
    };

    /// Gruvbox dark theme
    pub const gruvbox = Theme{
        .name = "gruvbox",
        .primary = Color.hex(0x458588),
        .secondary = Color.hex(0x689D6A),
        .accent = Color.hex(0xD3869B),
        .background = Color.hex(0x282828),
        .surface = Color.hex(0x3C3836),
        .foreground = Color.hex(0xEBDBB2),
        .muted = Color.hex(0x928374),
        .error_color = Color.hex(0xFB4934),
        .warning = Color.hex(0xFABD2F),
        .success = Color.hex(0xB8BB26),
        .info = Color.hex(0x83A598),

        .text = Style{ .fg = Color.hex(0xEBDBB2) },
        .focus = Style{ .fg = Color.hex(0xFE8019), .attrs = .{ .bold = true } },
        .border = Style{ .fg = Color.hex(0x504945) },
    };

    /// Nord theme
    pub const nord = Theme{
        .name = "nord",
        .primary = Color.hex(0x88C0D0),
        .secondary = Color.hex(0x81A1C1),
        .accent = Color.hex(0xB48EAD),
        .background = Color.hex(0x2E3440),
        .surface = Color.hex(0x3B4252),
        .foreground = Color.hex(0xECEFF4),
        .muted = Color.hex(0x4C566A),
        .error_color = Color.hex(0xBF616A),
        .warning = Color.hex(0xEBCB8B),
        .success = Color.hex(0xA3BE8C),
        .info = Color.hex(0x88C0D0),

        .text = Style{ .fg = Color.hex(0xECEFF4) },
        .focus = Style{ .fg = Color.hex(0x88C0D0), .attrs = .{ .bold = true } },
        .border = Style{ .fg = Color.hex(0x4C566A) },
    };

    /// Dracula theme
    pub const dracula = Theme{
        .name = "dracula",
        .primary = Color.hex(0xBD93F9),
        .secondary = Color.hex(0x8BE9FD),
        .accent = Color.hex(0xFF79C6),
        .background = Color.hex(0x282A36),
        .surface = Color.hex(0x44475A),
        .foreground = Color.hex(0xF8F8F2),
        .muted = Color.hex(0x6272A4),
        .error_color = Color.hex(0xFF5555),
        .warning = Color.hex(0xFFB86C),
        .success = Color.hex(0x50FA7B),
        .info = Color.hex(0x8BE9FD),

        .text = Style{ .fg = Color.hex(0xF8F8F2) },
        .focus = Style{ .fg = Color.hex(0xFF79C6), .attrs = .{ .bold = true } },
        .border = Style{ .fg = Color.hex(0x6272A4) },
    };

    /// High contrast theme for accessibility
    pub const high_contrast = Theme{
        .name = "high_contrast",
        .primary = Colors.bright_white,
        .secondary = Colors.bright_cyan,
        .accent = Colors.bright_yellow,
        .background = Colors.black,
        .surface = Colors.black,
        .foreground = Colors.bright_white,
        .muted = Colors.white,
        .error_color = Colors.bright_red,
        .warning = Colors.bright_yellow,
        .success = Colors.bright_green,
        .info = Colors.bright_cyan,

        .text = Style{ .fg = Colors.bright_white },
        .focus = Style{ .fg = Colors.bright_yellow, .attrs = .{ .bold = true, .underline = true } },
        .selected = Style{ .fg = Colors.black, .bg = Colors.bright_white },
        .border = Style{ .fg = Colors.bright_white },
        .button = Style{ .fg = Colors.bright_white, .bg = Colors.black, .attrs = .{ .bold = true } },
        .button_hover = Style{ .fg = Colors.black, .bg = Colors.bright_white },
    };
};

/// Button states for styling
pub const ButtonState = enum {
    normal,
    hovered,
    pressed,
    disabled,
};

/// Calculate appropriate text color for a background
pub fn contrastColor(bg: Color) Color {
    if (bg.toRGB()) |c| {
        return if (c.isLight())
            Color.hex(0x000000)
        else
            Color.hex(0xFFFFFF);
    }
    return .default;
}

test "theme button styles" {
    const theme = Theme.dark;
    _ = theme.getButtonStyle(.normal);
    _ = theme.getButtonStyle(.hovered);
    _ = theme.getButtonStyle(.pressed);
    _ = theme.getButtonStyle(.disabled);
}
