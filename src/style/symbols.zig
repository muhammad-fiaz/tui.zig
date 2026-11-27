//! Built-in Unicode and ASCII symbol sets for borders, bars, charts, and widgets.

const std = @import("std");
const testing = std.testing;

/// Line-drawing character set used for borders and separators.
pub const LineSet = struct {
    vertical: []const u8,
    horizontal: []const u8,
    top_right: []const u8,
    top_left: []const u8,
    bottom_right: []const u8,
    bottom_left: []const u8,
    vertical_left: []const u8,
    vertical_right: []const u8,
    horizontal_down: []const u8,
    horizontal_up: []const u8,
    cross: []const u8,
};

/// Standard box-drawing line sets.
pub const line = struct {
    pub const normal: LineSet = .{
        .vertical = "│",
        .horizontal = "─",
        .top_right = "┐",
        .top_left = "┌",
        .bottom_right = "┘",
        .bottom_left = "└",
        .vertical_left = "┤",
        .vertical_right = "├",
        .horizontal_down = "┬",
        .horizontal_up = "┴",
        .cross = "┼",
    };

    pub const rounded: LineSet = .{
        .vertical = "│",
        .horizontal = "─",
        .top_right = "╮",
        .top_left = "╭",
        .bottom_right = "╯",
        .bottom_left = "╰",
        .vertical_left = "┤",
        .vertical_right = "├",
        .horizontal_down = "┬",
        .horizontal_up = "┴",
        .cross = "┼",
    };

    pub const double: LineSet = .{
        .vertical = "║",
        .horizontal = "═",
        .top_right = "╗",
        .top_left = "╔",
        .bottom_right = "╝",
        .bottom_left = "╚",
        .vertical_left = "╣",
        .vertical_right = "╠",
        .horizontal_down = "╦",
        .horizontal_up = "╩",
        .cross = "╬",
    };

    pub const thick: LineSet = .{
        .vertical = "┃",
        .horizontal = "━",
        .top_right = "┓",
        .top_left = "┏",
        .bottom_right = "┛",
        .bottom_left = "┗",
        .vertical_left = "┫",
        .vertical_right = "┣",
        .horizontal_down = "┳",
        .horizontal_up = "┻",
        .cross = "╋",
    };

    pub const ascii: LineSet = .{
        .vertical = "|",
        .horizontal = "-",
        .top_right = "+",
        .top_left = "+",
        .bottom_right = "+",
        .bottom_left = "+",
        .vertical_left = "+",
        .vertical_right = "+",
        .horizontal_down = "+",
        .horizontal_up = "+",
        .cross = "+",
    };

    pub const light_double_dashed: LineSet = .{
        .vertical = "╎",
        .horizontal = "╌",
        .top_right = normal.top_right,
        .top_left = normal.top_left,
        .bottom_right = normal.bottom_right,
        .bottom_left = normal.bottom_left,
        .vertical_left = normal.vertical_left,
        .vertical_right = normal.vertical_right,
        .horizontal_down = normal.horizontal_down,
        .horizontal_up = normal.horizontal_up,
        .cross = normal.cross,
    };

    pub const heavy_double_dashed: LineSet = .{
        .vertical = "╏",
        .horizontal = "╍",
        .top_right = thick.top_right,
        .top_left = thick.top_left,
        .bottom_right = thick.bottom_right,
        .bottom_left = thick.bottom_left,
        .vertical_left = thick.vertical_left,
        .vertical_right = thick.vertical_right,
        .horizontal_down = thick.horizontal_down,
        .horizontal_up = thick.horizontal_up,
        .cross = thick.cross,
    };

    pub const light_triple_dashed: LineSet = .{
        .vertical = "┆",
        .horizontal = "┄",
        .top_right = normal.top_right,
        .top_left = normal.top_left,
        .bottom_right = normal.bottom_right,
        .bottom_left = normal.bottom_left,
        .vertical_left = normal.vertical_left,
        .vertical_right = normal.vertical_right,
        .horizontal_down = normal.horizontal_down,
        .horizontal_up = normal.horizontal_up,
        .cross = normal.cross,
    };

    pub const heavy_triple_dashed: LineSet = .{
        .vertical = "┇",
        .horizontal = "┅",
        .top_right = thick.top_right,
        .top_left = thick.top_left,
        .bottom_right = thick.bottom_right,
        .bottom_left = thick.bottom_left,
        .vertical_left = thick.vertical_left,
        .vertical_right = thick.vertical_right,
        .horizontal_down = thick.horizontal_down,
        .horizontal_up = thick.horizontal_up,
        .cross = thick.cross,
    };

    pub const light_quadruple_dashed: LineSet = .{
        .vertical = "┊",
        .horizontal = "┈",
        .top_right = normal.top_right,
        .top_left = normal.top_left,
        .bottom_right = normal.bottom_right,
        .bottom_left = normal.bottom_left,
        .vertical_left = normal.vertical_left,
        .vertical_right = normal.vertical_right,
        .horizontal_down = normal.horizontal_down,
        .horizontal_up = normal.horizontal_up,
        .cross = normal.cross,
    };

    pub const heavy_quadruple_dashed: LineSet = .{
        .vertical = "┋",
        .horizontal = "┉",
        .top_right = thick.top_right,
        .top_left = thick.top_left,
        .bottom_right = thick.bottom_right,
        .bottom_left = thick.bottom_left,
        .vertical_left = thick.vertical_left,
        .vertical_right = thick.vertical_right,
        .horizontal_down = thick.horizontal_down,
        .horizontal_up = thick.horizontal_up,
        .cross = thick.cross,
    };
};

/// Vertical block elements for gauges, sparklines, and bar charts.
pub const block = struct {
    pub const full = "█";
    pub const seven_eighths = "▇";
    pub const three_quarters = "▆";
    pub const five_eighths = "▅";
    pub const half = "▄";
    pub const three_eighths = "▃";
    pub const one_quarter = "▂";
    pub const one_eighth = "▁";

    /// Horizontal block elements (left-aligned) for horizontal progress bars.
    pub const horizontal_eighths = [9][]const u8{
        " ",
        "▏",
        "▎",
        "▍",
        "▌",
        "▋",
        "▊",
        "▉",
        "█",
    };

    /// Shade characters for fills and shadows.
    pub const light_shade = "░";
    pub const medium_shade = "▒";
    pub const dark_shade = "▓";
};

/// 9-level vertical bar glyph set.
pub const BarSet = struct {
    full: []const u8,
    seven_eighths: []const u8,
    three_quarters: []const u8,
    five_eighths: []const u8,
    half: []const u8,
    three_eighths: []const u8,
    one_quarter: []const u8,
    one_eighth: []const u8,
    empty: []const u8,

    /// Maps an index in `0..8` (`0` = empty, `8` = full) to its symbol.
    pub fn level(self: BarSet, step: u8) []const u8 {
        return switch (step) {
            0 => self.empty,
            1 => self.one_eighth,
            2 => self.one_quarter,
            3 => self.three_eighths,
            4 => self.half,
            5 => self.five_eighths,
            6 => self.three_quarters,
            7 => self.seven_eighths,
            else => self.full,
        };
    }
};

/// Bar symbol presets.
pub const bar = struct {
    pub const nine_levels: BarSet = .{
        .full = block.full,
        .seven_eighths = block.seven_eighths,
        .three_quarters = block.three_quarters,
        .five_eighths = block.five_eighths,
        .half = block.half,
        .three_eighths = block.three_eighths,
        .one_quarter = block.one_quarter,
        .one_eighth = block.one_eighth,
        .empty = " ",
    };

    pub const three_levels: BarSet = .{
        .full = block.full,
        .seven_eighths = block.full,
        .three_quarters = block.half,
        .five_eighths = block.half,
        .half = block.half,
        .three_eighths = block.half,
        .one_quarter = block.half,
        .one_eighth = " ",
        .empty = " ",
    };

    pub const ascii_levels: BarSet = .{
        .full = "#",
        .seven_eighths = "#",
        .three_quarters = "=",
        .five_eighths = "=",
        .half = "=",
        .three_eighths = "-",
        .one_quarter = "-",
        .one_eighth = ".",
        .empty = " ",
    };
};

/// Scrollbar symbol set.
pub const ScrollbarSet = struct {
    track: []const u8,
    thumb: []const u8,
    begin: []const u8,
    end: []const u8,
};

/// Scrollbar symbol presets.
pub const scrollbar = struct {
    pub const vertical: ScrollbarSet = .{
        .track = line.normal.vertical,
        .thumb = block.full,
        .begin = "↑",
        .end = "↓",
    };
    pub const horizontal: ScrollbarSet = .{
        .track = line.normal.horizontal,
        .thumb = block.full,
        .begin = "←",
        .end = "→",
    };
    pub const double_vertical: ScrollbarSet = .{
        .track = line.double.vertical,
        .thumb = block.full,
        .begin = "▲",
        .end = "▼",
    };
    pub const double_horizontal: ScrollbarSet = .{
        .track = line.double.horizontal,
        .thumb = block.full,
        .begin = "◄",
        .end = "►",
    };
};

/// Checkbox symbol sets.
pub const CheckboxSet = struct {
    checked: []const u8,
    unchecked: []const u8,
    indeterminate: []const u8,
};

pub const checkbox = struct {
    pub const unicode: CheckboxSet = .{ .checked = "[✓]", .unchecked = "[ ]", .indeterminate = "[-]" };
    pub const boxed: CheckboxSet = .{ .checked = "☑", .unchecked = "☐", .indeterminate = "⊟" };
    pub const ascii: CheckboxSet = .{ .checked = "[x]", .unchecked = "[ ]", .indeterminate = "[-]" };
};

/// Radio button symbol sets.
pub const RadioSet = struct {
    selected: []const u8,
    unselected: []const u8,
};

pub const radio = struct {
    pub const unicode: RadioSet = .{ .selected = "(●)", .unselected = "( )" };
    pub const circle: RadioSet = .{ .selected = "◉", .unselected = "○" };
    pub const ascii: RadioSet = .{ .selected = "(*)", .unselected = "( )" };
};

/// Tree guide symbol sets.
pub const TreeSet = struct {
    branch: []const u8,
    last_branch: []const u8,
    vertical: []const u8,
    empty: []const u8,
    expanded: []const u8,
    collapsed: []const u8,
    leaf: []const u8,
};

pub const tree = struct {
    pub const unicode: TreeSet = .{
        .branch = "├─ ",
        .last_branch = "└─ ",
        .vertical = "│  ",
        .empty = "   ",
        .expanded = "▾ ",
        .collapsed = "▸ ",
        .leaf = "  ",
    };
    pub const rounded: TreeSet = .{
        .branch = "├─ ",
        .last_branch = "╰─ ",
        .vertical = "│  ",
        .empty = "   ",
        .expanded = "▾ ",
        .collapsed = "▸ ",
        .leaf = "  ",
    };
    pub const ascii: TreeSet = .{
        .branch = "|- ",
        .last_branch = "`- ",
        .vertical = "|  ",
        .empty = "   ",
        .expanded = "v ",
        .collapsed = "> ",
        .leaf = "  ",
    };
};

/// Spinner frame presets for progress/loading indicators.
pub const spinner = struct {
    pub const dots = [_][]const u8{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" };
    pub const line_frames = [_][]const u8{ "-", "\\", "|", "/" };
    pub const arc = [_][]const u8{ "◜", "◠", "◝", "◞", "◡", "◟" };
    pub const bounce = [_][]const u8{ "⠁", "⠂", "⠄", "⠂" };
    pub const pulse = [_][]const u8{ "█", "▓", "▒", "░", "▒", "▓" };
};

/// Canvas/chart drawing marker resolution mode.
pub const Marker = enum {
    dot,
    block,
    half_block,
    braille,
    quadrant,
    bar,
};

/// Row-major bit-indexed 2x4 Braille Unicode codepoint table (`U+2800..U+28FF`).
/// Bit layout per 2x4 cell:
/// `(0,0)=0x01, (1,0)=0x08, (0,1)=0x02, (1,1)=0x10, (0,2)=0x04, (1,2)=0x20, (0,3)=0x40, (1,3)=0x80`.
pub const braille_dot_bits = [4][2]u8{
    .{ 0x01, 0x08 },
    .{ 0x02, 0x10 },
    .{ 0x04, 0x20 },
    .{ 0x40, 0x80 },
};

/// Encodes an 8-bit Braille dot mask (standard Unicode Braille ordering) into UTF-8.
pub fn encodeBrailleMask(mask: u8, out: *[3]u8) []const u8 {
    const codepoint: u21 = 0x2800 + @as(u21, mask);
    const len = std.unicode.utf8Encode(codepoint, out) catch unreachable;
    return out[0..len];
}

/// 2x2 Quadrant block characters indexed by `(tl << 3) | (tr << 2) | (bl << 1) | br`.
pub const quadrants = [16][]const u8{
    " ",
    "▗",
    "▖",
    "▄",
    "▝",
    "▐",
    "▞",
    "▟",
    "▘",
    "▚",
    "▌",
    "▙",
    "▀",
    "▜",
    "▛",
    "█",
};

/// Semantic UI icon glyphs supporting pure Unicode, strict ASCII, and Nerd Font presets.
pub const IconSet = struct {
    folder: []const u8,
    file: []const u8,
    check: []const u8,
    cross: []const u8,
    warn: []const u8,
    info: []const u8,
    search: []const u8,
    settings: []const u8,
    play: []const u8,
    pause: []const u8,
    stop: []const u8,
    refresh: []const u8,
    lock: []const u8,
    star: []const u8,
    chart: []const u8,
    image: []const u8,
    video: []const u8,
    terminal: []const u8,
};

pub const icons = struct {
    pub const unicode: IconSet = .{
        .folder = "▸",
        .file = "•",
        .check = "✓",
        .cross = "✖",
        .warn = "⚠",
        .info = "ℹ",
        .search = "⌕",
        .settings = "⚙",
        .play = "▶",
        .pause = "⏸",
        .stop = "■",
        .refresh = "↻",
        .lock = "🔒",
        .star = "★",
        .chart = "📊",
        .image = "🖼",
        .video = "🎬",
        .terminal = "⌘",
    };

    pub const ascii: IconSet = .{
        .folder = "+",
        .file = "-",
        .check = "[ok]",
        .cross = "[x]",
        .warn = "[!]",
        .info = "[i]",
        .search = "?",
        .settings = "*",
        .play = ">",
        .pause = "||",
        .stop = "[]",
        .refresh = "@",
        .lock = "#",
        .star = "*",
        .chart = "#",
        .image = "[img]",
        .video = "[vid]",
        .terminal = ">_",
    };

    pub const nerd: IconSet = .{
        .folder = "\u{f07b}",
        .file = "\u{f15b}",
        .check = "\u{f00c}",
        .cross = "\u{f00d}",
        .warn = "\u{f071}",
        .info = "\u{f05a}",
        .search = "\u{f002}",
        .settings = "\u{f013}",
        .play = "\u{f04b}",
        .pause = "\u{f04c}",
        .stop = "\u{f04d}",
        .refresh = "\u{f021}",
        .lock = "\u{f023}",
        .star = "\u{f005}",
        .chart = "\u{f080}",
        .image = "\u{f03e}",
        .video = "\u{f03d}",
        .terminal = "\u{f120}",
    };
};

test "braille mask encodes valid UTF-8" {
    var buf: [3]u8 = undefined;
    try testing.expectEqualStrings("⠀", encodeBrailleMask(0x00, &buf));
    try testing.expectEqualStrings("⣿", encodeBrailleMask(0xFF, &buf));
    try testing.expectEqualStrings("⠁", encodeBrailleMask(braille_dot_bits[0][0], &buf));
}

test "bar levels and quadrants cover range" {
    try testing.expectEqualStrings(" ", bar.nine_levels.level(0));
    try testing.expectEqualStrings("▁", bar.nine_levels.level(1));
    try testing.expectEqualStrings("█", bar.nine_levels.level(8));
    try testing.expectEqualStrings("█", quadrants[15]);
    try testing.expectEqualStrings(" ", quadrants[0]);
}
