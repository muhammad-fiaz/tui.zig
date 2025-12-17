//! Color system for TUI.zig
//!
//! Supports:
//! - Basic 16 colors
//! - 256 color palette
//! - True color (24-bit RGB)
//! - Named colors
//! - Color blending and manipulation

const std = @import("std");

/// A color that can be rendered in the terminal
pub const Color = union(enum) {
    /// Default terminal color
    default,

    /// Basic 16-color palette (0-15)
    basic: Basic,

    /// 256-color palette (0-255)
    palette: u8,

    /// True color RGB (24-bit)
    rgb: RGB,

    // Convenience constants
    pub const black = Color{ .basic = .black };
    pub const red = Color{ .basic = .red };
    pub const green = Color{ .basic = .green };
    pub const yellow = Color{ .basic = .yellow };
    pub const blue = Color{ .basic = .blue };
    pub const magenta = Color{ .basic = .magenta };
    pub const cyan = Color{ .basic = .cyan };
    pub const white = Color{ .basic = .white };
    pub const gray = Color{ .basic = .gray };
    pub const dark_gray = Color{ .basic = .bright_black };
    pub const light_red = Color{ .basic = .bright_red };
    pub const light_green = Color{ .basic = .bright_green };
    pub const light_yellow = Color{ .basic = .bright_yellow };
    pub const light_blue = Color{ .basic = .bright_blue };
    pub const light_magenta = Color{ .basic = .bright_magenta };
    pub const light_cyan = Color{ .basic = .bright_cyan };
    pub const light_white = Color{ .basic = .bright_white };

    /// Basic 16-color palette
    pub const Basic = enum(u8) {
        black = 0,
        red = 1,
        green = 2,
        yellow = 3,
        blue = 4,
        magenta = 5,
        cyan = 6,
        white = 7,
        bright_black = 8,
        bright_red = 9,
        bright_green = 10,
        bright_yellow = 11,
        bright_blue = 12,
        bright_magenta = 13,
        bright_cyan = 14,
        bright_white = 15,

        // Aliases
        pub const gray = Basic.bright_black;
        pub const grey = Basic.bright_black;
    };

    /// RGB color value
    pub const RGB = struct {
        r: u8,
        g: u8,
        b: u8,

        /// Create an RGB color from hex value (e.g., 0xFF5733)
        pub fn fromHex(hex_value: u24) RGB {
            return .{
                .r = @truncate((hex_value >> 16) & 0xFF),
                .g = @truncate((hex_value >> 8) & 0xFF),
                .b = @truncate(hex_value & 0xFF),
            };
        }

        /// Convert to hex value
        pub fn toHex(self: RGB) u24 {
            return (@as(u24, self.r) << 16) | (@as(u24, self.g) << 8) | @as(u24, self.b);
        }

        /// Blend two colors together
        pub fn blend(self: RGB, other: RGB, factor: f32) RGB {
            const f = std.math.clamp(factor, 0.0, 1.0);
            const inv = 1.0 - f;
            return .{
                .r = @intFromFloat(@as(f32, @floatFromInt(self.r)) * inv + @as(f32, @floatFromInt(other.r)) * f),
                .g = @intFromFloat(@as(f32, @floatFromInt(self.g)) * inv + @as(f32, @floatFromInt(other.g)) * f),
                .b = @intFromFloat(@as(f32, @floatFromInt(self.b)) * inv + @as(f32, @floatFromInt(other.b)) * f),
            };
        }

        /// Lighten the color by a percentage (0.0 - 1.0)
        pub fn lighten(self: RGB, amount: f32) RGB {
            return self.blend(.{ .r = 255, .g = 255, .b = 255 }, amount);
        }

        /// Darken the color by a percentage (0.0 - 1.0)
        pub fn darken(self: RGB, amount: f32) RGB {
            return self.blend(.{ .r = 0, .g = 0, .b = 0 }, amount);
        }

        /// Get the grayscale equivalent
        pub fn grayscale(self: RGB) RGB {
            const gray_val: u8 = @intFromFloat(0.299 * @as(f32, @floatFromInt(self.r)) +
                0.587 * @as(f32, @floatFromInt(self.g)) +
                0.114 * @as(f32, @floatFromInt(self.b)));
            return .{ .r = gray_val, .g = gray_val, .b = gray_val };
        }

        /// Calculate luminance (0.0 - 1.0)
        pub fn luminance(self: RGB) f32 {
            const r = @as(f32, @floatFromInt(self.r)) / 255.0;
            const g = @as(f32, @floatFromInt(self.g)) / 255.0;
            const b = @as(f32, @floatFromInt(self.b)) / 255.0;
            return 0.2126 * r + 0.7152 * g + 0.0722 * b;
        }

        /// Check if this is a light color
        pub fn isLight(self: RGB) bool {
            return self.luminance() > 0.5;
        }

        /// Get a contrasting color (black or white)
        pub fn contrastingColor(self: RGB) RGB {
            return if (self.isLight()) .{ .r = 0, .g = 0, .b = 0 } else .{ .r = 255, .g = 255, .b = 255 };
        }
    };

    /// Create a color from RGB values
    pub fn fromRGB(r: u8, g: u8, b: u8) Color {
        return .{ .rgb = .{ .r = r, .g = g, .b = b } };
    }

    /// Create a color from a hex value
    pub fn hex(value: u24) Color {
        return .{ .rgb = RGB.fromHex(value) };
    }

    /// Create a palette color
    pub fn palette256(index: u8) Color {
        return .{ .palette = index };
    }

    /// Check if this is the default color
    pub fn isDefault(self: Color) bool {
        return self == .default;
    }

    /// Convert to ANSI escape sequence for foreground
    pub fn toFgAnsi(self: Color, writer: anytype) !void {
        switch (self) {
            .default => try writer.writeAll("\x1b[39m"),
            .basic => |b| {
                const code: u8 = if (@intFromEnum(b) >= 8)
                    90 + @intFromEnum(b) - 8
                else
                    30 + @intFromEnum(b);
                try writer.print("\x1b[{d}m", .{code});
            },
            .palette => |p| try writer.print("\x1b[38;5;{d}m", .{p}),
            .rgb => |c| try writer.print("\x1b[38;2;{d};{d};{d}m", .{ c.r, c.g, c.b }),
        }
    }

    /// Convert to ANSI escape sequence for background
    pub fn toBgAnsi(self: Color, writer: anytype) !void {
        switch (self) {
            .default => try writer.writeAll("\x1b[49m"),
            .basic => |b| {
                const code: u8 = if (@intFromEnum(b) >= 8)
                    100 + @intFromEnum(b) - 8
                else
                    40 + @intFromEnum(b);
                try writer.print("\x1b[{d}m", .{code});
            },
            .palette => |p| try writer.print("\x1b[48;5;{d}m", .{p}),
            .rgb => |c| try writer.print("\x1b[48;2;{d};{d};{d}m", .{ c.r, c.g, c.b }),
        }
    }

    /// Blend this color with another
    pub fn blend(self: Color, other: Color, factor: f32) Color {
        const self_rgb = self.toRGB() orelse return other;
        const other_rgb = other.toRGB() orelse return self;
        return .{ .rgb = self_rgb.blend(other_rgb, factor) };
    }

    /// Convert to RGB if possible
    pub fn toRGB(self: Color) ?RGB {
        return switch (self) {
            .default => null,
            .basic => |b| basicToRGB(b),
            .palette => |p| paletteToRGB(p),
            .rgb => |c| c,
        };
    }

    fn basicToRGB(basic: Basic) RGB {
        return switch (basic) {
            .black => .{ .r = 0, .g = 0, .b = 0 },
            .red => .{ .r = 128, .g = 0, .b = 0 },
            .green => .{ .r = 0, .g = 128, .b = 0 },
            .yellow => .{ .r = 128, .g = 128, .b = 0 },
            .blue => .{ .r = 0, .g = 0, .b = 128 },
            .magenta => .{ .r = 128, .g = 0, .b = 128 },
            .cyan => .{ .r = 0, .g = 128, .b = 128 },
            .white => .{ .r = 192, .g = 192, .b = 192 },
            .bright_black => .{ .r = 128, .g = 128, .b = 128 },
            .bright_red => .{ .r = 255, .g = 0, .b = 0 },
            .bright_green => .{ .r = 0, .g = 255, .b = 0 },
            .bright_yellow => .{ .r = 255, .g = 255, .b = 0 },
            .bright_blue => .{ .r = 0, .g = 0, .b = 255 },
            .bright_magenta => .{ .r = 255, .g = 0, .b = 255 },
            .bright_cyan => .{ .r = 0, .g = 255, .b = 255 },
            .bright_white => .{ .r = 255, .g = 255, .b = 255 },
        };
    }

    fn paletteToRGB(index: u8) RGB {
        // Standard colors (0-15)
        if (index < 16) {
            return basicToRGB(@enumFromInt(index));
        }

        // 216-color cube (16-231)
        if (index < 232) {
            const idx = index - 16;
            const r_idx = idx / 36;
            const g_idx = (idx / 6) % 6;
            const b_idx = idx % 6;
            return .{
                .r = if (r_idx == 0) 0 else @as(u8, @intCast(55 + r_idx * 40)),
                .g = if (g_idx == 0) 0 else @as(u8, @intCast(55 + g_idx * 40)),
                .b = if (b_idx == 0) 0 else @as(u8, @intCast(55 + b_idx * 40)),
            };
        }

        // Grayscale (232-255)
        const gray_val: u8 = @intCast((index - 232) * 10 + 8);
        return .{ .r = gray_val, .g = gray_val, .b = gray_val };
    }
};

// ============================================
// Named Color Constants
// ============================================

pub const Colors = struct {
    // Basic colors
    pub const black = Color{ .basic = .black };
    pub const red = Color{ .basic = .red };
    pub const green = Color{ .basic = .green };
    pub const yellow = Color{ .basic = .yellow };
    pub const blue = Color{ .basic = .blue };
    pub const magenta = Color{ .basic = .magenta };
    pub const cyan = Color{ .basic = .cyan };
    pub const white = Color{ .basic = .white };

    // Bright colors
    pub const bright_black = Color{ .basic = .bright_black };
    pub const bright_red = Color{ .basic = .bright_red };
    pub const bright_green = Color{ .basic = .bright_green };
    pub const bright_yellow = Color{ .basic = .bright_yellow };
    pub const bright_blue = Color{ .basic = .bright_blue };
    pub const bright_magenta = Color{ .basic = .bright_magenta };
    pub const bright_cyan = Color{ .basic = .bright_cyan };
    pub const bright_white = Color{ .basic = .bright_white };

    // Aliases
    pub const gray = bright_black;
    pub const grey = bright_black;
    pub const default = Color.default;

    // CSS-like named colors (true color)
    pub const alice_blue = Color.hex(0xF0F8FF);
    pub const antique_white = Color.hex(0xFAEBD7);
    pub const aqua = Color.hex(0x00FFFF);
    pub const aquamarine = Color.hex(0x7FFFD4);
    pub const azure = Color.hex(0xF0FFFF);
    pub const beige = Color.hex(0xF5F5DC);
    pub const coral = Color.hex(0xFF7F50);
    pub const crimson = Color.hex(0xDC143C);
    pub const dark_blue = Color.hex(0x00008B);
    pub const dark_cyan = Color.hex(0x008B8B);
    pub const dark_gray = Color.hex(0xA9A9A9);
    pub const dark_green = Color.hex(0x006400);
    pub const dark_magenta = Color.hex(0x8B008B);
    pub const dark_orange = Color.hex(0xFF8C00);
    pub const dark_red = Color.hex(0x8B0000);
    pub const deep_pink = Color.hex(0xFF1493);
    pub const deep_sky_blue = Color.hex(0x00BFFF);
    pub const dodger_blue = Color.hex(0x1E90FF);
    pub const fire_brick = Color.hex(0xB22222);
    pub const forest_green = Color.hex(0x228B22);
    pub const gold = Color.hex(0xFFD700);
    pub const golden_rod = Color.hex(0xDAA520);
    pub const hot_pink = Color.hex(0xFF69B4);
    pub const indian_red = Color.hex(0xCD5C5C);
    pub const indigo = Color.hex(0x4B0082);
    pub const ivory = Color.hex(0xFFFFF0);
    pub const lavender = Color.hex(0xE6E6FA);
    pub const lemon_chiffon = Color.hex(0xFFFACD);
    pub const light_blue = Color.hex(0xADD8E6);
    pub const light_coral = Color.hex(0xF08080);
    pub const light_cyan = Color.hex(0xE0FFFF);
    pub const light_gray = Color.hex(0xD3D3D3);
    pub const light_green = Color.hex(0x90EE90);
    pub const light_pink = Color.hex(0xFFB6C1);
    pub const lime = Color.hex(0x00FF00);
    pub const lime_green = Color.hex(0x32CD32);
    pub const maroon = Color.hex(0x800000);
    pub const medium_blue = Color.hex(0x0000CD);
    pub const medium_purple = Color.hex(0x9370DB);
    pub const midnight_blue = Color.hex(0x191970);
    pub const mint_cream = Color.hex(0xF5FFFA);
    pub const navy = Color.hex(0x000080);
    pub const olive = Color.hex(0x808000);
    pub const orange = Color.hex(0xFFA500);
    pub const orange_red = Color.hex(0xFF4500);
    pub const orchid = Color.hex(0xDA70D6);
    pub const pale_green = Color.hex(0x98FB98);
    pub const pale_violet_red = Color.hex(0xDB7093);
    pub const peru = Color.hex(0xCD853F);
    pub const pink = Color.hex(0xFFC0CB);
    pub const plum = Color.hex(0xDDA0DD);
    pub const purple = Color.hex(0x800080);
    pub const rebecca_purple = Color.hex(0x663399);
    pub const rosy_brown = Color.hex(0xBC8F8F);
    pub const royal_blue = Color.hex(0x4169E1);
    pub const salmon = Color.hex(0xFA8072);
    pub const sea_green = Color.hex(0x2E8B57);
    pub const sienna = Color.hex(0xA0522D);
    pub const silver = Color.hex(0xC0C0C0);
    pub const sky_blue = Color.hex(0x87CEEB);
    pub const slate_blue = Color.hex(0x6A5ACD);
    pub const slate_gray = Color.hex(0x708090);
    pub const snow = Color.hex(0xFFFAFA);
    pub const spring_green = Color.hex(0x00FF7F);
    pub const steel_blue = Color.hex(0x4682B4);
    pub const tan = Color.hex(0xD2B48C);
    pub const teal = Color.hex(0x008080);
    pub const thistle = Color.hex(0xD8BFD8);
    pub const tomato = Color.hex(0xFF6347);
    pub const turquoise = Color.hex(0x40E0D0);
    pub const violet = Color.hex(0xEE82EE);
    pub const wheat = Color.hex(0xF5DEB3);
    pub const white_smoke = Color.hex(0xF5F5F5);
    pub const yellow_green = Color.hex(0x9ACD32);
};

test "hex color parsing" {
    const color = Color.hex(0xFF5733);
    const c = color.rgb;
    try std.testing.expectEqual(@as(u8, 0xFF), c.r);
    try std.testing.expectEqual(@as(u8, 0x57), c.g);
    try std.testing.expectEqual(@as(u8, 0x33), c.b);
}

test "color blending" {
    const white = Color.RGB{ .r = 255, .g = 255, .b = 255 };
    const black = Color.RGB{ .r = 0, .g = 0, .b = 0 };
    const gray = white.blend(black, 0.5);
    try std.testing.expect(gray.r > 120 and gray.r < 140);
    try std.testing.expect(gray.g > 120 and gray.g < 140);
    try std.testing.expect(gray.b > 120 and gray.b < 140);
}

test "luminance calculation" {
    const white = Color.RGB{ .r = 255, .g = 255, .b = 255 };
    const black = Color.RGB{ .r = 0, .g = 0, .b = 0 };
    try std.testing.expect(white.luminance() > 0.9);
    try std.testing.expect(black.luminance() < 0.1);
    try std.testing.expect(white.isLight());
    try std.testing.expect(!black.isLight());
}
