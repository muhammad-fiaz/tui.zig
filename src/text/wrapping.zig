//! Word/character wrapping, truncation, and line reflow utilities.
//!
//! Operates directly on borrowed UTF-8 slices without requiring heap allocations
//! when iterating (`WrapIterator`) or reusing a caller-owned `std.ArrayList`
//! across frames.

const std = @import("std");
const grapheme = @import("grapheme.zig");
const testing = std.testing;

/// Strategy for wrapping text lines that exceed available width.
pub const WrapMode = enum {
    /// Do not wrap; truncate or scroll horizontally.
    none,
    /// Wrap at whitespace boundaries, falling back to character breaks for long words.
    word,
    /// Wrap strictly at grapheme cluster boundaries.
    char,
};

/// Truncation mode when text exceeds available width without wrapping.
pub const Truncation = enum {
    /// Hard clip at `max_width` on grapheme boundary.
    clip,
    /// Append `"…"` at the end when truncated.
    end,
    /// Prepend `"…"` at the start when truncated.
    start,
    /// Place `"…"` in the middle when truncated.
    middle,
};

/// Configuration options for wrapping text.
pub const WrapOptions = struct {
    mode: WrapMode = .word,
    trim_leading_spaces: bool = true,
};

/// A single wrapped slice line and its computed display width.
pub const WrappedSlice = struct {
    slice: []const u8,
    width: u16,
};

/// Zero-allocation iterator producing wrapped `WrappedSlice` segments from a single logical line
/// (without embedded `\n`).
pub const WrapIterator = struct {
    text: []const u8,
    max_width: u16,
    options: WrapOptions,
    pos: usize = 0,
    emitted_empty: bool = false,

    pub fn init(text: []const u8, max_width: u16, options: WrapOptions) WrapIterator {
        return .{
            .text = text,
            .max_width = max_width,
            .options = options,
        };
    }

    /// Returns the next wrapped line segment, or `null` when exhausted.
    pub fn next(self: *WrapIterator) ?WrappedSlice {
        if (self.max_width == 0) return null;

        if (self.text.len == 0) {
            if (self.emitted_empty) return null;
            self.emitted_empty = true;
            return .{ .slice = "", .width = 0 };
        }

        if (self.pos >= self.text.len) return null;

        if (self.options.mode == .none) {
            const rest = self.text[self.pos..];
            self.pos = self.text.len;
            const fit = grapheme.truncateToWidth(rest, self.max_width);
            return .{ .slice = fit.slice, .width = fit.width };
        }

        if (self.pos > 0 and self.options.trim_leading_spaces and self.options.mode == .word) {
            while (self.pos < self.text.len and self.text[self.pos] == ' ') {
                self.pos += 1;
            }
            if (self.pos >= self.text.len) return null;
        }

        const start = self.pos;
        var it = grapheme.GraphemeIterator.init(self.text[start..]);
        var width_acc: u16 = 0;
        var last_fit_end: usize = start;
        var last_fit_width: u16 = 0;
        var last_space_end: ?usize = null;
        var width_before_space: u16 = 0;
        var pending_ws_width: u16 = 0;

        while (it.next()) |g| {
            const next_end = start + it.index;
            if (g.width == 0) {
                last_fit_end = next_end;
                continue;
            }

            if (width_acc + g.width > self.max_width) {
                if (self.options.mode == .word) {
                    if (last_space_end) |sp_end| {
                        // Trim trailing space at the break point.
                        const trimmed = std.mem.trimEnd(u8, self.text[start..sp_end], " ");
                        self.pos = sp_end;
                        return .{
                            .slice = trimmed,
                            .width = width_before_space -| @as(u16, @intCast(self.text[start..sp_end].len - trimmed.len -| pending_ws_width)),
                        };
                    }
                }
                if (last_fit_end == start) {
                    // Single grapheme wider than max_width: consume it anyway to guarantee progress.
                    self.pos = next_end;
                    return .{ .slice = self.text[start..next_end], .width = g.width };
                }
                self.pos = last_fit_end;
                return .{ .slice = self.text[start..last_fit_end], .width = last_fit_width };
            }

            width_acc += g.width;
            last_fit_end = next_end;
            last_fit_width = width_acc;

            if (self.options.mode == .word and std.mem.eql(u8, g.slice, " ")) {
                last_space_end = next_end;
                width_before_space = width_acc - g.width;
                pending_ws_width = 0;
            }
        }

        self.pos = self.text.len;
        const out_slice = self.text[start..];
        return .{ .slice = out_slice, .width = grapheme.displayWidth(out_slice) };
    }
};

/// Truncates `text` into caller-provided `out_buf` according to `mode`, returning the formatted slice.
/// Never allocates heap memory.
pub fn truncateInto(
    text: []const u8,
    max_width: u16,
    mode: Truncation,
    out_buf: []u8,
) []const u8 {
    if (max_width == 0) return out_buf[0..0];
    const total_w = grapheme.displayWidth(text);
    if (total_w <= max_width) {
        const len = @min(text.len, out_buf.len);
        @memcpy(out_buf[0..len], text[0..len]);
        return out_buf[0..len];
    }

    const ellipsis = "…";
    switch (mode) {
        .clip => {
            const fit = grapheme.truncateToWidth(text, max_width);
            const len = @min(fit.slice.len, out_buf.len);
            @memcpy(out_buf[0..len], fit.slice[0..len]);
            return out_buf[0..len];
        },
        .end => {
            if (max_width == 1) {
                const len = @min(ellipsis.len, out_buf.len);
                @memcpy(out_buf[0..len], ellipsis[0..len]);
                return out_buf[0..len];
            }
            const fit = grapheme.truncateToWidth(text, max_width - 1);
            var w = std.Io.Writer.fixed(out_buf);
            w.writeAll(fit.slice) catch return out_buf[0..0];
            w.writeAll(ellipsis) catch {};
            return w.buffered();
        },
        .start => {
            if (max_width == 1) {
                const len = @min(ellipsis.len, out_buf.len);
                @memcpy(out_buf[0..len], ellipsis[0..len]);
                return out_buf[0..len];
            }
            const fit = grapheme.truncateStartToWidth(text, max_width - 1);
            var w = std.Io.Writer.fixed(out_buf);
            w.writeAll(ellipsis) catch return out_buf[0..0];
            w.writeAll(fit.slice) catch {};
            return w.buffered();
        },
        .middle => {
            if (max_width <= 2) {
                return truncateInto(text, max_width, .end, out_buf);
            }
            const left_w = (max_width - 1) / 2;
            const right_w = (max_width - 1) - left_w;
            const head = grapheme.truncateToWidth(text, left_w);
            const tail = grapheme.truncateStartToWidth(text, right_w);
            var w = std.Io.Writer.fixed(out_buf);
            w.writeAll(head.slice) catch return out_buf[0..0];
            w.writeAll(ellipsis) catch {};
            w.writeAll(tail.slice) catch {};
            return w.buffered();
        },
    }
}

test "wrapIterator splits at word boundaries and hard-breaks long tokens" {
    var it = WrapIterator.init("hello world zig", 7, .{ .mode = .word });
    const l1 = it.next().?;
    try testing.expectEqualStrings("hello", l1.slice);
    const l2 = it.next().?;
    try testing.expectEqualStrings("world", l2.slice);
    const l3 = it.next().?;
    try testing.expectEqualStrings("zig", l3.slice);
    try testing.expect(it.next() == null);

    var hard = WrapIterator.init("abcdefgh", 3, .{ .mode = .word });
    try testing.expectEqualStrings("abc", hard.next().?.slice);
    try testing.expectEqualStrings("def", hard.next().?.slice);
    try testing.expectEqualStrings("gh", hard.next().?.slice);
}

test "truncateInto supports end, start, middle, and clip modes" {
    var buf: [64]u8 = undefined;
    try testing.expectEqualStrings("hel…", truncateInto("hello world", 4, .end, &buf));
    try testing.expectEqualStrings("…rld", truncateInto("hello world", 4, .start, &buf));
    try testing.expectEqualStrings("he…ld", truncateInto("hello world", 5, .middle, &buf));
    try testing.expectEqualStrings("hello", truncateInto("hello world", 5, .clip, &buf));
}
