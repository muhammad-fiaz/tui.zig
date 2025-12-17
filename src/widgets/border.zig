// Border styles and rendering utilities.
// Provides various box-drawing character sets for widget borders.

const std = @import("std");

pub const BorderStyle = enum {
    none,
    single,
    double,
    rounded,
    thick,
    ascii,
    custom,
};

pub const BorderChars = struct {
    top_left: []const u8,
    top_right: []const u8,
    bottom_left: []const u8,
    bottom_right: []const u8,
    horizontal: []const u8,
    vertical: []const u8,
    left_t: []const u8,
    right_t: []const u8,
    top_t: []const u8,
    bottom_t: []const u8,
    cross: []const u8,

    pub const single = BorderChars{
        .top_left = "┌",
        .top_right = "┐",
        .bottom_left = "└",
        .bottom_right = "┘",
        .horizontal = "─",
        .vertical = "│",
        .left_t = "├",
        .right_t = "┤",
        .top_t = "┬",
        .bottom_t = "┴",
        .cross = "┼",
    };

    pub const double = BorderChars{
        .top_left = "╔",
        .top_right = "╗",
        .bottom_left = "╚",
        .bottom_right = "╝",
        .horizontal = "═",
        .vertical = "║",
        .left_t = "╠",
        .right_t = "╣",
        .top_t = "╦",
        .bottom_t = "╩",
        .cross = "╬",
    };

    pub const rounded = BorderChars{
        .top_left = "╭",
        .top_right = "╮",
        .bottom_left = "╰",
        .bottom_right = "╯",
        .horizontal = "─",
        .vertical = "│",
        .left_t = "├",
        .right_t = "┤",
        .top_t = "┬",
        .bottom_t = "┴",
        .cross = "┼",
    };

    pub const thick = BorderChars{
        .top_left = "┏",
        .top_right = "┓",
        .bottom_left = "┗",
        .bottom_right = "┛",
        .horizontal = "━",
        .vertical = "┃",
        .left_t = "┣",
        .right_t = "┫",
        .top_t = "┳",
        .bottom_t = "┻",
        .cross = "╋",
    };

    pub const ascii = BorderChars{
        .top_left = "+",
        .top_right = "+",
        .bottom_left = "+",
        .bottom_right = "+",
        .horizontal = "-",
        .vertical = "|",
        .left_t = "+",
        .right_t = "+",
        .top_t = "+",
        .bottom_t = "+",
        .cross = "+",
    };

    pub fn fromStyle(style: BorderStyle) BorderChars {
        return switch (style) {
            .none => ascii,
            .single => single,
            .double => double,
            .rounded => rounded,
            .thick => thick,
            .ascii => ascii,
            .custom => single,
        };
    }
};

pub const Border = struct {
    top: bool = true,
    bottom: bool = true,
    left: bool = true,
    right: bool = true,
    style: BorderStyle = .single,
    chars: BorderChars = BorderChars.single,

    pub fn all(style: BorderStyle) Border {
        return .{
            .style = style,
            .chars = BorderChars.fromStyle(style),
        };
    }

    pub fn none() Border {
        return .{
            .top = false,
            .bottom = false,
            .left = false,
            .right = false,
            .style = .none,
        };
    }

    pub fn horizontal(style: BorderStyle) Border {
        return .{
            .left = false,
            .right = false,
            .style = style,
            .chars = BorderChars.fromStyle(style),
        };
    }

    pub fn vertical(style: BorderStyle) Border {
        return .{
            .top = false,
            .bottom = false,
            .style = style,
            .chars = BorderChars.fromStyle(style),
        };
    }
};
