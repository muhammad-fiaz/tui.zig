//! Border side masks, presets, custom border symbol sets, and collapsing merge logic.

const std = @import("std");
const symbols = @import("symbols.zig");
const testing = std.testing;

/// Bitmask selecting which sides of a `Block` or container render borders.
pub const BorderSides = packed struct(u4) {
    top: bool = false,
    right: bool = false,
    bottom: bool = false,
    left: bool = false,

    /// No borders enabled.
    pub const none: BorderSides = .{};
    /// All four borders enabled.
    pub const all: BorderSides = .{ .top = true, .right = true, .bottom = true, .left = true };
    /// Top and bottom borders enabled.
    pub const horizontal: BorderSides = .{ .top = true, .bottom = true };
    /// Left and right borders enabled.
    pub const vertical: BorderSides = .{ .left = true, .right = true };

    /// Bitwise union of two border masks.
    pub fn unionWith(a: BorderSides, b: BorderSides) BorderSides {
        return @bitCast(@as(u4, @bitCast(a)) | @as(u4, @bitCast(b)));
    }

    /// True when at least one side is enabled.
    pub fn any(self: BorderSides) bool {
        return @as(u4, @bitCast(self)) != 0;
    }
};

/// Complete set of 8 glyphs required to draw a rectangular box border.
pub const BorderSet = struct {
    top_left: []const u8,
    top_right: []const u8,
    bottom_left: []const u8,
    bottom_right: []const u8,
    vertical_left: []const u8,
    vertical_right: []const u8,
    horizontal_top: []const u8,
    horizontal_bottom: []const u8,

    /// Standard single-line box drawing border.
    pub const plain = fromLineSet(symbols.line.normal);
    /// Rounded single-line box drawing border.
    pub const rounded = fromLineSet(symbols.line.rounded);
    /// Double-line box drawing border.
    pub const double = fromLineSet(symbols.line.double);
    /// Thick/heavy single-line box drawing border.
    pub const thick = fromLineSet(symbols.line.thick);
    /// ASCII `+-|` fallback border.
    pub const ascii = fromLineSet(symbols.line.ascii);
    /// Light double-dashed border.
    pub const light_double_dashed = fromLineSet(symbols.line.light_double_dashed);
    /// Heavy double-dashed border.
    pub const heavy_double_dashed = fromLineSet(symbols.line.heavy_double_dashed);
    /// Light triple-dashed border.
    pub const light_triple_dashed = fromLineSet(symbols.line.light_triple_dashed);
    /// Heavy triple-dashed border.
    pub const heavy_triple_dashed = fromLineSet(symbols.line.heavy_triple_dashed);
    /// Light quadruple-dashed border.
    pub const light_quadruple_dashed = fromLineSet(symbols.line.light_quadruple_dashed);
    /// Heavy quadruple-dashed border.
    pub const heavy_quadruple_dashed = fromLineSet(symbols.line.heavy_quadruple_dashed);

    /// Quadrant border outside the inner block by half a cell.
    pub const quadrant_outside: BorderSet = .{
        .top_left = "▛",
        .top_right = "▜",
        .bottom_left = "▙",
        .bottom_right = "▟",
        .vertical_left = "▌",
        .vertical_right = "▐",
        .horizontal_top = "▀",
        .horizontal_bottom = "▄",
    };

    /// Quadrant border inside the edge by half a cell.
    pub const quadrant_inside: BorderSet = .{
        .top_left = "▗",
        .top_right = "▖",
        .bottom_left = "▝",
        .bottom_right = "▘",
        .vertical_left = "▐",
        .vertical_right = "▌",
        .horizontal_top = "▄",
        .horizontal_bottom = "▀",
    };

    /// Wide 1/8-block border.
    pub const one_eighth_wide: BorderSet = .{
        .top_left = "▁",
        .top_right = "▁",
        .bottom_left = "▔",
        .bottom_right = "▔",
        .vertical_left = "▏",
        .vertical_right = "▕",
        .horizontal_top = "▁",
        .horizontal_bottom = "▔",
    };

    /// Tall 1/8-block border.
    pub const one_eighth_tall: BorderSet = .{
        .top_left = "▕",
        .top_right = "▏",
        .bottom_left = "▕",
        .bottom_right = "▏",
        .vertical_left = "▕",
        .vertical_right = "▏",
        .horizontal_top = "▔",
        .horizontal_bottom = "▁",
    };

    /// Solid full-block border.
    pub const full: BorderSet = .{
        .top_left = "█",
        .top_right = "█",
        .bottom_left = "█",
        .bottom_right = "█",
        .vertical_left = "█",
        .vertical_right = "█",
        .horizontal_top = "█",
        .horizontal_bottom = "█",
    };

    /// Blank border set preserving layout insets without visible glyphs.
    pub const empty: BorderSet = .{
        .top_left = " ",
        .top_right = " ",
        .bottom_left = " ",
        .bottom_right = " ",
        .vertical_left = " ",
        .vertical_right = " ",
        .horizontal_top = " ",
        .horizontal_bottom = " ",
    };

    /// Converts a `symbols.LineSet` into a `BorderSet`.
    pub fn fromLineSet(set: symbols.LineSet) BorderSet {
        return .{
            .top_left = set.top_left,
            .top_right = set.top_right,
            .bottom_left = set.bottom_left,
            .bottom_right = set.bottom_right,
            .vertical_left = set.vertical,
            .vertical_right = set.vertical,
            .horizontal_top = set.horizontal,
            .horizontal_bottom = set.horizontal,
        };
    }
};

/// Named border rendering style presets.
pub const BorderType = enum {
    plain,
    rounded,
    double,
    thick,
    ascii,
    light_double_dashed,
    heavy_double_dashed,
    light_triple_dashed,
    heavy_triple_dashed,
    light_quadruple_dashed,
    heavy_quadruple_dashed,
    quadrant_outside,
    quadrant_inside,
    one_eighth_wide,
    one_eighth_tall,
    full,
    empty,

    /// Resolves this `BorderType` to its corresponding `BorderSet`.
    pub fn symbolsSet(self: BorderType) BorderSet {
        return switch (self) {
            .plain => BorderSet.plain,
            .rounded => BorderSet.rounded,
            .double => BorderSet.double,
            .thick => BorderSet.thick,
            .ascii => BorderSet.ascii,
            .light_double_dashed => BorderSet.light_double_dashed,
            .heavy_double_dashed => BorderSet.heavy_double_dashed,
            .light_triple_dashed => BorderSet.light_triple_dashed,
            .heavy_triple_dashed => BorderSet.heavy_triple_dashed,
            .light_quadruple_dashed => BorderSet.light_quadruple_dashed,
            .heavy_quadruple_dashed => BorderSet.heavy_quadruple_dashed,
            .quadrant_outside => BorderSet.quadrant_outside,
            .quadrant_inside => BorderSet.quadrant_inside,
            .one_eighth_wide => BorderSet.one_eighth_wide,
            .one_eighth_tall => BorderSet.one_eighth_tall,
            .full => BorderSet.full,
            .empty => BorderSet.empty,
        };
    }
};

/// Strategy applied when overlapping borders share cells (border collapsing).
pub const MergeStrategy = enum {
    /// Overwrites the existing cell glyph with the incoming glyph.
    replace,
    /// Combines box-drawing segments only when an exact Unicode composite glyph exists.
    exact,
    /// Combines box-drawing segments, approximating unsupported style combinations.
    fuzzy,
};

const Segment = enum(u2) {
    none = 0,
    light = 1,
    heavy = 2,
    double = 3,
};

const BoxEdges = struct {
    up: Segment = .none,
    right: Segment = .none,
    down: Segment = .none,
    left: Segment = .none,

    fn isEmpty(self: BoxEdges) bool {
        return self.up == .none and self.right == .none and self.down == .none and self.left == .none;
    }

    fn key(self: BoxEdges) u8 {
        return (@as(u8, @backingInt(self.up)) << 6) |
            (@as(u8, @backingInt(self.right)) << 4) |
            (@as(u8, @backingInt(self.down)) << 2) |
            @as(u8, @backingInt(self.left));
    }
};

const BoxEntry = struct {
    glyph: []const u8,
    edges: BoxEdges,
    exact: bool = true,
};

const l = Segment.light;
const h = Segment.heavy;
const d = Segment.double;
const n = Segment.none;

// Unicode Box Drawing characters mapped to directional segment weights.
const box_table = [_]BoxEntry{
    .{ .glyph = "─", .edges = .{ .left = l, .right = l } },
    .{ .glyph = "━", .edges = .{ .left = h, .right = h } },
    .{ .glyph = "│", .edges = .{ .up = l, .down = l } },
    .{ .glyph = "┃", .edges = .{ .up = h, .down = h } },
    .{ .glyph = "┌", .edges = .{ .right = l, .down = l } },
    .{ .glyph = "┍", .edges = .{ .right = h, .down = l } },
    .{ .glyph = "┎", .edges = .{ .right = l, .down = h } },
    .{ .glyph = "┏", .edges = .{ .right = h, .down = h } },
    .{ .glyph = "┐", .edges = .{ .left = l, .down = l } },
    .{ .glyph = "┑", .edges = .{ .left = h, .down = l } },
    .{ .glyph = "┒", .edges = .{ .left = l, .down = h } },
    .{ .glyph = "┓", .edges = .{ .left = h, .down = h } },
    .{ .glyph = "└", .edges = .{ .up = l, .right = l } },
    .{ .glyph = "┕", .edges = .{ .up = l, .right = h } },
    .{ .glyph = "┖", .edges = .{ .up = h, .right = l } },
    .{ .glyph = "┗", .edges = .{ .up = h, .right = h } },
    .{ .glyph = "┘", .edges = .{ .up = l, .left = l } },
    .{ .glyph = "┙", .edges = .{ .up = l, .left = h } },
    .{ .glyph = "┚", .edges = .{ .up = h, .left = l } },
    .{ .glyph = "┛", .edges = .{ .up = h, .left = h } },
    .{ .glyph = "├", .edges = .{ .up = l, .down = l, .right = l } },
    .{ .glyph = "┝", .edges = .{ .up = l, .down = l, .right = h } },
    .{ .glyph = "┞", .edges = .{ .up = h, .down = l, .right = l } },
    .{ .glyph = "┟", .edges = .{ .up = l, .down = h, .right = l } },
    .{ .glyph = "┠", .edges = .{ .up = h, .down = h, .right = l } },
    .{ .glyph = "┡", .edges = .{ .up = h, .down = l, .right = h } },
    .{ .glyph = "┢", .edges = .{ .up = l, .down = h, .right = h } },
    .{ .glyph = "┣", .edges = .{ .up = h, .down = h, .right = h } },
    .{ .glyph = "┤", .edges = .{ .up = l, .down = l, .left = l } },
    .{ .glyph = "┥", .edges = .{ .up = l, .down = l, .left = h } },
    .{ .glyph = "┦", .edges = .{ .up = h, .down = l, .left = l } },
    .{ .glyph = "┧", .edges = .{ .up = l, .down = h, .left = l } },
    .{ .glyph = "┨", .edges = .{ .up = h, .down = h, .left = l } },
    .{ .glyph = "┩", .edges = .{ .up = h, .down = l, .left = h } },
    .{ .glyph = "┪", .edges = .{ .up = l, .down = h, .left = h } },
    .{ .glyph = "┫", .edges = .{ .up = h, .down = h, .left = h } },
    .{ .glyph = "┬", .edges = .{ .left = l, .right = l, .down = l } },
    .{ .glyph = "┭", .edges = .{ .left = h, .right = l, .down = l } },
    .{ .glyph = "┮", .edges = .{ .left = l, .right = h, .down = l } },
    .{ .glyph = "┯", .edges = .{ .left = h, .right = h, .down = l } },
    .{ .glyph = "┰", .edges = .{ .left = l, .right = l, .down = h } },
    .{ .glyph = "┱", .edges = .{ .left = h, .right = l, .down = h } },
    .{ .glyph = "┲", .edges = .{ .left = l, .right = h, .down = h } },
    .{ .glyph = "┳", .edges = .{ .left = h, .right = h, .down = h } },
    .{ .glyph = "┴", .edges = .{ .left = l, .right = l, .up = l } },
    .{ .glyph = "┵", .edges = .{ .left = h, .right = l, .up = l } },
    .{ .glyph = "┶", .edges = .{ .left = l, .right = h, .up = l } },
    .{ .glyph = "┷", .edges = .{ .left = h, .right = h, .up = l } },
    .{ .glyph = "┸", .edges = .{ .left = l, .right = l, .up = h } },
    .{ .glyph = "┹", .edges = .{ .left = h, .right = l, .up = h } },
    .{ .glyph = "┺", .edges = .{ .left = l, .right = h, .up = h } },
    .{ .glyph = "┻", .edges = .{ .left = h, .right = h, .up = h } },
    .{ .glyph = "┼", .edges = .{ .up = l, .right = l, .down = l, .left = l } },
    .{ .glyph = "┽", .edges = .{ .up = l, .right = l, .down = l, .left = h } },
    .{ .glyph = "┾", .edges = .{ .up = l, .right = h, .down = l, .left = l } },
    .{ .glyph = "┿", .edges = .{ .up = l, .right = h, .down = l, .left = h } },
    .{ .glyph = "╀", .edges = .{ .up = h, .right = l, .down = l, .left = l } },
    .{ .glyph = "╁", .edges = .{ .up = l, .right = l, .down = h, .left = l } },
    .{ .glyph = "╂", .edges = .{ .up = h, .right = l, .down = h, .left = l } },
    .{ .glyph = "╃", .edges = .{ .up = h, .right = l, .down = l, .left = h } },
    .{ .glyph = "╄", .edges = .{ .up = h, .right = h, .down = l, .left = l } },
    .{ .glyph = "╅", .edges = .{ .up = l, .right = l, .down = h, .left = h } },
    .{ .glyph = "╆", .edges = .{ .up = l, .right = h, .down = h, .left = l } },
    .{ .glyph = "╇", .edges = .{ .up = h, .right = h, .down = l, .left = h } },
    .{ .glyph = "╈", .edges = .{ .up = l, .right = h, .down = h, .left = h } },
    .{ .glyph = "╉", .edges = .{ .up = h, .right = l, .down = h, .left = h } },
    .{ .glyph = "╊", .edges = .{ .up = h, .right = h, .down = h, .left = l } },
    .{ .glyph = "╋", .edges = .{ .up = h, .right = h, .down = h, .left = h } },
    .{ .glyph = "═", .edges = .{ .left = d, .right = d } },
    .{ .glyph = "║", .edges = .{ .up = d, .down = d } },
    .{ .glyph = "╒", .edges = .{ .right = d, .down = l } },
    .{ .glyph = "╓", .edges = .{ .right = l, .down = d } },
    .{ .glyph = "╔", .edges = .{ .right = d, .down = d } },
    .{ .glyph = "╕", .edges = .{ .left = d, .down = l } },
    .{ .glyph = "╖", .edges = .{ .left = l, .down = d } },
    .{ .glyph = "╗", .edges = .{ .left = d, .down = d } },
    .{ .glyph = "╘", .edges = .{ .up = l, .right = d } },
    .{ .glyph = "╙", .edges = .{ .up = d, .right = l } },
    .{ .glyph = "╚", .edges = .{ .up = d, .right = d } },
    .{ .glyph = "╛", .edges = .{ .up = l, .left = d } },
    .{ .glyph = "╜", .edges = .{ .up = d, .left = l } },
    .{ .glyph = "╝", .edges = .{ .up = d, .left = d } },
    .{ .glyph = "╞", .edges = .{ .up = l, .down = l, .right = d } },
    .{ .glyph = "╟", .edges = .{ .up = d, .down = d, .right = l } },
    .{ .glyph = "╠", .edges = .{ .up = d, .down = d, .right = d } },
    .{ .glyph = "╡", .edges = .{ .up = l, .down = l, .left = d } },
    .{ .glyph = "╢", .edges = .{ .up = d, .down = d, .left = l } },
    .{ .glyph = "╣", .edges = .{ .up = d, .down = d, .left = d } },
    .{ .glyph = "╤", .edges = .{ .left = d, .right = d, .down = l } },
    .{ .glyph = "╥", .edges = .{ .left = l, .right = l, .down = d } },
    .{ .glyph = "╦", .edges = .{ .left = d, .right = d, .down = d } },
    .{ .glyph = "╧", .edges = .{ .left = d, .right = d, .up = l } },
    .{ .glyph = "╨", .edges = .{ .left = l, .right = l, .up = d } },
    .{ .glyph = "╩", .edges = .{ .left = d, .right = d, .up = d } },
    .{ .glyph = "╪", .edges = .{ .up = l, .down = l, .left = d, .right = d } },
    .{ .glyph = "╫", .edges = .{ .up = d, .down = d, .left = l, .right = l } },
    .{ .glyph = "╬", .edges = .{ .up = d, .down = d, .left = d, .right = d } },
    // Rounded and dashed glyphs map for fuzzy collapsing only.
    .{ .glyph = "╭", .edges = .{ .right = l, .down = l }, .exact = false },
    .{ .glyph = "╮", .edges = .{ .left = l, .down = l }, .exact = false },
    .{ .glyph = "╯", .edges = .{ .up = l, .left = l }, .exact = false },
    .{ .glyph = "╰", .edges = .{ .up = l, .right = l }, .exact = false },
    .{ .glyph = "╌", .edges = .{ .left = l, .right = l }, .exact = false },
    .{ .glyph = "┄", .edges = .{ .left = l, .right = l }, .exact = false },
    .{ .glyph = "┈", .edges = .{ .left = l, .right = l }, .exact = false },
    .{ .glyph = "╍", .edges = .{ .left = h, .right = h }, .exact = false },
    .{ .glyph = "┅", .edges = .{ .left = h, .right = h }, .exact = false },
    .{ .glyph = "┉", .edges = .{ .left = h, .right = h }, .exact = false },
    .{ .glyph = "╎", .edges = .{ .up = l, .down = l }, .exact = false },
    .{ .glyph = "┆", .edges = .{ .up = l, .down = l }, .exact = false },
    .{ .glyph = "┊", .edges = .{ .up = l, .down = l }, .exact = false },
    .{ .glyph = "╏", .edges = .{ .up = h, .down = h }, .exact = false },
    .{ .glyph = "┇", .edges = .{ .up = h, .down = h }, .exact = false },
    .{ .glyph = "┋", .edges = .{ .up = h, .down = h }, .exact = false },
    .{ .glyph = "╴", .edges = .{ .left = l } },
    .{ .glyph = "╵", .edges = .{ .up = l } },
    .{ .glyph = "╶", .edges = .{ .right = l } },
    .{ .glyph = "╷", .edges = .{ .down = l } },
    .{ .glyph = "╸", .edges = .{ .left = h } },
    .{ .glyph = "╹", .edges = .{ .up = h } },
    .{ .glyph = "╺", .edges = .{ .right = h } },
    .{ .glyph = "╻", .edges = .{ .down = h } },
    .{ .glyph = "╼", .edges = .{ .left = l, .right = h } },
    .{ .glyph = "╽", .edges = .{ .up = l, .down = h } },
    .{ .glyph = "╾", .edges = .{ .left = h, .right = l } },
    .{ .glyph = "╿", .edges = .{ .up = h, .down = l } },
};

const lookup_by_key = blk: {
    var table: [256]?[]const u8 = @splat(null);
    for (box_table) |entry| {
        if (entry.exact) {
            table[entry.edges.key()] = entry.glyph;
        }
    }
    break :blk table;
};

fn decodeBoxEdges(glyph: []const u8, exact_only: bool) ?BoxEdges {
    for (box_table) |entry| {
        if (exact_only and !entry.exact) continue;
        if (std.mem.eql(u8, entry.glyph, glyph)) return entry.edges;
    }
    return null;
}

fn combineSegment(prev: Segment, next: Segment) Segment {
    return if (next != n) next else prev;
}

fn normalizeFuzzy(edges: BoxEdges, prefer_double: bool) BoxEdges {
    var out = edges;
    const fields = .{ "up", "right", "down", "left" };
    inline for (fields) |f| {
        const val = @field(out, f);
        if (val != n) {
            @field(out, f) = if (prefer_double) .double else .heavy;
        }
    }
    return out;
}

fn coerceToLight(edges: BoxEdges) BoxEdges {
    var out = edges;
    const fields = .{ "up", "right", "down", "left" };
    inline for (fields) |f| {
        if (@field(out, f) != .none) @field(out, f) = .light;
    }
    return out;
}

/// Merges `incoming` over `existing` according to `strategy`.
pub fn mergeSymbol(existing: []const u8, incoming: []const u8, strategy: MergeStrategy) []const u8 {
    if (strategy == .replace) return incoming;

    const exact_only = strategy == .exact;
    const prev = decodeBoxEdges(existing, exact_only) orelse return incoming;
    const next = decodeBoxEdges(incoming, exact_only) orelse return incoming;

    const combined: BoxEdges = .{
        .up = combineSegment(prev.up, next.up),
        .right = combineSegment(prev.right, next.right),
        .down = combineSegment(prev.down, next.down),
        .left = combineSegment(prev.left, next.left),
    };
    if (combined.isEmpty()) return incoming;

    if (lookup_by_key[combined.key()]) |glyph| return glyph;
    if (strategy == .exact) return incoming;

    const prefer_double = next.up == .double or next.right == .double or next.down == .double or next.left == .double;
    const harmonized = normalizeFuzzy(combined, prefer_double);
    if (lookup_by_key[harmonized.key()]) |glyph| return glyph;

    const light = coerceToLight(combined);
    return lookup_by_key[light.key()] orelse incoming;
}

test "border merge combines box glyphs cleanly" {
    try testing.expectEqualStrings("━", mergeSymbol("│", "━", .replace));
    try testing.expectEqualStrings("┼", mergeSymbol("│", "─", .exact));
    try testing.expectEqualStrings("╆", mergeSymbol("┘", "┏", .exact));
    try testing.expectEqualStrings("╔", mergeSymbol("┘", "╔", .exact));
    try testing.expectEqualStrings("╬", mergeSymbol("┘", "╔", .fuzzy));
    try testing.expectEqualStrings("┼", mergeSymbol("╭", "┘", .fuzzy));
}

test "border types return valid symbol sets" {
    const rounded = BorderType.rounded.symbolsSet();
    try testing.expectEqualStrings("╭", rounded.top_left);
    try testing.expectEqualStrings("╯", rounded.bottom_right);
    try testing.expect(BorderSides.all.any());
    try testing.expect(!BorderSides.none.any());
}
