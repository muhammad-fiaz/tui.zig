//! UTF-8 grapheme segmentation and Unicode terminal cell display width.
//!
//! Uses `std.unicode` for UTF-8 decoding and validation, grouping base
//! codepoints with combining marks, variation selectors, skin-tone modifiers,
//! regional indicator pairs, and ZWJ emoji sequences into grapheme clusters.

const std = @import("std");
const testing = std.testing;

/// A single Unicode grapheme cluster slice and its terminal cell display width.
pub const Grapheme = struct {
    slice: []const u8,
    width: u16,
};

/// Iterates UTF-8 text yielding grapheme clusters and their display widths.
/// Invalid UTF-8 sequences are safely stepped one byte at a time with width 1
/// (or skipped if ASCII control).
pub const GraphemeIterator = struct {
    bytes: []const u8,
    index: usize = 0,

    /// Creates a `GraphemeIterator` over `bytes`.
    pub fn init(bytes: []const u8) GraphemeIterator {
        return .{ .bytes = bytes, .index = 0 };
    }

    /// Returns the next `Grapheme`, or `null` at the end of the slice.
    pub fn next(self: *GraphemeIterator) ?Grapheme {
        if (self.index >= self.bytes.len) return null;

        const start = self.index;
        const first_byte = self.bytes[start];

        // ASCII fast path: single printable byte not followed by combining mark or ZWJ.
        if (first_byte < 0x80) {
            self.index += 1;
            const next_is_non_ascii = self.index < self.bytes.len and self.bytes[self.index] >= 0x80;
            if (!next_is_non_ascii) {
                const w: u16 = if (first_byte < 0x20 or first_byte == 0x7F) 0 else 1;
                return .{ .slice = self.bytes[start..self.index], .width = w };
            }
            // Fall through to attach any trailing combining marks / VS16 to ASCII base.
            return self.finishCluster(start, first_byte);
        }

        const first_cp = self.readCodepoint() orelse {
            // Invalid UTF-8 lead byte: advance one byte safely.
            self.index = start + 1;
            return .{ .slice = self.bytes[start..self.index], .width = 1 };
        };

        return self.finishCluster(start, first_cp);
    }

    fn finishCluster(self: *GraphemeIterator, start: usize, first_cp: u21) Grapheme {
        var is_ri = isRegionalIndicator(first_cp);
        var has_vs16 = false;
        var has_zwj = false;
        var prev_was_zwj = false;

        while (self.index < self.bytes.len) {
            const peek_pos = self.index;
            const b = self.bytes[peek_pos];
            if (b < 0x80) {
                if (prev_was_zwj and b >= 0x20 and b != 0x7F) {
                    self.index += 1;
                    prev_was_zwj = false;
                    continue;
                }
                break;
            }

            const cp = self.readCodepoint() orelse {
                self.index = peek_pos;
                break;
            };

            if (cp == 0x200D) {
                has_zwj = true;
                prev_was_zwj = true;
                is_ri = false;
                continue;
            }
            if (cp == 0xFE0F) {
                has_vs16 = true;
                prev_was_zwj = false;
                continue;
            }
            if (prev_was_zwj) {
                prev_was_zwj = false;
                continue;
            }
            if (isRegionalIndicator(cp) and is_ri) {
                is_ri = false;
                continue;
            }
            if (isClusterExtender(cp)) {
                continue;
            }

            self.index = peek_pos;
            break;
        }

        const slice = self.bytes[start..self.index];
        var width: u16 = codepointWidth(first_cp);
        if (isRegionalIndicator(first_cp) and slice.len >= 8) {
            width = 2;
        } else if (has_zwj and width > 0) {
            width = 2;
        } else if (has_vs16 and isEmojiPresentationCapable(first_cp)) {
            width = 2;
        }

        return .{ .slice = slice, .width = width };
    }

    fn readCodepoint(self: *GraphemeIterator) ?u21 {
        if (self.index >= self.bytes.len) return null;
        const seq_len = std.unicode.utf8ByteSequenceLength(self.bytes[self.index]) catch return null;
        if (self.index + seq_len > self.bytes.len) return null;
        const cp = switch (seq_len) {
            1 => @as(u21, self.bytes[self.index]),
            2 => std.unicode.utf8Decode2(self.bytes[self.index..][0..2].*) catch return null,
            3 => std.unicode.utf8Decode3(self.bytes[self.index..][0..3].*) catch return null,
            4 => std.unicode.utf8Decode4(self.bytes[self.index..][0..4].*) catch return null,
            else => return null,
        };
        self.index += seq_len;
        return cp;
    }
};

/// Returns the terminal display width of a single Unicode codepoint (`0`, `1`, or `2`).
pub fn codepointWidth(cp: u21) u8 {
    // ASCII and C0/C1 controls.
    if (cp < 0x20 or (cp >= 0x7F and cp < 0xA0)) return 0;
    if (cp < 0x0300) return 1;

    // Combining diacritics, format controls, variation selectors, Hangul trailing jamo.
    if (isZeroWidth(cp)) return 0;

    // Halfwidth Katakana dakuten / handakuten render as 1 cell in terminals.
    if (cp == 0xFF9E or cp == 0xFF9F) return 1;

    // East Asian Wide, Fullwidth, and wide emoji blocks.
    if (isWideCodepoint(cp)) return 2;

    return 1;
}

/// Returns the total terminal cell width of `text` across all grapheme clusters.
pub fn displayWidth(text: []const u8) u16 {
    if (text.len == 0) return 0;
    var total: u32 = 0;
    var it = GraphemeIterator.init(text);
    while (it.next()) |g| {
        total += g.width;
        if (total >= std.math.maxInt(u16)) return std.math.maxInt(u16);
    }
    return @intCast(total);
}

/// Returns the terminal cell width for a cell's symbol string.
/// Multi-grapheme payloads (such as embedded escape payloads) report width `1`.
pub fn cellWidth(symbol: []const u8) u16 {
    if (symbol.len == 0) return 0;
    if (symbol.len == 1) {
        const b = symbol[0];
        return if (b < 0x20 or b == 0x7F) 0 else 1;
    }
    var it = GraphemeIterator.init(symbol);
    const first = it.next() orelse return 0;
    if (it.next() != null) return 1;
    return first.width;
}

/// Truncates `text` at grapheme boundaries so its display width is at most `max_width`.
pub fn truncateToWidth(text: []const u8, max_width: u16) Grapheme {
    if (max_width == 0 or text.len == 0) return .{ .slice = text[0..0], .width = 0 };
    var it = GraphemeIterator.init(text);
    var end_idx: usize = 0;
    var used: u16 = 0;
    while (it.next()) |g| {
        if (used + g.width > max_width) break;
        used += g.width;
        end_idx = it.index;
    }
    return .{ .slice = text[0..end_idx], .width = used };
}

/// Truncates `text` from the left (keeping the tail) to fit within `max_width`.
pub fn truncateStartToWidth(text: []const u8, max_width: u16) Grapheme {
    const total = displayWidth(text);
    if (total <= max_width) return .{ .slice = text, .width = total };
    if (max_width == 0) return .{ .slice = text[text.len..], .width = 0 };

    const to_drop = total - max_width;
    var dropped: u16 = 0;
    var start_idx: usize = 0;
    var it = GraphemeIterator.init(text);
    while (it.next()) |g| {
        if (dropped >= to_drop) break;
        dropped += g.width;
        start_idx = it.index;
    }
    return .{ .slice = text[start_idx..], .width = total -| dropped };
}

fn isRegionalIndicator(cp: u21) bool {
    return cp >= 0x1F1E6 and cp <= 0x1F1FF;
}

fn isEmojiPresentationCapable(cp: u21) bool {
    return (cp >= 0x2600 and cp <= 0x27BF) or
        cp == 0x231A or cp == 0x231B or
        (cp >= 0x25A0 and cp <= 0x25FF) or
        (cp >= 0x2B00 and cp <= 0x2BFF) or
        (cp >= 0x1F000 and cp <= 0x1FAFF);
}

fn isClusterExtender(cp: u21) bool {
    return isZeroWidth(cp) or
        (cp >= 0x1F3FB and cp <= 0x1F3FF) or // Emoji Fitzpatrick skin tones
        (cp >= 0xE0020 and cp <= 0xE007F); // Tag characters for flag sequences
}

fn isZeroWidth(cp: u21) bool {
    return switch (cp) {
        0x0300...0x036F, // Combining Diacritical Marks
        0x0483...0x0489, // Cyrillic combining
        0x0591...0x05BD,
        0x05BF,
        0x05C1...0x05C2,
        0x05C4...0x05C5,
        0x05C7,
        0x0610...0x061A,
        0x064B...0x065F,
        0x0670,
        0x06D6...0x06DC,
        0x06DF...0x06E4,
        0x06E7...0x06E8,
        0x06EA...0x06ED,
        0x0711,
        0x0730...0x074A,
        0x0900...0x0902,
        0x093C,
        0x0941...0x0948,
        0x094D,
        0x0951...0x0957,
        0x0962...0x0963,
        0x0981, // Bengali
        0x09BC,
        0x09BE...0x09C4,
        0x09CD,
        0x0A01...0x0A02, // Gurmukhi
        0x0A3C,
        0x0A41...0x0A4D,
        0x0A81...0x0A82, // Gujarati
        0x0ABC,
        0x0AC1...0x0AC8,
        0x0ACD,
        0x0B01, // Oriya
        0x0B3C,
        0x0B3F,
        0x0B41...0x0B4D,
        0x0B82, // Tamil
        0x0BC0,
        0x0BCD,
        0x0C3E...0x0C40, // Telugu
        0x0C46...0x0C4D,
        0x0CBC, // Kannada
        0x0CCC...0x0CCD,
        0x0D41...0x0D4D, // Malayalam
        0x0E31, // Thai
        0x0E34...0x0E3A,
        0x0E47...0x0E4E,
        0x0EB1, // Lao
        0x0EB4...0x0EB9,
        0x0EBB...0x0EBC,
        0x0EC8...0x0ECD,
        0x0F71...0x0F84, // Tibetan
        0x102D...0x1030, // Myanmar
        0x1032...0x1037,
        0x1039...0x103A,
        0x1160...0x11FF, // Hangul Jamo Medial Vowels and Trailing Consonants
        0x17B7...0x17BD, // Khmer
        0x17C6,
        0x17C9...0x17D3,
        0x1AB0...0x1AFF,
        0x1DC0...0x1DFF,
        0x200B...0x200F, // ZWSP, ZWNJ, ZWJ, LRM, RLM
        0x202A...0x202E,
        0x2060...0x206F,
        0x20D0...0x20FF,
        0x3099...0x309A, // Combining Katakana/Hiragana voiced marks
        0xD7B0...0xD7FF, // Hangul Jamo Extended-B
        0xFE00...0xFE0F, // Variation Selectors 1..16
        0xFE20...0xFE2F,
        0xFEFF,
        0xE0100...0xE01EF, // Variation Selectors Supplement
        => true,
        else => false,
    };
}

/// Text reading direction for localization and BiDi-safe alignment.
pub const TextDirection = enum {
    ltr,
    rtl,
    auto,
};

/// Returns true when `cp` belongs to a right-to-left script (Hebrew, Arabic, Syriac, Thaana, N'Ko, Adlam).
pub fn isRtlCodepoint(cp: u21) bool {
    return (cp >= 0x0590 and cp <= 0x08FF) or
        (cp >= 0xFB1D and cp <= 0xFDFF) or
        (cp >= 0xFE70 and cp <= 0xFEFF) or
        (cp >= 0x10800 and cp <= 0x10FFF) or
        (cp >= 0x1E800 and cp <= 0x1E95F);
}

/// Detects dominant reading direction (`ltr` vs `rtl`) from the first strongly directional codepoint in `text`.
pub fn detectDirection(text: []const u8) TextDirection {
    var it = GraphemeIterator.init(text);
    while (it.next()) |g| {
        if (g.slice.len == 0) continue;
        const seq_len = std.unicode.utf8ByteSequenceLength(g.slice[0]) catch continue;
        if (seq_len > g.slice.len) continue;
        const cp = std.unicode.utf8Decode(g.slice[0..seq_len]) catch continue;
        if (isRtlCodepoint(cp)) return .rtl;
        if ((cp >= 'A' and cp <= 'Z') or (cp >= 'a' and cp <= 'z') or (cp >= 0x00C0 and cp <= 0x04FF)) return .ltr;
    }
    return .ltr;
}

fn containsRtlCodepoint(text: []const u8) bool {
    var it = GraphemeIterator.init(text);
    while (it.next()) |g| {
        if (g.slice.len == 0) continue;
        const seq_len = std.unicode.utf8ByteSequenceLength(g.slice[0]) catch continue;
        if (seq_len > g.slice.len) continue;
        const cp = std.unicode.utf8Decode(g.slice[0..seq_len]) catch continue;
        if (isRtlCodepoint(cp)) return true;
    }
    return false;
}

fn clusterIsRtlOrNeutral(slice: []const u8) enum { rtl, ltr, neutral } {
    if (slice.len == 0) return .neutral;
    const seq_len = std.unicode.utf8ByteSequenceLength(slice[0]) catch return .neutral;
    if (seq_len > slice.len) return .neutral;
    const cp = std.unicode.utf8Decode(slice[0..seq_len]) catch return .neutral;
    if (isRtlCodepoint(cp)) return .rtl;
    if ((cp >= '0' and cp <= '9') or (cp >= 'A' and cp <= 'Z') or (cp >= 'a' and cp <= 'z') or (cp >= 0x00C0 and cp <= 0x04FF)) {
        return .ltr;
    }
    return .neutral;
}

/// Reorders grapheme clusters visually for `.rtl` display while keeping embedded LTR words/numbers readable
/// (zero heap allocation using caller buffer `out_buf`).
pub fn visualOrderInto(text: []const u8, dir: TextDirection, out_buf: []u8) []const u8 {
    const resolved = if (dir == .auto) detectDirection(text) else dir;
    if (resolved == .ltr or text.len == 0 or !containsRtlCodepoint(text)) {
        const len = @min(text.len, out_buf.len);
        @memcpy(out_buf[0..len], text[0..len]);
        return out_buf[0..len];
    }
    // Reverse grapheme cluster sequence while preserving contiguous LTR sub-runs (numbers, ASCII tokens).
    var ends: [256]struct { start: usize, len: usize, is_ltr: bool } = undefined;
    var count: usize = 0;
    var it = GraphemeIterator.init(text);
    while (it.next()) |g| {
        if (count >= ends.len) break;
        ends[count] = .{
            .start = it.index - g.slice.len,
            .len = g.slice.len,
            .is_ltr = clusterIsRtlOrNeutral(g.slice) == .ltr,
        };
        count += 1;
    }
    var pos: usize = 0;
    var i: usize = count;
    while (i > 0) {
        if (ends[i - 1].is_ltr) {
            var run_start = i - 1;
            while (run_start > 0 and ends[run_start - 1].is_ltr) : (run_start -= 1) {}
            var j = run_start;
            while (j < i) : (j += 1) {
                const cl = ends[j];
                if (pos + cl.len > out_buf.len) break;
                @memcpy(out_buf[pos .. pos + cl.len], text[cl.start .. cl.start + cl.len]);
                pos += cl.len;
            }
            i = run_start;
        } else {
            i -= 1;
            const cl = ends[i];
            if (pos + cl.len > out_buf.len) break;
            @memcpy(out_buf[pos .. pos + cl.len], text[cl.start .. cl.start + cl.len]);
            pos += cl.len;
        }
    }
    return out_buf[0..pos];
}

fn isWideCodepoint(cp: u21) bool {
    return switch (cp) {
        0x1100...0x115F, // Hangul Jamo init. consonants
        0x231A...0x231B,
        0x2329...0x232A,
        0x23E9...0x23EC,
        0x23F0,
        0x23F3,
        0x25FD...0x25FE,
        0x2614...0x2615,
        0x2648...0x2653,
        0x267F,
        0x2693,
        0x26A1,
        0x26AA...0x26AB,
        0x26BD...0x26BE,
        0x26C4...0x26C5,
        0x26CE,
        0x26D4,
        0x26EA,
        0x26F2...0x26F3,
        0x26F5,
        0x26FA,
        0x26FD,
        0x2705,
        0x270A...0x270B,
        0x2728,
        0x274C,
        0x274E,
        0x2753...0x2755,
        0x2757,
        0x2795...0x2797,
        0x27B0,
        0x27BF,
        0x2B1B...0x2B1C,
        0x2B50,
        0x2B55,
        0x2E80...0x303E, // CJK Radicals, Kangxi, Symbols
        0x3040...0x3247, // Hiragana, Katakana, Bopomofo, Enclosed CJK
        0x3250...0x4DBF, // CJK Extension A
        0x4E00...0xA4C6, // CJK Unified Ideographs, Yi
        0xA960...0xA97C, // Hangul Jamo Extended-A
        0xAC00...0xD7A3, // Hangul Syllables
        0xF900...0xFAFF, // CJK Compatibility Ideographs
        0xFE10...0xFE19, // Vertical forms
        0xFE30...0xFE6B, // CJK Compatibility Forms
        0xFF01...0xFF60, // Fullwidth Forms
        0xFFE0...0xFFE6,
        0x1F004,
        0x1F0CF,
        0x1F18E,
        0x1F191...0x1F19A,
        0x1F1E6...0x1F1FF, // Regional Indicators
        0x1F200...0x1F2FF,
        0x1F300...0x1F64F, // Misc Symbols & Emoticons
        0x1F680...0x1F6FF, // Transport & Map
        0x1F7E0...0x1F7EB,
        0x1F900...0x1FAFF, // Supplemental Symbols and Extended-A
        0x20000...0x2FFFD, // CJK Extension B..F
        0x30000...0x3FFFD, // CJK Extension G+
        => true,
        else => false,
    };
}

test "grapheme width handles ASCII, CJK, combining marks, and emoji" {
    try testing.expectEqual(@as(u16, 5), displayWidth("hello"));
    try testing.expectEqual(@as(u16, 2), displayWidth("あ"));
    try testing.expectEqual(@as(u16, 4), displayWidth("日本語".ptr[0..6])); // "日本" = 4
    try testing.expectEqual(@as(u16, 1), displayWidth("e\u{0301}"));
    try testing.expectEqual(@as(u16, 2), displayWidth("ｶﾞ"));
    try testing.expectEqual(@as(u16, 2), displayWidth("👨‍👩‍👧‍👦"));
    try testing.expectEqual(@as(u16, 2), displayWidth("🇺🇸"));
    try testing.expectEqual(@as(u16, 0), displayWidth("\x1b"));
}

test "truncateToWidth respects grapheme and width bounds" {
    const t = truncateToWidth("aあb", 3);
    try testing.expectEqualStrings("aあ", t.slice);
    try testing.expectEqual(@as(u16, 3), t.width);

    const t2 = truncateToWidth("aあb", 2);
    try testing.expectEqualStrings("a", t2.slice);
    try testing.expectEqual(@as(u16, 1), t2.width);

    // Multi-script & RTL direction detection + visual cluster ordering.
    try testing.expectEqual(TextDirection.rtl, detectDirection("مرحبا"));
    try testing.expectEqual(TextDirection.ltr, detectDirection("Привет"));
    try testing.expectEqual(@as(u16, 2), displayWidth("कि")); // Ka + i-matra combining vowel
    var rtl_buf: [32]u8 = undefined;
    const vis = visualOrderInto("اب", .rtl, &rtl_buf);
    try testing.expectEqualStrings("با", vis);
}
