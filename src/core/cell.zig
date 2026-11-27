//! Terminal grid cell representation with inline grapheme storage.
//!
//! `Cell` holds up to 32 UTF-8 bytes inline so virtually every ASCII, CJK, box
//! drawing, and ZWJ emoji cluster requires zero heap allocation. Oversized
//! symbols (> 32 bytes) store an arena slice owned by the parent `Buffer`.

const std = @import("std");
const style_root = @import("../style/root.zig");
const grapheme = @import("../text/grapheme.zig");
const testing = std.testing;

pub const Color = style_root.Color;
pub const Style = style_root.Style;
pub const Modifiers = style_root.Modifiers;
pub const UnderlineStyle = style_root.UnderlineStyle;
pub const MergeStrategy = style_root.MergeStrategy;

/// Special directives controlling how `BufferDiff` treats a cell.
pub const CellDiffOption = union(enum) {
    /// Standard diffing behavior.
    none,
    /// Skip emitting this cell (e.g., trailing half of a wide glyph or external graphics region).
    skip,
    /// Always emit this cell even when equal to the previous frame.
    always_update,
    /// Override calculated cell display width (useful for escape/hyperlink payloads).
    forced_width: u16,
};

/// Maximum UTF-8 symbol length stored inline in a `Cell` without overflowing to a `Buffer` arena.
pub const inline_symbol_capacity: usize = 32;

/// A single character cell on the terminal grid.
pub const Cell = struct {
    /// Inline UTF-8 storage for grapheme clusters up to 32 bytes.
    symbol_buf: [inline_symbol_capacity]u8 = @splat(0),
    /// Byte length (`0` = default space `" "`, `1..32` = inline, `255` = `overflow` slice).
    symbol_len: u8 = 0,
    /// Arena-owned slice when a symbol exceeds `inline_symbol_capacity`.
    overflow: ?[]const u8 = null,
    /// Foreground color.
    fg: Color = .inherit,
    /// Background color.
    bg: Color = .inherit,
    /// Underline color.
    underline_color: Color = .inherit,
    /// Active text attributes.
    modifiers: Modifiers = .empty,
    /// Underline rendering variant.
    underline_style: UnderlineStyle = .none,
    /// Optional OSC 8 hyperlink URL attached to this cell (borrowed slice).
    hyperlink: ?[]const u8 = null,
    /// Diff behavior modifier.
    diff_option: CellDiffOption = .none,

    /// Default blank cell (`" "`, inherited style).
    pub const empty: Cell = .{};

    /// Creates a `Cell` from a comptime or runtime symbol <= 32 bytes (truncates gracefully if longer;
    /// use `Buffer` methods for arbitrary-length overflow storage).
    pub fn init(sym: []const u8) Cell {
        var cell: Cell = .{};
        cell.setSymbol(sym);
        return cell;
    }

    /// Returns the cell's UTF-8 symbol (`" "` when empty).
    pub fn symbol(self: *const Cell) []const u8 {
        if (self.symbol_len == 0) return " ";
        if (self.symbol_len == 255) return self.overflow orelse " ";
        return self.symbol_buf[0..self.symbol_len];
    }

    /// Sets the cell's symbol inline (clamping on grapheme/UTF-8 boundary if > 32 bytes).
    pub fn setSymbol(self: *Cell, sym: []const u8) void {
        self.overflow = null;
        if (sym.len == 0 or (sym.len == 1 and sym[0] == ' ')) {
            self.symbol_len = 0;
            return;
        }
        if (sym.len <= inline_symbol_capacity) {
            @memcpy(self.symbol_buf[0..sym.len], sym);
            self.symbol_len = @intCast(sym.len);
            return;
        }
        // Safe fallback: fit complete UTF-8 codepoints up to inline capacity.
        var valid_len: usize = 0;
        var it = grapheme.GraphemeIterator.init(sym);
        while (it.next()) |g| {
            if (valid_len + g.slice.len > inline_symbol_capacity) break;
            valid_len += g.slice.len;
        }
        if (valid_len > 0) {
            @memcpy(self.symbol_buf[0..valid_len], sym[0..valid_len]);
            self.symbol_len = @intCast(valid_len);
        } else {
            self.symbol_len = 0;
        }
    }

    /// Sets an arena-owned symbol slice of arbitrary length.
    pub fn setOverflowSymbol(self: *Cell, owned_slice: []const u8) void {
        if (owned_slice.len <= inline_symbol_capacity) {
            self.setSymbol(owned_slice);
            return;
        }
        self.overflow = owned_slice;
        self.symbol_len = 255;
    }

    /// Encodes a single Unicode codepoint into this cell.
    pub fn setChar(self: *Cell, cp: u21) void {
        var tmp: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(cp, &tmp) catch {
            self.setSymbol("\u{FFFD}");
            return;
        };
        self.setSymbol(tmp[0..len]);
    }

    /// Merges a box-drawing glyph onto this cell using `strategy`.
    pub fn mergeSymbol(self: *Cell, incoming: []const u8, strategy: MergeStrategy) void {
        if (self.symbol_len == 0) {
            self.setSymbol(incoming);
            return;
        }
        const merged = style_root.border.mergeSymbol(self.symbol(), incoming, strategy);
        self.setSymbol(merged);
    }

    /// Patches `s` onto the cell's current visual style.
    pub fn setStyle(self: *Cell, s: Style) void {
        const patched = self.style().patch(s);
        self.fg = patched.foreground;
        self.bg = patched.background;
        self.underline_color = patched.underline_color;
        self.modifiers = patched.activeModifiers();
        self.underline_style = patched.effectiveUnderline();
        self.hyperlink = patched.hyperlink;
    }

    /// Extracts the current visual `Style` of this cell.
    pub fn style(self: *const Cell) Style {
        return .{
            .foreground = self.fg,
            .background = self.bg,
            .underline_color = self.underline_color,
            .bold = self.modifiers.bold,
            .dim = self.modifiers.dim,
            .italic = self.modifiers.italic,
            .underline = self.underline_style == .single or self.modifiers.underline,
            .blink = self.modifiers.blink,
            .rapid_blink = self.modifiers.rapid_blink,
            .reverse = self.modifiers.reverse,
            .hidden = self.modifiers.hidden,
            .strikethrough = self.modifiers.strikethrough,
            .overline = self.modifiers.overline,
            .underline_style = self.underline_style,
            .hyperlink = self.hyperlink,
        };
    }

    /// Returns the terminal column width occupied by this cell.
    pub fn cellWidth(self: *const Cell) u16 {
        return switch (self.diff_option) {
            .forced_width => |w| @max(w, 1),
            else => grapheme.cellWidth(self.symbol()),
        };
    }

    /// Resets the cell back to `Cell.empty`.
    pub fn reset(self: *Cell) void {
        self.* = Cell.empty;
    }

    /// Compares two cells for semantic visual equality (`Cell.empty` equals `" "` with same style).
    pub fn eql(a: *const Cell, b: *const Cell) bool {
        return std.mem.eql(u8, a.symbol(), b.symbol()) and
            a.fg.eql(b.fg) and
            a.bg.eql(b.bg) and
            a.underline_color.eql(b.underline_color) and
            @as(u16, @bitCast(a.modifiers)) == @as(u16, @bitCast(b.modifiers)) and
            a.underline_style == b.underline_style and
            eqlOptSlice(a.hyperlink, b.hyperlink) and
            std.meta.eql(a.diff_option, b.diff_option);
    }

    fn eqlOptSlice(a: ?[]const u8, b: ?[]const u8) bool {
        if (a == null and b == null) return true;
        if (a == null or b == null) return false;
        return std.mem.eql(u8, a.?, b.?);
    }
};

test "cell inline symbol, equality, and style patching" {
    var a: Cell = .{};
    var b = Cell.init(" ");
    try testing.expect(a.eql(&b));
    try testing.expectEqualStrings(" ", a.symbol());

    a.setSymbol("👨‍👩‍👧‍👦");
    try testing.expectEqualStrings("👨‍👩‍👧‍👦", a.symbol());
    try testing.expectEqual(@as(u16, 2), a.cellWidth());

    a.setStyle(.{ .foreground = .red, .bold = true });
    try testing.expectEqual(Color.red, a.fg);
    try testing.expect(a.modifiers.bold);

    a.reset();
    try testing.expect(a.eql(&Cell.empty));
}
