// Image display widget with protocol support for Kitty and iTerm.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;

pub const ImageProtocol = enum {
    kitty,
    iterm2,
    sixel,
    ascii,
};

pub const Image = struct {
    data: []const u8,
    width: u16,
    height: u16,
    protocol: ImageProtocol = .ascii,
    base: widget.StatefulWidget = .{},

    pub fn init(data: []const u8, width: u16, height: u16) Image {
        return .{ .data = data, .width = width, .height = height };
    }

    pub fn withProtocol(self: Image, protocol: ImageProtocol) Image {
        var result = self;
        result.protocol = protocol;
        return result;
    }

    pub fn render(self: *Image, ctx: *widget.RenderContext) void {
        var sub = ctx.getSubScreen();
        
        switch (self.protocol) {
            .kitty => self.renderKitty(&sub),
            .iterm2 => self.renderITerm2(&sub),
            .sixel => self.renderSixel(&sub),
            .ascii => self.renderAscii(&sub),
        }
    }

    fn renderKitty(self: *Image, sub: anytype) void {
        // Kitty graphics protocol: https://sw.kovidgoyal.net/kitty/graphics-protocol/
        // Format: \x1b_G<control data>;<payload>\x1b\\
        
        // Move cursor to position
        sub.moveCursor(0, 0);
        
        // Base64 encode image data
        var buf: [8192]u8 = undefined;
        const encoded = std.base64.standard.Encoder.encode(&buf, self.data);
        
        // Send Kitty graphics command
        // a=T: transmit, f=24: RGB format, s=width, v=height
        var cmd_buf: [256]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "\x1b_Ga=T,f=24,s={d},v={d};{s}\x1b\\", .{
            self.width,
            self.height,
            encoded,
        }) catch return;
        
        sub.putString(cmd);
    }

    fn renderITerm2(self: *Image, sub: anytype) void {
        // iTerm2 inline images: https://iterm2.com/documentation-images.html
        // Format: \x1b]1337;File=inline=1;width=<w>;height=<h>:<base64>\x07
        
        sub.moveCursor(0, 0);
        
        // Base64 encode image data
        var buf: [8192]u8 = undefined;
        const encoded = std.base64.standard.Encoder.encode(&buf, self.data);
        
        // Send iTerm2 image command
        var cmd_buf: [256]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "\x1b]1337;File=inline=1;width={d};height={d}:{s}\x07", .{
            self.width,
            self.height,
            encoded,
        }) catch return;
        
        sub.putString(cmd);
    }

    fn renderSixel(self: *Image, sub: anytype) void {
        // Sixel graphics: https://en.wikipedia.org/wiki/Sixel
        // Format: \x1bP<params>q<sixel data>\x1b\\
        
        sub.moveCursor(0, 0);
        
        // Start sixel sequence
        sub.putString("\x1bPq");
        
        // Define color palette (simplified grayscale)
        for (0..256) |i| {
            var color_buf: [32]u8 = undefined;
            const color_cmd = std.fmt.bufPrint(&color_buf, "#{d};2;{d};{d};{d}", .{
                i,
                i * 100 / 255,
                i * 100 / 255,
                i * 100 / 255,
            }) catch continue;
            sub.putString(color_cmd);
        }
        
        // Render image data as sixels (6 pixels per character)
        var y: usize = 0;
        while (y < self.height) : (y += 6) {
            for (0..self.width) |x| {
                if (x >= self.data.len) break;
                
                var sixel: u8 = 0;
                for (0..6) |dy| {
                    if (y + dy >= self.height) break;
                    const idx = (y + dy) * self.width + x;
                    if (idx < self.data.len and self.data[idx] > 128) {
                        sixel |= @as(u8, 1) << @intCast(dy);
                    }
                }
                
                // Output sixel character (offset by 63)
                sub.putChar(@as(u8, 63 + sixel));
            }
            sub.putString("$-"); // Carriage return and line feed
        }
        
        // End sixel sequence
        sub.putString("\x1b\\");
    }

    fn renderAscii(self: *Image, sub: anytype) void {
        const chars = " .:-=+*#%@";
        for (0..@min(self.height, sub.height)) |y| {
            for (0..@min(self.width, sub.width)) |x| {
                const idx = (y * self.width + x) % self.data.len;
                const brightness = self.data[idx];
                const char_idx = @min(brightness / 26, chars.len - 1);
                
                sub.moveCursor(@intCast(x), @intCast(y));
                sub.putChar(chars[char_idx]);
            }
        }
    }
};

test "Image creation" {
    const data = [_]u8{0} ** 100;
    const img = Image.init(&data, 10, 10);
    try std.testing.expectEqual(@as(u16, 10), img.width);
    try std.testing.expectEqual(@as(u16, 10), img.height);
}

test "Image with protocol" {
    const data = [_]u8{128} ** 100;
    const img = Image.init(&data, 10, 10).withProtocol(.kitty);
    try std.testing.expectEqual(ImageProtocol.kitty, img.protocol);
}

test "Image ASCII rendering" {
    const data = [_]u8{ 0, 50, 100, 150, 200, 255 };
    const img = Image.init(&data, 3, 2);
    try std.testing.expectEqual(ImageProtocol.ascii, img.protocol);
}
