//! Terminal color abstraction backed by `tint`.
//!
//! Colors are plain values with no heap ownership. `.inherit` leaves an existing
//! cell color intact, `.reset` restores the terminal's default color, and all
//! concrete color spaces delegate conversion, perceptual metrics, mixing, and
//! capability downgrading to `tint`.

const std = @import("std");
const tint = @import("tint");
const testing = std.testing;

/// Terminal color capability level supported by the output backend.
pub const Capability = tint.ansi.Capability;
/// Color layer target (foreground, background, or underline).
pub const Layer = tint.ansi.Layer;
/// 16-color ANSI palette enum plus `.default`.
pub const Ansi4 = tint.color.Ansi4;
/// Indexed 256-color entry (`0..255`).
pub const Ansi256 = tint.color.Ansi256;
/// 24-bit sRGB color triple (`0..255` per channel).
pub const Rgb = tint.color.Rgb;
/// 24-bit hexadecimal color value (`0xRRGGBB`).
pub const Hex = tint.color.Hex;
/// HSL color space (`h: 0..359`, `s: 0..100`, `l: 0..100`).
pub const Hsl = tint.color.Hsl;
/// HSV color space (`h: 0..359`, `s: 0..100`, `v: 0..100`).
pub const Hsv = tint.color.Hsv;
/// Perceptual OKLab color space.
pub const Oklab = tint.color.Oklab;
/// Cylindrical perceptual OKLCH color space (`l: 0..1`, `c: chroma`, `h: 0..360`).
pub const Oklch = tint.color.Oklch;
/// Color interpolation space.
pub const Space = tint.color.Space;
/// Hue circle traversal mode for `mixHue`.
pub const HuePath = tint.color.HuePath;

/// Terminal color value supporting inheritance, terminal default reset, ANSI
/// 4-bit, 256-color indexed, truecolor RGB/Hex, HSL, HSV, and named CSS colors.
pub const Color = union(enum) {
    /// Leaves the underlying color unchanged when patching or compositing.
    inherit,
    /// Concrete color value represented by `tint.color.Color`.
    tint: tint.color.Color,

    /// Restores the terminal's own default foreground, background, or underline color.
    pub const reset: Color = .{ .tint = tint.color.ansi4.default };

    /// Standard ANSI black (SGR 30/40).
    pub const black: Color = .{ .tint = tint.color.ansi4.black };
    /// Standard ANSI red (SGR 31/41).
    pub const red: Color = .{ .tint = tint.color.ansi4.red };
    /// Standard ANSI green (SGR 32/42).
    pub const green: Color = .{ .tint = tint.color.ansi4.green };
    /// Standard ANSI yellow (SGR 33/43).
    pub const yellow: Color = .{ .tint = tint.color.ansi4.yellow };
    /// Standard ANSI blue (SGR 34/44).
    pub const blue: Color = .{ .tint = tint.color.ansi4.blue };
    /// Standard ANSI magenta (SGR 35/45).
    pub const magenta: Color = .{ .tint = tint.color.ansi4.magenta };
    /// Standard ANSI cyan (SGR 36/46).
    pub const cyan: Color = .{ .tint = tint.color.ansi4.cyan };
    /// Standard ANSI white / light gray (SGR 37/47).
    pub const white: Color = .{ .tint = tint.color.ansi4.white };

    /// Standard ANSI bright black / dark gray (SGR 90/100).
    pub const bright_black: Color = .{ .tint = tint.color.ansi4.brightBlack };
    /// Standard ANSI bright red (SGR 91/101).
    pub const bright_red: Color = .{ .tint = tint.color.ansi4.brightRed };
    /// Standard ANSI bright green (SGR 92/102).
    pub const bright_green: Color = .{ .tint = tint.color.ansi4.brightGreen };
    /// Standard ANSI bright yellow (SGR 93/103).
    pub const bright_yellow: Color = .{ .tint = tint.color.ansi4.brightYellow };
    /// Standard ANSI bright blue (SGR 94/104).
    pub const bright_blue: Color = .{ .tint = tint.color.ansi4.brightBlue };
    /// Standard ANSI bright magenta (SGR 95/105).
    pub const bright_magenta: Color = .{ .tint = tint.color.ansi4.brightMagenta };
    /// Standard ANSI bright cyan (SGR 96/106).
    pub const bright_cyan: Color = .{ .tint = tint.color.ansi4.brightCyan };
    /// Standard ANSI bright white (SGR 97/107).
    pub const bright_white: Color = .{ .tint = tint.color.ansi4.brightWhite };

    /// Alias for `white` (ANSI palette gray).
    pub const gray: Color = white;
    /// Alias for `bright_black` (ANSI palette dark gray).
    pub const dark_gray: Color = bright_black;
    /// Alias for `bright_red`.
    pub const light_red: Color = bright_red;
    /// Alias for `bright_green`.
    pub const light_green: Color = bright_green;
    /// Alias for `bright_yellow`.
    pub const light_yellow: Color = bright_yellow;
    /// Alias for `bright_blue`.
    pub const light_blue: Color = bright_blue;
    /// Alias for `bright_magenta`.
    pub const light_magenta: Color = bright_magenta;
    /// Alias for `bright_cyan`.
    pub const light_cyan: Color = bright_cyan;

    /// Named CSS/X11 truecolor constants delegated from `tint.color`.
    pub const coral: Color = .{ .tint = tint.color.coral };
    pub const crimson: Color = .{ .tint = tint.color.crimson };
    pub const gold: Color = .{ .tint = tint.color.gold };
    pub const orange: Color = .{ .tint = tint.color.orange };
    pub const orange_red: Color = .{ .tint = tint.color.orangeRed };
    pub const pink: Color = .{ .tint = tint.color.pink };
    pub const hot_pink: Color = .{ .tint = tint.color.hotPink };
    pub const deep_pink: Color = .{ .tint = tint.color.deepPink };
    pub const purple: Color = .{ .tint = tint.color.purple };
    pub const rebecca_purple: Color = .{ .tint = tint.color.rebeccaPurple };
    pub const indigo: Color = .{ .tint = tint.color.indigo };
    pub const violet: Color = .{ .tint = tint.color.violet };
    pub const orchid: Color = .{ .tint = tint.color.orchid };
    pub const plum: Color = .{ .tint = tint.color.plum };
    pub const teal: Color = .{ .tint = tint.color.teal };
    pub const navy: Color = .{ .tint = tint.color.navy };
    pub const royal_blue: Color = .{ .tint = tint.color.royalBlue };
    pub const sky_blue: Color = .{ .tint = tint.color.skyBlue };
    pub const deep_sky_blue: Color = .{ .tint = tint.color.deepSkyBlue };
    pub const dodger_blue: Color = .{ .tint = tint.color.dodgerBlue };
    pub const steel_blue: Color = .{ .tint = tint.color.steelBlue };
    pub const cornflower_blue: Color = .{ .tint = tint.color.cornflowerBlue };
    pub const slate_blue: Color = .{ .tint = tint.color.slateBlue };
    pub const slate_gray: Color = .{ .tint = tint.color.slateGray };
    pub const turquoise: Color = .{ .tint = tint.color.turquoise };
    pub const aquamarine: Color = .{ .tint = tint.color.aquamarine };
    pub const sea_green: Color = .{ .tint = tint.color.seaGreen };
    pub const spring_green: Color = .{ .tint = tint.color.springGreen };
    pub const forest_green: Color = .{ .tint = tint.color.forestGreen };
    pub const lime: Color = .{ .tint = tint.color.lime };
    pub const tomato: Color = .{ .tint = tint.color.tomato };
    pub const salmon: Color = .{ .tint = tint.color.salmon };
    pub const silver: Color = .{ .tint = tint.color.silver };
    pub const lavender: Color = .{ .tint = tint.color.lavender };
    pub const khaki: Color = .{ .tint = tint.color.khaki };
    pub const olive: Color = .{ .tint = tint.color.olive };
    pub const maroon: Color = .{ .tint = tint.color.maroon };
    pub const chocolate: Color = .{ .tint = tint.color.chocolate };
    pub const wheat: Color = .{ .tint = tint.color.wheat };

    /// Constructs a 24-bit RGB color.
    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .tint = tint.color.rgb(r, g, b) };
    }

    /// Constructs a 24-bit color from a `0xRRGGBB` integer.
    pub fn hex(value: u24) Color {
        return .{ .tint = tint.color.hex(value) };
    }

    /// Constructs an HSL color (`h` wraps at 360; `s` and `l` are in `0..100`).
    pub fn hsl(h: u16, s: u8, l: u8) Color {
        return .{ .tint = tint.color.hsl(h, s, l) };
    }

    /// Constructs an HSV color (`h` wraps at 360; `s` and `v` are in `0..100`).
    pub fn hsv(h: u16, s: u8, v: u8) Color {
        return .{ .tint = tint.color.hsv(h, s, v) };
    }

    /// Constructs a 24-bit TrueColor converted from CSS Color 4 OKLCH (`l: 0..1`, `c >= 0`, `h: 0..360`).
    pub fn oklch(l: f64, c: f64, h: f64) Color {
        const srgb = (Oklch{ .l = l, .c = c, .h = h }).toOklab().toRgb();
        return rgb(srgb.r, srgb.g, srgb.b);
    }

    /// Constructs an indexed 256-palette color (`0..255`).
    pub fn indexed(index: u8) Color {
        return .{ .tint = tint.color.ansi256.index(index) };
    }

    /// Alias for `indexed`.
    pub fn ansi256(index: u8) Color {
        return indexed(index);
    }

    /// Constructs a 4-bit ANSI color.
    pub fn ansi(a: Ansi4) Color {
        return .{ .tint = .{ .ansi4 = a } };
    }

    /// Wraps an existing `tint.color.Color`.
    pub fn fromTint(c: tint.color.Color) Color {
        return .{ .tint = c };
    }

    /// Parses a CSS/X11 color name or hex string (`#RGB`, `#RRGGBB`, `0xRRGGBB`).
    /// Also accepts `"inherit"` and `"reset"` / `"default"`.
    pub fn parse(text: []const u8) ?Color {
        if (std.ascii.eqlIgnoreCase(text, "inherit")) return .inherit;
        if (std.ascii.eqlIgnoreCase(text, "reset") or std.ascii.eqlIgnoreCase(text, "default")) return .reset;
        if (tint.color.parse(text)) |c| return .{ .tint = c };
        return null;
    }

    /// Returns the underlying `tint.color.Color`, or `null` when `.inherit`.
    pub fn toTint(self: Color) ?tint.color.Color {
        return switch (self) {
            .inherit => null,
            .tint => |c| c,
        };
    }

    /// True if this color is `.inherit`.
    pub fn isInherit(self: Color) bool {
        return self == .inherit;
    }

    /// True if this color explicitly resets to the terminal default.
    pub fn isReset(self: Color) bool {
        return switch (self) {
            .tint => |c| switch (c) {
                .ansi4 => |a| a == .default,
                else => false,
            },
            .inherit => false,
        };
    }

    /// Downgrades this color to the closest representation supported by `capability`.
    /// `.inherit` remains `.inherit`.
    pub fn downgrade(self: Color, capability: Capability) Color {
        return switch (self) {
            .inherit => .inherit,
            .tint => |c| switch (c) {
                .ansi4 => |a| if (a == .default)
                    self
                else switch (capability) {
                    .none => .reset,
                    .ansi16, .ansi256, .trueColor => self,
                },
                .ansi256 => switch (capability) {
                    .none => .reset,
                    .ansi16 => .{ .tint = .{ .ansi4 = c.nearestAnsi16() } },
                    .ansi256, .trueColor => self,
                },
                .rgb, .hex, .hsl, .hsv => .{ .tint = c.downgrade(capability) },
            },
        };
    }

    /// Renders an ANSI SGR sequence for `layer` at `capability`.
    /// Returns `null` when `.inherit`.
    pub fn sequence(self: Color, layer: Layer, capability: Capability) ?tint.ansi.Sequence {
        const concrete = self.downgrade(capability).toTint() orelse return null;
        return concrete.sequence(layer);
    }

    /// Converts concrete colors to sRGB; returns `null` for `.inherit`.
    pub fn toRgb(self: Color) ?Rgb {
        const concrete = self.toTint() orelse return null;
        return concrete.toRgb();
    }

    /// WCAG relative luminance (`0.0..1.0`), or `null` for `.inherit`.
    pub fn luminance(self: Color) ?f64 {
        const concrete = self.toTint() orelse return null;
        return concrete.luminance();
    }

    /// WCAG contrast ratio (`1.0..21.0`) between two concrete colors.
    pub fn contrastRatio(self: Color, other: Color) ?f64 {
        const a = self.toTint() orelse return null;
        const b = other.toTint() orelse return null;
        return a.contrastRatio(b);
    }

    /// Blends towards `other` in sRGB (`ratio` clamped to `0.0..1.0`).
    pub fn mix(self: Color, other: Color, ratio: f64) Color {
        const a = self.toTint() orelse return other;
        const b = other.toTint() orelse return self;
        return .{ .tint = a.mix(b, ratio) };
    }

    /// Blends towards `other` in the specified `Space`.
    pub fn mixIn(self: Color, other: Color, ratio: f64, space: Space) Color {
        const a = self.toTint() orelse return other;
        const b = other.toTint() orelse return self;
        return .{ .tint = a.mixIn(b, ratio, space) };
    }

    /// Increases HSL lightness by `amount` (`0.0..1.0`).
    pub fn lighten(self: Color, amount: f64) Color {
        const concrete = self.toTint() orelse return .inherit;
        return .{ .tint = concrete.lighten(amount) };
    }

    /// Decreases HSL lightness by `amount` (`0.0..1.0`).
    pub fn darken(self: Color, amount: f64) Color {
        const concrete = self.toTint() orelse return .inherit;
        return .{ .tint = concrete.darken(amount) };
    }

    /// Equality check across color variants.
    pub fn eql(a: Color, b: Color) bool {
        return std.meta.eql(a, b);
    }
};

test "color constants and constructors resolve cleanly" {
    const c1: Color = .red;
    const c2: Color = .rgb(255, 100, 20);
    const c3: Color = .hex(0x7C3AED);
    const c4: Color = .indexed(196);
    const c5: Color = .inherit;
    const c6: Color = .reset;

    try testing.expect(!c1.isInherit());
    try testing.expect(c5.isInherit());
    try testing.expect(c6.isReset());
    try testing.expectEqualStrings("\x1b[31m", c1.sequence(.foreground, .trueColor).?.slice());
    try testing.expectEqualStrings("\x1b[38;2;255;100;20m", c2.sequence(.foreground, .trueColor).?.slice());
    try testing.expectEqualStrings("\x1b[38;2;124;58;237m", c3.sequence(.foreground, .trueColor).?.slice());
    try testing.expectEqualStrings("\x1b[38;5;196m", c4.sequence(.foreground, .ansi256).?.slice());
    try testing.expect(c5.sequence(.foreground, .trueColor) == null);
    try testing.expectEqualStrings("\x1b[39m", c6.sequence(.foreground, .trueColor).?.slice());
}

test "color downgrade and parse honor capability" {
    const brand: Color = .rgb(255, 0, 0);
    try testing.expectEqualStrings("\x1b[39m", brand.downgrade(.none).sequence(.foreground, .none).?.slice());
    try testing.expectEqualStrings("\x1b[91m", brand.downgrade(.ansi16).sequence(.foreground, .ansi16).?.slice());
    try testing.expect(std.mem.startsWith(u8, brand.downgrade(.ansi256).sequence(.foreground, .ansi256).?.slice(), "\x1b[38;5;"));

    try testing.expectEqual(Color.inherit, Color.parse("inherit").?);
    try testing.expectEqual(Color.reset, Color.parse("reset").?);
    try testing.expect(Color.parse("#ff6600") != null);
    try testing.expect(Color.parse("rebeccaPurple") != null);
    try testing.expect(Color.parse("not-a-color") == null);

    const oklch_c = Color.oklch(0.637, 0.237, 25.331);
    const srgb = oklch_c.toRgb().?;
    try testing.expect(srgb.r > 200 and srgb.g < 100 and srgb.b < 100);
}

test "color metrics and mixing delegate to tint" {
    const ratio = Color.bright_white.contrastRatio(.black).?;
    try testing.expect(ratio > 20.0);
    try testing.expect(Color.white.contrastRatio(.black).? > 8.0);
    const mid = Color.rgb(0, 0, 0).mix(.rgb(255, 255, 255), 0.5).toRgb().?;
    try testing.expectEqual(@as(u8, 128), mid.r);
}
