//! Unicode support utilities for TUI.zig
//!
//! Provides:
//! - Character width calculation (wcwidth)
//! - Grapheme cluster handling
//! - Display width for strings

const std = @import("std");

/// Get the display width of a Unicode codepoint.
/// Returns 0 for control/combining characters, 1 for most chars, 2 for wide chars (CJK, emoji, etc.)
pub fn charWidth(cp: u21) u2 {
    // Control characters and combining marks
    if (cp < 0x20) return 0;
    if (cp >= 0x7F and cp < 0xA0) return 0;

    // Zero-width characters
    if (isZeroWidth(cp)) return 0;

    // Wide characters
    if (isWideChar(cp)) return 2;

    return 1;
}

/// Check if a codepoint is a zero-width character
fn isZeroWidth(cp: u21) bool {
    // Combining diacritical marks
    if (cp >= 0x0300 and cp <= 0x036F) return true;

    // Combining diacritical marks extended
    if (cp >= 0x1AB0 and cp <= 0x1AFF) return true;

    // Combining diacritical marks supplement
    if (cp >= 0x1DC0 and cp <= 0x1DFF) return true;

    // Combining diacritical marks for symbols
    if (cp >= 0x20D0 and cp <= 0x20FF) return true;

    // Combining half marks
    if (cp >= 0xFE20 and cp <= 0xFE2F) return true;

    // Zero width space and similar
    if (cp == 0x200B or cp == 0x200C or cp == 0x200D or cp == 0xFEFF) return true;

    // Variation selectors
    if (cp >= 0xFE00 and cp <= 0xFE0F) return true;
    if (cp >= 0xE0100 and cp <= 0xE01EF) return true;

    // Soft hyphen
    if (cp == 0x00AD) return true;

    return false;
}

/// Check if a codepoint is a wide (double-width) character
fn isWideChar(cp: u21) bool {
    // CJK ranges
    if (cp >= 0x1100 and cp <= 0x115F) return true; // Hangul Jamo
    if (cp >= 0x231A and cp <= 0x231B) return true; // Watch, hourglass
    if (cp >= 0x2329 and cp <= 0x232A) return true; // Angle brackets
    if (cp >= 0x23E9 and cp <= 0x23F3) return true; // Various symbols
    if (cp >= 0x23F8 and cp <= 0x23FA) return true; // Various symbols
    if (cp >= 0x25AA and cp <= 0x25AB) return true; // Squares
    if (cp >= 0x25B6 and cp <= 0x25C0) return true; // Triangles
    if (cp >= 0x25FB and cp <= 0x25FE) return true; // Squares
    if (cp >= 0x2600 and cp <= 0x2764) return true; // Miscellaneous symbols
    if (cp >= 0x2795 and cp <= 0x2797) return true; // Math operators
    if (cp >= 0x2934 and cp <= 0x2935) return true; // Arrows
    if (cp >= 0x2B05 and cp <= 0x2B07) return true; // Arrows
    if (cp >= 0x2B1B and cp <= 0x2B1C) return true; // Squares
    if (cp >= 0x2B50 and cp <= 0x2B50) return true; // Star
    if (cp >= 0x2B55 and cp <= 0x2B55) return true; // Circle
    if (cp >= 0x2E80 and cp <= 0x2EFF) return true; // CJK Radicals Supplement
    if (cp >= 0x2F00 and cp <= 0x2FDF) return true; // Kangxi Radicals
    if (cp >= 0x2FF0 and cp <= 0x2FFF) return true; // Ideographic Description Characters
    if (cp >= 0x3000 and cp <= 0x303E) return true; // CJK Symbols and Punctuation
    if (cp >= 0x3041 and cp <= 0x3096) return true; // Hiragana
    if (cp >= 0x30A0 and cp <= 0x30FF) return true; // Katakana
    if (cp >= 0x3105 and cp <= 0x312F) return true; // Bopomofo
    if (cp >= 0x3131 and cp <= 0x318E) return true; // Hangul Compatibility Jamo
    if (cp >= 0x3190 and cp <= 0x31FF) return true; // Kanbun, Bopomofo Extended, etc.
    if (cp >= 0x3200 and cp <= 0x321E) return true; // Enclosed CJK Letters
    if (cp >= 0x3220 and cp <= 0x3247) return true; // Enclosed CJK Letters
    if (cp >= 0x3250 and cp <= 0x4DBF) return true; // Various CJK ranges
    if (cp >= 0x4E00 and cp <= 0x9FFF) return true; // CJK Unified Ideographs
    if (cp >= 0xA960 and cp <= 0xA97F) return true; // Hangul Jamo Extended-A
    if (cp >= 0xAC00 and cp <= 0xD7A3) return true; // Hangul Syllables
    if (cp >= 0xD7B0 and cp <= 0xD7FF) return true; // Hangul Jamo Extended-B
    if (cp >= 0xF900 and cp <= 0xFAFF) return true; // CJK Compatibility Ideographs
    if (cp >= 0xFE10 and cp <= 0xFE1F) return true; // Vertical forms
    if (cp >= 0xFE30 and cp <= 0xFE6F) return true; // CJK Compatibility Forms
    if (cp >= 0xFF00 and cp <= 0xFF60) return true; // Fullwidth ASCII
    if (cp >= 0xFFE0 and cp <= 0xFFE6) return true; // Fullwidth symbols
    if (cp >= 0x1F300 and cp <= 0x1F9FF) return true; // Emoji
    if (cp >= 0x20000 and cp <= 0x2A6DF) return true; // CJK Extension B
    if (cp >= 0x2A700 and cp <= 0x2CEAF) return true; // CJK Extension C, D, E, F
    if (cp >= 0x2F800 and cp <= 0x2FA1F) return true; // CJK Compatibility Supplement
    if (cp >= 0x30000 and cp <= 0x3134F) return true; // CJK Extension G

    return false;
}

/// Calculate the display width of a UTF-8 string
pub fn stringWidth(s: []const u8) usize {
    var width: usize = 0;
    var iter = std.unicode.Utf8Iterator{ .bytes = s, .i = 0 };

    while (iter.nextCodepoint()) |cp| {
        width += charWidth(cp);
    }

    return width;
}

/// Calculate the display width of a grapheme cluster
pub fn graphemeWidth(grapheme: []const u8) usize {
    if (grapheme.len == 0) return 0;

    // For a grapheme cluster, the width is typically determined by the base character
    var iter = std.unicode.Utf8Iterator{ .bytes = grapheme, .i = 0 };

    if (iter.nextCodepoint()) |cp| {
        // Check if it's an emoji sequence (contains variation selectors or ZWJ)
        if (isEmojiSequence(grapheme)) return 2;

        return charWidth(cp);
    }

    return 1;
}

/// Check if a string represents an emoji sequence
fn isEmojiSequence(s: []const u8) bool {
    var iter = std.unicode.Utf8Iterator{ .bytes = s, .i = 0 };
    var found_emoji = false;

    while (iter.nextCodepoint()) |cp| {
        // Emoji ranges
        if (cp >= 0x1F300 and cp <= 0x1F9FF) found_emoji = true;
        if (cp >= 0x2600 and cp <= 0x26FF) found_emoji = true;
        if (cp >= 0x2700 and cp <= 0x27BF) found_emoji = true;

        // Zero-width joiner indicates compound emoji
        if (cp == 0x200D) return true;

        // Emoji variation selector
        if (cp == 0xFE0F) return true;
    }

    return found_emoji;
}

/// Truncate a string to a maximum display width
/// Returns the byte index where to cut
pub fn truncateToWidth(s: []const u8, max_width: usize) usize {
    var width: usize = 0;
    var iter = std.unicode.Utf8Iterator{ .bytes = s, .i = 0 };
    var last_valid_i: usize = 0;

    while (iter.nextCodepoint()) |cp| {
        const cp_width = charWidth(cp);

        if (width + cp_width > max_width) {
            break;
        }

        width += cp_width;
        last_valid_i = iter.i;
    }

    return last_valid_i;
}

/// Pad a string to a specific width
pub fn padToWidth(allocator: std.mem.Allocator, s: []const u8, width: usize, pad_char: u8) ![]u8 {
    const current_width = stringWidth(s);

    if (current_width >= width) {
        // Need to truncate
        const cut_point = truncateToWidth(s, width);
        const result = try allocator.alloc(u8, cut_point);
        @memcpy(result, s[0..cut_point]);
        return result;
    }

    // Need to pad
    const padding = width - current_width;
    const result = try allocator.alloc(u8, s.len + padding);
    @memcpy(result[0..s.len], s);
    @memset(result[s.len..], pad_char);
    return result;
}

/// Iterator for grapheme clusters (simplified)
pub const GraphemeIterator = struct {
    bytes: []const u8,
    i: usize = 0,

    pub fn next(self: *GraphemeIterator) ?[]const u8 {
        if (self.i >= self.bytes.len) return null;

        const start = self.i;
        var iter = std.unicode.Utf8Iterator{ .bytes = self.bytes, .i = self.i };

        // Get the first codepoint
        const first_cp = iter.nextCodepoint() orelse return null;
        _ = first_cp;

        // Look for combining characters or modifiers
        while (iter.nextCodepoint()) |cp| {
            if (!isZeroWidth(cp) and cp != 0x200D) {
                // This is a new base character, stop here
                break;
            }
        }

        self.i = iter.i;
        const end = iter.i;

        // Back up since we read one extra
        if (self.i > start and !isZeroWidth(std.unicode.utf8Decode(self.bytes[start..self.i]) catch 0)) {
            // Actually need to recalculate
        }

        return self.bytes[start..end];
    }
};

test "char width basic" {
    try std.testing.expectEqual(@as(u2, 1), charWidth('A'));
    try std.testing.expectEqual(@as(u2, 1), charWidth('z'));
    try std.testing.expectEqual(@as(u2, 1), charWidth('1'));
}

test "char width control characters" {
    try std.testing.expectEqual(@as(u2, 0), charWidth(0x00)); // NULL
    try std.testing.expectEqual(@as(u2, 0), charWidth(0x1B)); // ESC
}

test "char width wide characters" {
    try std.testing.expectEqual(@as(u2, 2), charWidth('中'));
    try std.testing.expectEqual(@as(u2, 2), charWidth('日'));
    try std.testing.expectEqual(@as(u2, 2), charWidth('한'));
}

test "string width" {
    try std.testing.expectEqual(@as(usize, 5), stringWidth("Hello"));
    try std.testing.expectEqual(@as(usize, 4), stringWidth("中文"));
    try std.testing.expectEqual(@as(usize, 9), stringWidth("Hello中文")); // 5 + 4 = 9
}

test "truncate to width" {
    const s = "Hello, World!";
    try std.testing.expectEqual(@as(usize, 5), truncateToWidth(s, 5));
    try std.testing.expectEqual(@as(usize, 13), truncateToWidth(s, 100));
}
