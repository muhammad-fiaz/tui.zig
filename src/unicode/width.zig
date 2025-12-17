//! Display width calculation module.
//!
//! Re-exports from unicode.zig for convenient access.

const unicode = @import("unicode.zig");

pub const charWidth = unicode.charWidth;
pub const stringWidth = unicode.stringWidth;
pub const graphemeWidth = unicode.graphemeWidth;
pub const truncateToWidth = unicode.truncateToWidth;
pub const padToWidth = unicode.padToWidth;
pub const GraphemeIterator = unicode.GraphemeIterator;

test {
    _ = unicode;
}
