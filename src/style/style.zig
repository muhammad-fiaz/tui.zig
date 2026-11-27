//! Text and cell styling primitives backed by `tint`.
//!
//! `Style` is plain value data with zero heap allocations. Colors default to
//! `.inherit` and modifiers compose predictably via `patch`.

const std = @import("std");
const tint = @import("tint");
const color_mod = @import("color.zig");
const testing = std.testing;

pub const Color = color_mod.Color;
pub const Capability = color_mod.Capability;

/// Underline decoration style.
pub const UnderlineStyle = enum(u3) {
    none = 0,
    single = 1,
    double = 2,
    curly = 3,
    dotted = 4,
    dashed = 5,
};

/// Bitmask of text modifiers used for explicit removal or compact comparison.
pub const Modifiers = packed struct(u16) {
    bold: bool = false,
    dim: bool = false,
    italic: bool = false,
    underline: bool = false,
    blink: bool = false,
    rapid_blink: bool = false,
    reverse: bool = false,
    hidden: bool = false,
    strikethrough: bool = false,
    overline: bool = false,
    fraktur: bool = false,
    frame: bool = false,
    encircle: bool = false,
    superscript: bool = false,
    subscript: bool = false,
    _padding: u1 = 0,

    /// No modifiers active.
    pub const empty: Modifiers = .{};

    /// Bitwise union of `a` and `b`.
    pub fn unionWith(a: Modifiers, b: Modifiers) Modifiers {
        return @bitCast(@as(u16, @bitCast(a)) | @as(u16, @bitCast(b)));
    }

    /// Modifiers present in `a` and not in `b`.
    pub fn difference(a: Modifiers, b: Modifiers) Modifiers {
        return @bitCast(@as(u16, @bitCast(a)) & ~@as(u16, @bitCast(b)));
    }

    /// True if all modifiers in `subset` are active in `self`.
    pub fn contains(self: Modifiers, subset: Modifiers) bool {
        const a: u16 = @bitCast(self);
        const b: u16 = @bitCast(subset);
        return (a & b) == b;
    }

    /// True when no modifiers are set.
    pub fn isEmpty(self: Modifiers) bool {
        return @as(u16, @bitCast(self)) == 0;
    }
};

/// Composable terminal cell and text style.
///
/// Unspecified colors default to `.inherit` so `Style{}` acts as an identity
/// style during composition (`patch`).
pub const Style = struct {
    /// Foreground text color (defaults to `.inherit`).
    foreground: Color = .inherit,
    /// Background cell color (defaults to `.inherit`).
    background: Color = .inherit,
    /// Underline color for terminals supporting SGR 58 (defaults to `.inherit`).
    underline_color: Color = .inherit,
    /// Bold / high intensity attribute.
    bold: bool = false,
    /// Dim / faint attribute.
    dim: bool = false,
    /// Italic text attribute.
    italic: bool = false,
    /// Standard single underline attribute.
    underline: bool = false,
    /// Slow blink attribute.
    blink: bool = false,
    /// Rapid blink attribute.
    rapid_blink: bool = false,
    /// Reverse video (swaps foreground and background).
    reverse: bool = false,
    /// Concealed / hidden text attribute.
    hidden: bool = false,
    /// Crossed-out / strikethrough attribute.
    strikethrough: bool = false,
    /// Overline attribute.
    overline: bool = false,
    /// Extended underline variant (`double`, `curly`, `dotted`, `dashed`).
    underline_style: UnderlineStyle = .none,
    /// Optional OSC 8 hyperlink target URI (borrowed; empty/null closes link).
    hyperlink: ?[]const u8 = null,
    /// Modifiers explicitly cleared when patching onto another `Style`.
    remove: Modifiers = .empty,

    /// Default empty style.
    pub const default: Style = .{};
    /// Style explicitly resetting colors and attributes to terminal defaults.
    pub const reset: Style = .{
        .foreground = .reset,
        .background = .reset,
        .underline_color = .reset,
        .remove = .{
            .bold = true,
            .dim = true,
            .italic = true,
            .underline = true,
            .blink = true,
            .rapid_blink = true,
            .reverse = true,
            .hidden = true,
            .strikethrough = true,
            .overline = true,
        },
    };

    /// Creates a style with only a foreground color.
    pub fn fg(color: Color) Style {
        return .{ .foreground = color };
    }

    /// Creates a style with only a background color.
    pub fn bg(color: Color) Style {
        return .{ .background = color };
    }

    /// Converts from a `tint.style.Style`.
    pub fn fromTint(s: tint.style.Style) Style {
        return .{
            .foreground = if (s.foreground) |c| Color.fromTint(c) else .inherit,
            .background = if (s.background) |c| Color.fromTint(c) else .inherit,
            .underline_color = if (s.underlineColor) |c| Color.fromTint(c) else .inherit,
            .bold = s.bold,
            .dim = s.dim,
            .italic = s.italic,
            .underline = s.underline,
            .blink = s.blink,
            .rapid_blink = s.rapidBlink,
            .reverse = s.reverse,
            .hidden = s.hidden,
            .strikethrough = s.strikethrough,
            .overline = s.overline,
        };
    }

    /// Returns a copy with `foreground` set to `color`.
    pub fn withFg(self: Style, color: Color) Style {
        var copy = self;
        copy.foreground = color;
        return copy;
    }

    /// Returns a copy with `background` set to `color`.
    pub fn withBg(self: Style, color: Color) Style {
        var copy = self;
        copy.background = color;
        return copy;
    }

    /// Returns a copy with `underline_color` set to `color`.
    pub fn withUnderlineColor(self: Style, color: Color) Style {
        var copy = self;
        copy.underline_color = color;
        return copy;
    }

    /// Returns a copy carrying an OSC 8 `url` hyperlink target.
    pub fn withLink(self: Style, url: ?[]const u8) Style {
        var copy = self;
        copy.hyperlink = url;
        return copy;
    }

    /// Returns a copy with bold enabled.
    pub fn withBold(self: Style) Style {
        var copy = self;
        copy.bold = true;
        copy.remove.bold = false;
        return copy;
    }

    /// Returns a copy with dim enabled.
    pub fn withDim(self: Style) Style {
        var copy = self;
        copy.dim = true;
        copy.remove.dim = false;
        return copy;
    }

    /// Returns a copy with italic enabled.
    pub fn withItalic(self: Style) Style {
        var copy = self;
        copy.italic = true;
        copy.remove.italic = false;
        return copy;
    }

    /// Returns a copy with single underline enabled.
    pub fn withUnderline(self: Style) Style {
        var copy = self;
        copy.underline = true;
        copy.underline_style = .single;
        copy.remove.underline = false;
        return copy;
    }

    /// Returns a copy with the specified `UnderlineStyle`.
    pub fn withUnderlineStyle(self: Style, variant: UnderlineStyle) Style {
        var copy = self;
        copy.underline_style = variant;
        copy.underline = variant == .single;
        if (variant != .none) copy.remove.underline = false;
        return copy;
    }

    /// Returns a copy with reverse video enabled.
    pub fn withReverse(self: Style) Style {
        var copy = self;
        copy.reverse = true;
        copy.remove.reverse = false;
        return copy;
    }

    /// Returns a copy with strikethrough enabled.
    pub fn withStrikethrough(self: Style) Style {
        var copy = self;
        copy.strikethrough = true;
        copy.remove.strikethrough = false;
        return copy;
    }

    /// Returns the effective `UnderlineStyle` normalized across `underline` and `underline_style`.
    pub fn effectiveUnderline(self: Style) UnderlineStyle {
        if (self.underline_style != .none) return self.underline_style;
        return if (self.underline) .single else .none;
    }

    /// Packs the active modifier booleans into a `Modifiers` bitmask.
    pub fn activeModifiers(self: Style) Modifiers {
        return .{
            .bold = self.bold,
            .dim = self.dim,
            .italic = self.italic,
            .underline = self.effectiveUnderline() != .none,
            .blink = self.blink,
            .rapid_blink = self.rapid_blink,
            .reverse = self.reverse,
            .hidden = self.hidden,
            .strikethrough = self.strikethrough,
            .overline = self.overline,
        };
    }

    /// Applies `other` on top of `self`. Non-inherit colors replace; `other`'s
    /// active modifiers are added while `other.remove` modifiers are cleared.
    pub fn patch(self: Style, other: Style) Style {
        var out = self;
        if (!other.foreground.isInherit()) out.foreground = other.foreground;
        if (!other.background.isInherit()) out.background = other.background;
        if (!other.underline_color.isInherit()) out.underline_color = other.underline_color;

        if (other.remove.bold) out.bold = false;
        if (other.remove.dim) out.dim = false;
        if (other.remove.italic) out.italic = false;
        if (other.remove.underline) {
            out.underline = false;
            out.underline_style = .none;
        }
        if (other.remove.blink) out.blink = false;
        if (other.remove.rapid_blink) out.rapid_blink = false;
        if (other.remove.reverse) out.reverse = false;
        if (other.remove.hidden) out.hidden = false;
        if (other.remove.strikethrough) out.strikethrough = false;
        if (other.remove.overline) out.overline = false;

        if (other.bold) out.bold = true;
        if (other.dim) out.dim = true;
        if (other.italic) out.italic = true;
        if (other.underline_style != .none) {
            out.underline_style = other.underline_style;
            out.underline = other.underline_style == .single;
        } else if (other.underline) {
            out.underline = true;
            out.underline_style = .single;
        }
        if (other.blink) out.blink = true;
        if (other.rapid_blink) out.rapid_blink = true;
        if (other.reverse) out.reverse = true;
        if (other.hidden) out.hidden = true;
        if (other.strikethrough) out.strikethrough = true;
        if (other.overline) out.overline = true;
        if (other.hyperlink) |hl| out.hyperlink = hl;

        out.remove = self.remove.difference(other.activeModifiers()).unionWith(other.remove);
        return out;
    }

    /// Converts to a `tint.style.Style`, optionally downgrading colors for `capability`.
    pub fn toTint(self: Style, capability: Capability) tint.style.Style {
        return .{
            .foreground = self.foreground.downgrade(capability).toTint(),
            .background = self.background.downgrade(capability).toTint(),
            .underlineColor = self.underline_color.downgrade(capability).toTint(),
            .bold = self.bold,
            .dim = self.dim,
            .italic = self.italic,
            .underline = self.effectiveUnderline() != .none,
            .blink = self.blink,
            .rapidBlink = self.rapid_blink,
            .reverse = self.reverse,
            .hidden = self.hidden,
            .strikethrough = self.strikethrough,
            .overline = self.overline,
        };
    }

    /// Returns a normalized copy with colors downgraded to `capability`.
    pub fn downgrade(self: Style, capability: Capability) Style {
        var out = self;
        out.foreground = self.foreground.downgrade(capability);
        out.background = self.background.downgrade(capability);
        out.underline_color = self.underline_color.downgrade(capability);
        return out;
    }

    /// Blends foreground and background colors smoothly toward `other` (`ratio` in `0.0..1.0`).
    pub fn mix(self: Style, other: Style, ratio: f64) Style {
        var out = self;
        out.foreground = self.foreground.mix(other.foreground, ratio);
        out.background = self.background.mix(other.background, ratio);
        return out;
    }

    /// Equality check ignoring `remove` mask when comparing resolved cell styles.
    pub fn eql(a: Style, b: Style) bool {
        return a.foreground.eql(b.foreground) and
            a.background.eql(b.background) and
            a.underline_color.eql(b.underline_color) and
            a.bold == b.bold and
            a.dim == b.dim and
            a.italic == b.italic and
            a.effectiveUnderline() == b.effectiveUnderline() and
            a.blink == b.blink and
            a.rapid_blink == b.rapid_blink and
            a.reverse == b.reverse and
            a.hidden == b.hidden and
            a.strikethrough == b.strikethrough and
            a.overline == b.overline;
    }

    /// Emits the minimal ANSI/SGR escape sequences needed to transition terminal
    /// state from `prev` to `next` under `capability`.
    pub fn writeAnsiDiff(
        prev: Style,
        next: Style,
        capability: Capability,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        const p_fg = resolvedColor(prev.foreground, capability);
        const n_fg = resolvedColor(next.foreground, capability);
        const p_bg = resolvedColor(prev.background, capability);
        const n_bg = resolvedColor(next.background, capability);
        const p_ul = resolvedColor(prev.underline_color, capability);
        const n_ul = resolvedColor(next.underline_color, capability);

        const fg_changed = !p_fg.eql(n_fg);
        const bg_changed = !p_bg.eql(n_bg);
        const ul_changed = !p_ul.eql(n_ul);

        const p_mods = prev.activeModifiers();
        const n_mods = next.activeModifiers();
        const p_u = prev.effectiveUnderline();
        const n_u = next.effectiveUnderline();

        if (!fg_changed and !bg_changed and !ul_changed and
            @as(u16, @bitCast(p_mods)) == @as(u16, @bitCast(n_mods)) and p_u == n_u)
        {
            return;
        }

        // Handle attribute resets first because SGR 22/23/25 clear paired attributes.
        const reset_intensity = (p_mods.bold and !n_mods.bold) or (p_mods.dim and !n_mods.dim);
        const reset_blink = (p_mods.blink and !n_mods.blink) or (p_mods.rapid_blink and !n_mods.rapid_blink);

        if (reset_intensity) try writer.writeAll(tint.ansi.reset.bold);
        if (p_mods.italic and !n_mods.italic) try writer.writeAll(tint.ansi.reset.italic);
        if (p_u != .none and n_u == .none) try writer.writeAll(tint.ansi.reset.underline);
        if (reset_blink) try writer.writeAll(tint.ansi.reset.blink);
        if (p_mods.reverse and !n_mods.reverse) try writer.writeAll(tint.ansi.reset.reverse);
        if (p_mods.hidden and !n_mods.hidden) try writer.writeAll(tint.ansi.reset.hidden);
        if (p_mods.strikethrough and !n_mods.strikethrough) try writer.writeAll(tint.ansi.reset.strikethrough);
        if (p_mods.overline and !n_mods.overline) try writer.writeAll(tint.ansi.reset.overline);

        if (fg_changed) {
            if (n_fg.sequence(.foreground, capability)) |seq| {
                try writer.writeAll(seq.slice());
            } else {
                try writer.writeAll(tint.ansi.reset.foreground);
            }
        }
        if (bg_changed) {
            if (n_bg.sequence(.background, capability)) |seq| {
                try writer.writeAll(seq.slice());
            } else {
                try writer.writeAll(tint.ansi.reset.background);
            }
        }
        if (ul_changed) {
            if (n_ul.sequence(.underline, capability)) |seq| {
                try writer.writeAll(seq.slice());
            } else {
                try writer.writeAll(tint.ansi.reset.underlineColor);
            }
        }

        if (n_mods.bold and (!p_mods.bold or reset_intensity)) try writer.writeAll("\x1b[1m");
        if (n_mods.dim and (!p_mods.dim or reset_intensity)) try writer.writeAll("\x1b[2m");
        if (n_mods.italic and !p_mods.italic) try writer.writeAll("\x1b[3m");
        if (n_u != .none and n_u != p_u) {
            const code = switch (n_u) {
                .none => unreachable,
                .single => "\x1b[4m",
                .double => "\x1b[4:2m",
                .curly => "\x1b[4:3m",
                .dotted => "\x1b[4:4m",
                .dashed => "\x1b[4:5m",
            };
            try writer.writeAll(code);
        }
        if (n_mods.blink and (!p_mods.blink or reset_blink)) try writer.writeAll("\x1b[5m");
        if (n_mods.rapid_blink and (!p_mods.rapid_blink or reset_blink)) try writer.writeAll("\x1b[6m");
        if (n_mods.reverse and !p_mods.reverse) try writer.writeAll("\x1b[7m");
        if (n_mods.hidden and !p_mods.hidden) try writer.writeAll("\x1b[8m");
        if (n_mods.strikethrough and !p_mods.strikethrough) try writer.writeAll("\x1b[9m");
        if (n_mods.overline and !p_mods.overline) try writer.writeAll("\x1b[53m");
    }
};

fn resolvedColor(c: Color, capability: Capability) Color {
    if (c.isInherit() or c.isReset()) return .reset;
    return c.downgrade(capability);
}

test "style patch composes colors and modifiers" {
    const base = Style{ .foreground = .white, .background = .blue, .bold = true };
    const overlay = Style{ .foreground = .yellow, .italic = true, .remove = .{ .bold = true } };
    const merged = base.patch(overlay);

    try testing.expectEqual(Color.yellow, merged.foreground);
    try testing.expectEqual(Color.blue, merged.background);
    try testing.expect(!merged.bold);
    try testing.expect(merged.italic);
}

test "style toTint emits expected SGR" {
    const s = Style.fg(.red).withBg(.black).withBold();
    const t = s.toTint(.trueColor);
    try testing.expectEqualStrings("\x1b[31;40;1m", t.toAnsi().slice());
}

test "writeAnsiDiff emits minimal transitions" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const a = Style{ .foreground = .red, .bold = true, .dim = true };
    const b = Style{ .foreground = .red, .bold = true };
    try Style.writeAnsiDiff(a, b, .trueColor, &writer);
    // Bold and dim share SGR 22 reset, so bold must be re-applied without re-emitting red.
    try testing.expectEqualStrings("\x1b[22m\x1b[1m", writer.buffered());

    var writer2 = std.Io.Writer.fixed(&buf);
    try Style.writeAnsiDiff(b, b, .trueColor, &writer2);
    try testing.expectEqual(@as(usize, 0), writer2.buffered().len);

    // Extended underline styles + underline color + reverse highlight transition cleanly.
    const ul_a = Style.fg(.cyan).withUnderlineStyle(.curly).withUnderlineColor(.yellow).withReverse();
    const ul_b = Style.fg(.cyan).withUnderlineStyle(.double);
    var writer3 = std.Io.Writer.fixed(&buf);
    try Style.writeAnsiDiff(.default, ul_a, .trueColor, &writer3);
    try testing.expect(std.mem.indexOf(u8, writer3.buffered(), "\x1b[4:3m") != null);
    try testing.expect(std.mem.indexOf(u8, writer3.buffered(), "\x1b[7m") != null);
    var writer4 = std.Io.Writer.fixed(&buf);
    try Style.writeAnsiDiff(ul_a, ul_b, .trueColor, &writer4);
    try testing.expect(std.mem.indexOf(u8, writer4.buffered(), "\x1b[27m") != null);
    try testing.expect(std.mem.indexOf(u8, writer4.buffered(), "\x1b[4:2m") != null);
}
