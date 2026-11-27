//! Zero-allocation masked secret text helper (`Masked`) for sensitive fields.

const std = @import("std");
const grapheme = @import("grapheme.zig");
const span_mod = @import("span.zig");
const style_root = @import("../style/root.zig");
const testing = std.testing;

pub const Span = span_mod.Span;
pub const Style = style_root.Style;

/// Masks each visible grapheme cluster of `value` using `mask_char` (default `"•"`).
/// Renders directly into caller-provided stack memory without heap allocation.
pub const Masked = struct {
    value: []const u8,
    mask_char: []const u8 = "•",
    style: Style = .{},

    /// Initializes a `Masked` view over `secret` with default `"•"` glyph.
    pub fn init(secret: []const u8) Masked {
        return .{ .value = secret };
    }

    /// Number of visible mask glyphs matching grapheme count of `value`.
    pub fn graphemeCount(self: Masked) usize {
        var n: usize = 0;
        var it = grapheme.GraphemeIterator.init(self.value);
        while (it.next()) |_| n += 1;
        return n;
    }

    /// Formats the masked representation into caller buffer `out` and returns the formatted slice.
    pub fn formatInto(self: Masked, out: []u8) []const u8 {
        const count = self.graphemeCount();
        var written: usize = 0;
        for (0..count) |_| {
            if (written + self.mask_char.len > out.len) break;
            @memcpy(out[written .. written + self.mask_char.len], self.mask_char);
            written += self.mask_char.len;
        }
        return out[0..written];
    }

    /// Formats into `out` and wraps as a styled `Span`.
    pub fn toSpan(self: Masked, out: []u8) Span {
        return Span.styled(self.formatInto(out), self.style);
    }
};

test "masked formats utf8 secrets without allocation" {
    const m = Masked.init("p@ss🔑");
    try testing.expectEqual(@as(usize, 5), m.graphemeCount());
    var buf: [32]u8 = undefined;
    try testing.expectEqualStrings("•••••", m.formatInto(&buf));
}
