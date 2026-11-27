//! Styling, colors, border symbols, glyphs, and themes.

const testing = @import("std").testing;

pub const color = @import("color.zig");
pub const style = @import("style.zig");
pub const symbols = @import("symbols.zig");
pub const border = @import("border.zig");
pub const theme = @import("theme.zig");
pub const palette_mod = @import("palette.zig");

pub const Color = color.Color;
pub const Capability = color.Capability;
pub const Layer = color.Layer;
pub const Rgb = color.Rgb;
pub const Hsl = color.Hsl;
pub const Hsv = color.Hsv;
pub const Oklab = color.Oklab;
pub const Oklch = color.Oklch;
pub const Hex = color.Hex;
pub const Ansi4 = color.Ansi4;
pub const Ansi256 = color.Ansi256;

pub const Style = style.Style;
pub const Modifiers = style.Modifiers;
pub const UnderlineStyle = style.UnderlineStyle;

pub const BorderSides = border.BorderSides;
pub const BorderSet = border.BorderSet;
pub const BorderType = border.BorderType;
pub const MergeStrategy = border.MergeStrategy;

pub const Theme = theme.Theme;
pub const palette = palette_mod;

pub const LineSet = symbols.LineSet;
pub const BarSet = symbols.BarSet;
pub const ScrollbarSet = symbols.ScrollbarSet;
pub const CheckboxSet = symbols.CheckboxSet;
pub const RadioSet = symbols.RadioSet;
pub const TreeSet = symbols.TreeSet;
pub const IconSet = symbols.IconSet;
pub const Marker = symbols.Marker;

test {
    testing.refAllDecls(@This());
    testing.refAllDecls(color);
    testing.refAllDecls(style);
    testing.refAllDecls(symbols);
    testing.refAllDecls(border);
    testing.refAllDecls(theme);
    testing.refAllDecls(palette_mod);
}
