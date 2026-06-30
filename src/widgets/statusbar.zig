// Status bar widget for bottom application status display.

const std = @import("std");
const widget = @import("widget.zig");
const Style = @import("../style/style.zig").Style;
const Color = @import("../style/color.zig").Color;
const unicode = @import("../unicode/unicode.zig");

pub const StatusItem = struct {
    text: []const u8,
    alignment: enum { left, center, right } = .left,
};

pub const Statusbar = struct {
    items: []const StatusItem,
    base: widget.StatefulWidget = .{},
    style: Style = Style.default,

    pub fn init(items: []const StatusItem) Statusbar {
        return .{ .items = items };
    }

    pub fn render(self: *Statusbar, ctx: *widget.RenderContext) void {
        var sub = ctx.getSubScreen();

        sub.setStyle(self.style.setBg(Color.fromRGB(40, 42, 54)).setFg(Color.white));
        for (0..sub.width) |x| {
            sub.moveCursor(@intCast(x), 0);
            sub.putChar(' ');
        }

        for (self.items) |item| {
            const text_len: u16 = @intCast(item.text.len);
            const x = switch (item.alignment) {
                .left => 2,
                .center => (sub.width -| text_len) / 2,
                .right => sub.width -| text_len - 2,
            };

            sub.moveCursor(x, 0);
            sub.putString(item.text);
        }
    }

    pub fn sizeHint(self: *Statusbar) widget.SizeHint {
        var max_width: u16 = 0;
        for (self.items) |item| {
            const w: u16 = @intCast(unicode.stringWidth(item.text) + 4);
            if (w > max_width) max_width = w;
        }
        return .{
            .min_width = max_width,
            .preferred_width = 0,
            .min_height = 1,
            .preferred_height = 1,
            .expand_x = true,
        };
    }

    pub fn isFocusable(self: *Statusbar) bool {
        _ = self;
        return false;
    }

    test "statusbar size hint" {
        const items = [_]StatusItem{.{ .text = "Ready" }};
        var sb = Statusbar.init(&items);
        const hint = sb.sizeHint();
        try std.testing.expectEqual(@as(u16, 1), hint.min_height);
    }
};

test "Statusbar creation" {
    const items = [_]StatusItem{.{ .text = "Ready" }};
    const statusbar = Statusbar.init(&items);
    try std.testing.expectEqual(@as(usize, 1), statusbar.items.len);
}
