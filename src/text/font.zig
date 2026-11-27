//! Custom bitmap / pixel font renderer (`BitmapFont`, `BitmapGlyph`, `FontRenderMode`).
//!
//! Supports:
//! - Full built-in printable ASCII (`0x20..0x7E`) in both compact `block_3x5` and crisp `sans_5x7`.
//! - Client-side custom font definitions via static `BitmapGlyph` lookup tables or dynamic `lookup_fn` callbacks
//!   supporting arbitrary Unicode codepoints (Cyrillic, Greek, Arabic, CJK, custom logo/icon glyphs).
//! - Multiple sub-cell resolutions: `.full_block` (`█`), `.half_block` (`▀▄█` — 2 vertical pixels per row),
//!   `.quadrant` (2x2), `.braille` (2x4), and `.custom` symbol cells.

const std = @import("std");
const grapheme = @import("grapheme.zig");
const testing = std.testing;

/// Single monochrome pixel bitmap glyph (`width <= 16`, `height <= 16`, MSB left-aligned in `rows`).
pub const BitmapGlyph = struct {
    codepoint: u21,
    width: u5 = 3,
    height: u5 = 5,
    /// Bitmask per row where MSB bit `(width - 1)` represents leftmost pixel (`x = 0`).
    rows: []const u16,

    /// Returns `true` when glyph pixel `(x, y)` is lit.
    pub fn pixelAt(self: BitmapGlyph, x: u16, y: u16) bool {
        if (x >= self.width or y >= self.height or y >= self.rows.len) return false;
        const shift: u4 = @intCast(self.width - 1 - x);
        return ((self.rows[y] >> shift) & 1) != 0;
    }
};

/// Sub-cell rasterization strategy used when painting a `BitmapFont` into a terminal cell grid.
pub const FontRenderMode = enum {
    /// Each font pixel maps to 1x1 cell using `pixel_char` (e.g. `"█"`).
    full_block,
    /// Packs 1x2 vertical bitmap pixels per terminal cell (`▀`, `▄`, `█`).
    half_block,
    /// Packs 2x2 bitmap pixels per terminal cell (`▖..▟`).
    quadrant,
    /// Packs 2x4 bitmap pixels per terminal cell (`⠁..⣿`).
    braille,
};

/// Client-extensible bitmap font definition.
pub const BitmapFont = struct {
    name: []const u8 = "default",
    default_width: u5 = 3,
    height: u5 = 5,
    letter_spacing: u16 = 1,
    line_spacing: u16 = 1,
    /// Optional client-provided sorted or linear slice of Unicode glyphs.
    glyphs: []const BitmapGlyph = &.{},
    /// Optional callback queried first for custom procedural/dynamic glyphs (arbitrary codepoints).
    lookup_fn: ?*const fn (cp: u21) ?BitmapGlyph = null,
    /// Optional fallback font when a codepoint is missing in `lookup_fn` and `glyphs`.
    fallback: ?*const BitmapFont = null,

    /// Compact 3x5 built-in bitmap font covering full printable ASCII (`0x20..0x7E`).
    pub const block_3x5: BitmapFont = .{
        .name = "block_3x5",
        .default_width = 3,
        .height = 5,
        .letter_spacing = 1,
        .lookup_fn = lookupAscii3x5,
    };

    /// Sharp 5x7 UI headline font covering ASCII letters, digits, and core punctuation.
    pub const sans_5x7: BitmapFont = .{
        .name = "sans_5x7",
        .default_width = 5,
        .height = 7,
        .letter_spacing = 1,
        .lookup_fn = lookupSans5x7,
        .fallback = &block_3x5,
    };

    /// Resolves a glyph for Unicode codepoint `cp`.
    pub fn resolveGlyph(self: *const BitmapFont, cp: u21) ?BitmapGlyph {
        if (self.lookup_fn) |fn_ptr| {
            if (fn_ptr(cp)) |g| return g;
        }
        for (self.glyphs) |g| {
            if (g.codepoint == cp) return g;
        }
        if (self.fallback) |fb| {
            return fb.resolveGlyph(cp);
        }
        return null;
    }

    /// Computes total bitmap pixel dimensions `(width_px, height_px)` for UTF-8 single-line `text`,
    /// honoring tallest resolved fallback/custom glyph height.
    pub fn measurePixels(self: *const BitmapFont, text: []const u8, scale_x: u16, scale_y: u16) struct { width: u16, height: u16 } {
        const sx = @max(@as(u16, 1), scale_x);
        const sy = @max(@as(u16, 1), scale_y);
        var w: u32 = 0;
        var max_h: u16 = self.height;
        var count: usize = 0;
        var git = grapheme.GraphemeIterator.init(text);
        while (git.next()) |g| {
            const cp = std.unicode.utf8Decode(g.slice[0..@min(g.slice.len, std.unicode.utf8ByteSequenceLength(g.slice[0]) catch 1)]) catch '?';
            if (cp == '\n' or cp == '\r') continue;
            if (count > 0) w += @as(u32, self.letter_spacing) * sx;
            const resolved = self.resolveGlyph(cp);
            const gw: u16 = if (resolved) |bg| bg.width else self.default_width;
            if (resolved) |bg| max_h = @max(max_h, bg.height);
            w += @as(u32, gw) * sx;
            count += 1;
        }
        return .{
            .width = @intCast(@min(std.math.maxInt(u16), w)),
            .height = @intCast(@min(std.math.maxInt(u16), @as(u32, max_h) * sy)),
        };
    }

    /// Computes terminal cell dimensions needed to display `text` under `mode`.
    pub fn measureCells(self: *const BitmapFont, text: []const u8, mode: FontRenderMode, scale_x: u16, scale_y: u16) struct { cols: u16, rows: u16 } {
        const px = self.measurePixels(text, scale_x, scale_y);
        const div: struct { u16, u16 } = switch (mode) {
            .full_block => .{ 1, 1 },
            .half_block => .{ 1, 2 },
            .quadrant => .{ 2, 2 },
            .braille => .{ 2, 4 },
        };
        return .{
            .cols = (px.width + div[0] - 1) / div[0],
            .rows = (px.height + div[1] - 1) / div[1],
        };
    }
};

fn glyph3x5(rows: *const [5]u16, cp: u21) BitmapGlyph {
    return .{ .codepoint = cp, .width = 3, .height = 5, .rows = rows };
}

fn glyph5x7(rows: *const [7]u16, cp: u21) BitmapGlyph {
    return .{ .codepoint = cp, .width = 5, .height = 7, .rows = rows };
}

const g3_space = [5]u16{ 0, 0, 0, 0, 0 };
const g3_A = [5]u16{ 0b010, 0b101, 0b111, 0b101, 0b101 };
const g3_B = [5]u16{ 0b110, 0b101, 0b110, 0b101, 0b110 };
const g3_C = [5]u16{ 0b011, 0b100, 0b100, 0b100, 0b011 };
const g3_D = [5]u16{ 0b110, 0b101, 0b101, 0b101, 0b110 };
const g3_E = [5]u16{ 0b111, 0b100, 0b110, 0b100, 0b111 };
const g3_F = [5]u16{ 0b111, 0b100, 0b110, 0b100, 0b100 };
const g3_G = [5]u16{ 0b011, 0b100, 0b101, 0b101, 0b011 };
const g3_H = [5]u16{ 0b101, 0b101, 0b111, 0b101, 0b101 };
const g3_I = [5]u16{ 0b111, 0b010, 0b010, 0b010, 0b111 };
const g3_J = [5]u16{ 0b001, 0b001, 0b001, 0b101, 0b010 };
const g3_K = [5]u16{ 0b101, 0b101, 0b110, 0b101, 0b101 };
const g3_L = [5]u16{ 0b100, 0b100, 0b100, 0b100, 0b111 };
const g3_M = [5]u16{ 0b101, 0b111, 0b101, 0b101, 0b101 };
const g3_N = [5]u16{ 0b101, 0b111, 0b111, 0b101, 0b101 };
const g3_O = [5]u16{ 0b111, 0b101, 0b101, 0b101, 0b111 };
const g3_P = [5]u16{ 0b110, 0b101, 0b110, 0b100, 0b100 };
const g3_Q = [5]u16{ 0b010, 0b101, 0b101, 0b111, 0b011 };
const g3_R = [5]u16{ 0b110, 0b101, 0b110, 0b101, 0b101 };
const g3_S = [5]u16{ 0b011, 0b100, 0b010, 0b001, 0b110 };
const g3_T = [5]u16{ 0b111, 0b010, 0b010, 0b010, 0b010 };
const g3_U = [5]u16{ 0b101, 0b101, 0b101, 0b101, 0b111 };
const g3_V = [5]u16{ 0b101, 0b101, 0b101, 0b101, 0b010 };
const g3_W = [5]u16{ 0b101, 0b101, 0b101, 0b111, 0b101 };
const g3_X = [5]u16{ 0b101, 0b101, 0b010, 0b101, 0b101 };
const g3_Y = [5]u16{ 0b101, 0b101, 0b010, 0b010, 0b010 };
const g3_Z = [5]u16{ 0b111, 0b001, 0b010, 0b100, 0b111 };
const g3_1 = [5]u16{ 0b010, 0b110, 0b010, 0b010, 0b111 };
const g3_2 = [5]u16{ 0b110, 0b001, 0b010, 0b100, 0b111 };
const g3_3 = [5]u16{ 0b110, 0b001, 0b110, 0b001, 0b110 };
const g3_4 = [5]u16{ 0b101, 0b101, 0b111, 0b001, 0b001 };
const g3_5 = [5]u16{ 0b111, 0b100, 0b110, 0b001, 0b110 };
const g3_6 = [5]u16{ 0b011, 0b100, 0b111, 0b101, 0b111 };
const g3_7 = [5]u16{ 0b111, 0b001, 0b010, 0b010, 0b010 };
const g3_8 = [5]u16{ 0b111, 0b101, 0b111, 0b101, 0b111 };
const g3_9 = [5]u16{ 0b111, 0b101, 0b111, 0b001, 0b110 };
const g3_dot = [5]u16{ 0b000, 0b000, 0b000, 0b000, 0b010 };
const g3_comma = [5]u16{ 0b000, 0b000, 0b000, 0b010, 0b100 };
const g3_dash = [5]u16{ 0b000, 0b000, 0b111, 0b000, 0b000 };
const g3_plus = [5]u16{ 0b000, 0b010, 0b111, 0b010, 0b000 };
const g3_under = [5]u16{ 0b000, 0b000, 0b000, 0b000, 0b111 };
const g3_colon = [5]u16{ 0b000, 0b010, 0b000, 0b010, 0b000 };
const g3_semi = [5]u16{ 0b000, 0b010, 0b000, 0b010, 0b100 };
const g3_bang = [5]u16{ 0b010, 0b010, 0b010, 0b000, 0b010 };
const g3_quest = [5]u16{ 0b110, 0b001, 0b010, 0b000, 0b010 };
const g3_slash = [5]u16{ 0b001, 0b001, 0b010, 0b100, 0b100 };
const g3_bslash = [5]u16{ 0b100, 0b100, 0b010, 0b001, 0b001 };
const g3_pct = [5]u16{ 0b101, 0b001, 0b010, 0b100, 0b101 };
const g3_lparen = [5]u16{ 0b010, 0b100, 0b100, 0b100, 0b010 };
const g3_rparen = [5]u16{ 0b010, 0b001, 0b001, 0b001, 0b010 };
const g3_lbrack = [5]u16{ 0b110, 0b100, 0b100, 0b100, 0b110 };
const g3_rbrack = [5]u16{ 0b011, 0b001, 0b001, 0b001, 0b011 };
const g3_eq = [5]u16{ 0b000, 0b111, 0b000, 0b111, 0b000 };
const g3_lt = [5]u16{ 0b001, 0b010, 0b100, 0b010, 0b001 };
const g3_gt = [5]u16{ 0b100, 0b010, 0b001, 0b010, 0b100 };
const g3_hash = [5]u16{ 0b101, 0b111, 0b101, 0b111, 0b101 };
const g3_star = [5]u16{ 0b101, 0b010, 0b111, 0b010, 0b101 };
const g3_at = [5]u16{ 0b011, 0b101, 0b111, 0b100, 0b011 };
const g3_amp = [5]u16{ 0b010, 0b101, 0b010, 0b101, 0b011 };
const g3_pipe = [5]u16{ 0b010, 0b010, 0b010, 0b010, 0b010 };
const g3_tilde = [5]u16{ 0b000, 0b011, 0b110, 0b000, 0b000 };
const g3_caret = [5]u16{ 0b010, 0b101, 0b000, 0b000, 0b000 };
const g3_quote = [5]u16{ 0b010, 0b010, 0b000, 0b000, 0b000 };
const g3_dquote = [5]u16{ 0b101, 0b101, 0b000, 0b000, 0b000 };
const g3_dollar = [5]u16{ 0b011, 0b110, 0b010, 0b011, 0b110 };

// Distinct compact lowercase forms where helpful while keeping legibility at 3x5.
const g3_a = [5]u16{ 0b000, 0b011, 0b101, 0b101, 0b011 };
const g3_b = [5]u16{ 0b100, 0b110, 0b101, 0b101, 0b110 };
const g3_c = [5]u16{ 0b000, 0b011, 0b100, 0b100, 0b011 };
const g3_d = [5]u16{ 0b001, 0b011, 0b101, 0b101, 0b011 };
const g3_e = [5]u16{ 0b000, 0b111, 0b110, 0b100, 0b011 };
const g3_f = [5]u16{ 0b011, 0b010, 0b111, 0b010, 0b010 };
const g3_g = [5]u16{ 0b011, 0b101, 0b011, 0b001, 0b110 };
const g3_h = [5]u16{ 0b100, 0b110, 0b101, 0b101, 0b101 };
const g3_i = [5]u16{ 0b010, 0b000, 0b010, 0b010, 0b010 };
const g3_j = [5]u16{ 0b001, 0b000, 0b001, 0b101, 0b010 };
const g3_k = [5]u16{ 0b100, 0b101, 0b110, 0b101, 0b101 };
const g3_l = [5]u16{ 0b110, 0b010, 0b010, 0b010, 0b011 };
const g3_m = [5]u16{ 0b000, 0b111, 0b111, 0b101, 0b101 };
const g3_n = [5]u16{ 0b000, 0b110, 0b101, 0b101, 0b101 };
const g3_o = [5]u16{ 0b000, 0b010, 0b101, 0b101, 0b010 };
const g3_p = [5]u16{ 0b110, 0b101, 0b110, 0b100, 0b100 };
const g3_q = [5]u16{ 0b011, 0b101, 0b011, 0b001, 0b001 };
const g3_r = [5]u16{ 0b000, 0b011, 0b100, 0b100, 0b100 };
const g3_s = [5]u16{ 0b000, 0b011, 0b010, 0b001, 0b110 };
const g3_t = [5]u16{ 0b010, 0b111, 0b010, 0b010, 0b011 };
const g3_u = [5]u16{ 0b000, 0b101, 0b101, 0b101, 0b011 };
const g3_v = [5]u16{ 0b000, 0b101, 0b101, 0b101, 0b010 };
const g3_w = [5]u16{ 0b000, 0b101, 0b101, 0b111, 0b111 };
const g3_x = [5]u16{ 0b000, 0b101, 0b010, 0b010, 0b101 };
const g3_y = [5]u16{ 0b101, 0b101, 0b011, 0b001, 0b110 };
const g3_z = [5]u16{ 0b000, 0b111, 0b010, 0b100, 0b111 };

fn lookupAscii3x5(cp: u21) ?BitmapGlyph {
    return switch (cp) {
        ' ' => glyph3x5(&g3_space, cp),
        'A' => glyph3x5(&g3_A, cp),
        'B' => glyph3x5(&g3_B, cp),
        'C' => glyph3x5(&g3_C, cp),
        'D' => glyph3x5(&g3_D, cp),
        'E' => glyph3x5(&g3_E, cp),
        'F' => glyph3x5(&g3_F, cp),
        'G' => glyph3x5(&g3_G, cp),
        'H' => glyph3x5(&g3_H, cp),
        'I' => glyph3x5(&g3_I, cp),
        'J' => glyph3x5(&g3_J, cp),
        'K' => glyph3x5(&g3_K, cp),
        'L' => glyph3x5(&g3_L, cp),
        'M' => glyph3x5(&g3_M, cp),
        'N' => glyph3x5(&g3_N, cp),
        'O', '0' => glyph3x5(&g3_O, cp),
        'P' => glyph3x5(&g3_P, cp),
        'Q' => glyph3x5(&g3_Q, cp),
        'R' => glyph3x5(&g3_R, cp),
        'S' => glyph3x5(&g3_S, cp),
        'T' => glyph3x5(&g3_T, cp),
        'U' => glyph3x5(&g3_U, cp),
        'V' => glyph3x5(&g3_V, cp),
        'W' => glyph3x5(&g3_W, cp),
        'X' => glyph3x5(&g3_X, cp),
        'Y' => glyph3x5(&g3_Y, cp),
        'Z' => glyph3x5(&g3_Z, cp),
        'a' => glyph3x5(&g3_a, cp),
        'b' => glyph3x5(&g3_b, cp),
        'c' => glyph3x5(&g3_c, cp),
        'd' => glyph3x5(&g3_d, cp),
        'e' => glyph3x5(&g3_e, cp),
        'f' => glyph3x5(&g3_f, cp),
        'g' => glyph3x5(&g3_g, cp),
        'h' => glyph3x5(&g3_h, cp),
        'i' => glyph3x5(&g3_i, cp),
        'j' => glyph3x5(&g3_j, cp),
        'k' => glyph3x5(&g3_k, cp),
        'l' => glyph3x5(&g3_l, cp),
        'm' => glyph3x5(&g3_m, cp),
        'n' => glyph3x5(&g3_n, cp),
        'o' => glyph3x5(&g3_o, cp),
        'p' => glyph3x5(&g3_p, cp),
        'q' => glyph3x5(&g3_q, cp),
        'r' => glyph3x5(&g3_r, cp),
        's' => glyph3x5(&g3_s, cp),
        't' => glyph3x5(&g3_t, cp),
        'u' => glyph3x5(&g3_u, cp),
        'v' => glyph3x5(&g3_v, cp),
        'w' => glyph3x5(&g3_w, cp),
        'x' => glyph3x5(&g3_x, cp),
        'y' => glyph3x5(&g3_y, cp),
        'z' => glyph3x5(&g3_z, cp),
        '1' => glyph3x5(&g3_1, cp),
        '2' => glyph3x5(&g3_2, cp),
        '3' => glyph3x5(&g3_3, cp),
        '4' => glyph3x5(&g3_4, cp),
        '5' => glyph3x5(&g3_5, cp),
        '6' => glyph3x5(&g3_6, cp),
        '7' => glyph3x5(&g3_7, cp),
        '8' => glyph3x5(&g3_8, cp),
        '9' => glyph3x5(&g3_9, cp),
        '.' => glyph3x5(&g3_dot, cp),
        ',' => glyph3x5(&g3_comma, cp),
        '-' => glyph3x5(&g3_dash, cp),
        '+' => glyph3x5(&g3_plus, cp),
        '_' => glyph3x5(&g3_under, cp),
        ':' => glyph3x5(&g3_colon, cp),
        ';' => glyph3x5(&g3_semi, cp),
        '!' => glyph3x5(&g3_bang, cp),
        '?' => glyph3x5(&g3_quest, cp),
        '/' => glyph3x5(&g3_slash, cp),
        '\\' => glyph3x5(&g3_bslash, cp),
        '%' => glyph3x5(&g3_pct, cp),
        '(' => glyph3x5(&g3_lparen, cp),
        ')' => glyph3x5(&g3_rparen, cp),
        '[' => glyph3x5(&g3_lbrack, cp),
        ']' => glyph3x5(&g3_rbrack, cp),
        '=' => glyph3x5(&g3_eq, cp),
        '<' => glyph3x5(&g3_lt, cp),
        '>' => glyph3x5(&g3_gt, cp),
        '#' => glyph3x5(&g3_hash, cp),
        '*' => glyph3x5(&g3_star, cp),
        '@' => glyph3x5(&g3_at, cp),
        '&' => glyph3x5(&g3_amp, cp),
        '|' => glyph3x5(&g3_pipe, cp),
        '~' => glyph3x5(&g3_tilde, cp),
        '^' => glyph3x5(&g3_caret, cp),
        '\'' => glyph3x5(&g3_quote, cp),
        '"' => glyph3x5(&g3_dquote, cp),
        '$' => glyph3x5(&g3_dollar, cp),
        else => null,
    };
}

const g5_space = [7]u16{ 0, 0, 0, 0, 0, 0, 0 };
const g5_A = [7]u16{ 0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001 };
const g5_B = [7]u16{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110 };
const g5_C = [7]u16{ 0b01110, 0b10001, 0b10000, 0b10000, 0b10000, 0b10001, 0b01110 };
const g5_D = [7]u16{ 0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110 };
const g5_E = [7]u16{ 0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111 };
const g5_F = [7]u16{ 0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000 };
const g5_G = [7]u16{ 0b01110, 0b10001, 0b10000, 0b10111, 0b10001, 0b10001, 0b01111 };
const g5_H = [7]u16{ 0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001 };
const g5_I = [7]u16{ 0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b11111 };
const g5_J = [7]u16{ 0b00111, 0b00010, 0b00010, 0b00010, 0b10010, 0b10010, 0b01100 };
const g5_K = [7]u16{ 0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001 };
const g5_L = [7]u16{ 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111 };
const g5_M = [7]u16{ 0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001 };
const g5_N = [7]u16{ 0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001 };
const g5_O = [7]u16{ 0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110 };
const g5_P = [7]u16{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000 };
const g5_Q = [7]u16{ 0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101 };
const g5_R = [7]u16{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001 };
const g5_S = [7]u16{ 0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110 };
const g5_T = [7]u16{ 0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100 };
const g5_U = [7]u16{ 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110 };
const g5_V = [7]u16{ 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b00100 };
const g5_W = [7]u16{ 0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b11011, 0b10001 };
const g5_X = [7]u16{ 0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001 };
const g5_Y = [7]u16{ 0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100 };
const g5_Z = [7]u16{ 0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111 };
const g5_0 = [7]u16{ 0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110 };
const g5_1 = [7]u16{ 0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110 };
const g5_2 = [7]u16{ 0b01110, 0b10001, 0b00001, 0b00110, 0b01000, 0b10000, 0b11111 };
const g5_3 = [7]u16{ 0b11110, 0b00001, 0b00001, 0b01110, 0b00001, 0b00001, 0b11110 };
const g5_4 = [7]u16{ 0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010 };
const g5_5 = [7]u16{ 0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110 };
const g5_6 = [7]u16{ 0b01110, 0b10000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110 };
const g5_7 = [7]u16{ 0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000 };
const g5_8 = [7]u16{ 0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110 };
const g5_9 = [7]u16{ 0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b01110 };
const g5_dot = [7]u16{ 0, 0, 0, 0, 0, 0b00110, 0b00110 };
const g5_comma = [7]u16{ 0, 0, 0, 0, 0b00110, 0b00100, 0b01000 };
const g5_dash = [7]u16{ 0, 0, 0, 0b01110, 0, 0, 0 };
const g5_plus = [7]u16{ 0, 0b00100, 0b00100, 0b11111, 0b00100, 0b00100, 0 };
const g5_colon = [7]u16{ 0, 0b00100, 0b00100, 0, 0b00100, 0b00100, 0 };
const g5_bang = [7]u16{ 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0, 0b00100 };
const g5_quest = [7]u16{ 0b01110, 0b10001, 0b00001, 0b00110, 0b00100, 0, 0b00100 };
const g5_slash = [7]u16{ 0b00001, 0b00010, 0b00010, 0b00100, 0b01000, 0b01000, 0b10000 };
const g5_under = [7]u16{ 0, 0, 0, 0, 0, 0, 0b11111 };

fn foldLatinAccent(cp: u21) u21 {
    return switch (cp) {
        0x00C0...0x00C5, 0x00E0...0x00E5 => 'A',
        0x00C7, 0x00E7 => 'C',
        0x00C8...0x00CB, 0x00E8...0x00EB => 'E',
        0x00CC...0x00CF, 0x00EC...0x00EF => 'I',
        0x00D1, 0x00F1 => 'N',
        0x00D2...0x00D6, 0x00D8, 0x00F2...0x00F6, 0x00F8 => 'O',
        0x00D9...0x00DC, 0x00F9...0x00FC => 'U',
        0x00DD, 0x00FD, 0x00FF => 'Y',
        0x00A1 => '!',
        0x00BF => '?',
        else => if (cp >= 'a' and cp <= 'z') cp - 32 else cp,
    };
}

fn lookupSans5x7(cp: u21) ?BitmapGlyph {
    const up: u21 = foldLatinAccent(cp);
    return switch (up) {
        ' ' => glyph5x7(&g5_space, cp),
        'A' => glyph5x7(&g5_A, cp),
        'B' => glyph5x7(&g5_B, cp),
        'C' => glyph5x7(&g5_C, cp),
        'D' => glyph5x7(&g5_D, cp),
        'E' => glyph5x7(&g5_E, cp),
        'F' => glyph5x7(&g5_F, cp),
        'G' => glyph5x7(&g5_G, cp),
        'H' => glyph5x7(&g5_H, cp),
        'I' => glyph5x7(&g5_I, cp),
        'J' => glyph5x7(&g5_J, cp),
        'K' => glyph5x7(&g5_K, cp),
        'L' => glyph5x7(&g5_L, cp),
        'M' => glyph5x7(&g5_M, cp),
        'N' => glyph5x7(&g5_N, cp),
        'O' => glyph5x7(&g5_O, cp),
        'P' => glyph5x7(&g5_P, cp),
        'Q' => glyph5x7(&g5_Q, cp),
        'R' => glyph5x7(&g5_R, cp),
        'S' => glyph5x7(&g5_S, cp),
        'T' => glyph5x7(&g5_T, cp),
        'U' => glyph5x7(&g5_U, cp),
        'V' => glyph5x7(&g5_V, cp),
        'W' => glyph5x7(&g5_W, cp),
        'X' => glyph5x7(&g5_X, cp),
        'Y' => glyph5x7(&g5_Y, cp),
        'Z' => glyph5x7(&g5_Z, cp),
        '0' => glyph5x7(&g5_0, cp),
        '1' => glyph5x7(&g5_1, cp),
        '2' => glyph5x7(&g5_2, cp),
        '3' => glyph5x7(&g5_3, cp),
        '4' => glyph5x7(&g5_4, cp),
        '5' => glyph5x7(&g5_5, cp),
        '6' => glyph5x7(&g5_6, cp),
        '7' => glyph5x7(&g5_7, cp),
        '8' => glyph5x7(&g5_8, cp),
        '9' => glyph5x7(&g5_9, cp),
        '.' => glyph5x7(&g5_dot, cp),
        ',' => glyph5x7(&g5_comma, cp),
        '-' => glyph5x7(&g5_dash, cp),
        '+' => glyph5x7(&g5_plus, cp),
        ':' => glyph5x7(&g5_colon, cp),
        '!' => glyph5x7(&g5_bang, cp),
        '?' => glyph5x7(&g5_quest, cp),
        '/' => glyph5x7(&g5_slash, cp),
        '_' => glyph5x7(&g5_under, cp),
        else => null,
    };
}

test "bitmap fonts resolve ascii and custom client unicode glyphs cleanly" {
    const custom_font = BitmapFont{
        .name = "custom_logo",
        .default_width = 5,
        .height = 5,
        .glyphs = &.{
            .{ .codepoint = '★', .width = 5, .height = 5, .rows = &.{ 0b00100, 0b11111, 0b01110, 0b11011, 0b10001 } },
        },
        .fallback = &BitmapFont.block_3x5,
    };

    const star = custom_font.resolveGlyph('★').?;
    try testing.expect(star.pixelAt(2, 0));
    try testing.expect(!star.pixelAt(0, 0));

    const z = BitmapFont.sans_5x7.resolveGlyph('Z').?;
    try testing.expectEqual(@as(u5, 5), z.width);
    try testing.expect(z.pixelAt(0, 0));

    const cells = BitmapFont.sans_5x7.measureCells("ZIG", .half_block, 1, 1);
    try testing.expectEqual(@as(u16, 17), cells.cols);
    try testing.expectEqual(@as(u16, 4), cells.rows);
}
