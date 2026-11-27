//! Text, spans, lines, Unicode display width, wrapping, and truncation.

const testing = @import("std").testing;

pub const grapheme = @import("grapheme.zig");
pub const span = @import("span.zig");
pub const line = @import("line.zig");
pub const text = @import("text.zig");
pub const wrapping = @import("wrapping.zig");
pub const masked = @import("masked.zig");
pub const locale = @import("locale.zig");
pub const font = @import("font.zig");

pub const Grapheme = grapheme.Grapheme;
pub const GraphemeIterator = grapheme.GraphemeIterator;
pub const TextDirection = grapheme.TextDirection;
pub const LocaleEntry = locale.LocaleEntry;
pub const Locale = locale.Locale;
pub const BitmapGlyph = font.BitmapGlyph;
pub const FontRenderMode = font.FontRenderMode;
pub const BitmapFont = font.BitmapFont;
pub const Span = span.Span;
pub const Line = line.Line;
pub const Text = text.Text;
pub const Masked = masked.Masked;
pub const WrapMode = wrapping.WrapMode;
pub const Truncation = wrapping.Truncation;
pub const WrapOptions = wrapping.WrapOptions;
pub const WrapIterator = wrapping.WrapIterator;

pub const displayWidth = grapheme.displayWidth;
pub const truncateToWidth = grapheme.truncateToWidth;
pub const truncateStartToWidth = grapheme.truncateStartToWidth;
pub const isRtlCodepoint = grapheme.isRtlCodepoint;
pub const detectDirection = grapheme.detectDirection;
pub const visualOrderInto = grapheme.visualOrderInto;
pub const truncateInto = wrapping.truncateInto;
pub const splitLinesIter = text.splitLinesIter;
pub const RawLineIterator = text.RawLineIterator;

test {
    testing.refAllDecls(@This());
    _ = grapheme;
    _ = span;
    _ = line;
    _ = text;
    _ = wrapping;
    _ = masked;
    _ = locale;
    _ = font;
}
