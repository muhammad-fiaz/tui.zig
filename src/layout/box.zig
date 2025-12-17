//! Box model for layout calculations

const std = @import("std");
const layout = @import("layout.zig");

pub const Rect = layout.Rect;
pub const Edges = layout.Edges;
pub const Constraint = layout.Constraint;
pub const Size = layout.Size;

/// Box model with content, padding, border, and margin
pub const Box = struct {
    /// Content area
    content: Rect = .{},

    /// Padding inside border
    padding: Edges = .{},

    /// Border thickness
    border: Edges = .{},

    /// Margin outside border
    margin: Edges = .{},

    /// Get the total outer rect including margin
    pub fn outerRect(self: Box) Rect {
        return .{
            .x = self.content.x -| self.padding.left -| self.border.left -| self.margin.left,
            .y = self.content.y -| self.padding.top -| self.border.top -| self.margin.top,
            .width = self.outerWidth(),
            .height = self.outerHeight(),
        };
    }

    /// Get the border box (content + padding + border)
    pub fn borderRect(self: Box) Rect {
        return .{
            .x = self.content.x -| self.padding.left -| self.border.left,
            .y = self.content.y -| self.padding.top -| self.border.top,
            .width = self.borderWidth(),
            .height = self.borderHeight(),
        };
    }

    /// Get the padding box (content + padding)
    pub fn paddingRect(self: Box) Rect {
        return .{
            .x = self.content.x -| self.padding.left,
            .y = self.content.y -| self.padding.top,
            .width = self.paddingWidth(),
            .height = self.paddingHeight(),
        };
    }

    /// Get total outer width
    pub fn outerWidth(self: Box) u16 {
        return self.content.width +|
            self.padding.horizontal() +|
            self.border.horizontal() +|
            self.margin.horizontal();
    }

    /// Get total outer height
    pub fn outerHeight(self: Box) u16 {
        return self.content.height +|
            self.padding.vertical() +|
            self.border.vertical() +|
            self.margin.vertical();
    }

    /// Get border box width
    pub fn borderWidth(self: Box) u16 {
        return self.content.width +|
            self.padding.horizontal() +|
            self.border.horizontal();
    }

    /// Get border box height
    pub fn borderHeight(self: Box) u16 {
        return self.content.height +|
            self.padding.vertical() +|
            self.border.vertical();
    }

    /// Get padding box width
    pub fn paddingWidth(self: Box) u16 {
        return self.content.width +| self.padding.horizontal();
    }

    /// Get padding box height
    pub fn paddingHeight(self: Box) u16 {
        return self.content.height +| self.padding.vertical();
    }

    /// Create a box from an outer rect and insets
    pub fn fromOuter(outer: Rect, margin_val: Edges, border_val: Edges, padding_val: Edges) Box {
        const content_x = outer.x +| margin_val.left +| border_val.left +| padding_val.left;
        const content_y = outer.y +| margin_val.top +| border_val.top +| padding_val.top;
        const content_w = outer.width -| margin_val.horizontal() -| border_val.horizontal() -| padding_val.horizontal();
        const content_h = outer.height -| margin_val.vertical() -| border_val.vertical() -| padding_val.vertical();

        return .{
            .content = .{
                .x = content_x,
                .y = content_y,
                .width = content_w,
                .height = content_h,
            },
            .padding = padding_val,
            .border = border_val,
            .margin = margin_val,
        };
    }
};

/// Flexible sizing specification
pub const FlexSize = struct {
    width: SizeSpec = .auto,
    height: SizeSpec = .auto,
    min_width: ?u16 = null,
    max_width: ?u16 = null,
    min_height: ?u16 = null,
    max_height: ?u16 = null,

    pub const SizeSpec = union(enum) {
        auto,
        fixed: u16,
        percent: u8,
        fill,
    };

    /// Resolve width given available space and intrinsic size
    pub fn resolveWidth(self: FlexSize, available: u16, intrinsic: u16) u16 {
        var result = switch (self.width) {
            .auto => intrinsic,
            .fixed => |f| f,
            .percent => |p| @as(u16, @intCast((@as(u32, available) * @as(u32, p)) / 100)),
            .fill => available,
        };

        if (self.min_width) |min| {
            result = @max(result, min);
        }
        if (self.max_width) |max| {
            result = @min(result, max);
        }

        return result;
    }

    /// Resolve height given available space and intrinsic size
    pub fn resolveHeight(self: FlexSize, available: u16, intrinsic: u16) u16 {
        var result = switch (self.height) {
            .auto => intrinsic,
            .fixed => |f| f,
            .percent => |p| @as(u16, @intCast((@as(u32, available) * @as(u32, p)) / 100)),
            .fill => available,
        };

        if (self.min_height) |min| {
            result = @max(result, min);
        }
        if (self.max_height) |max| {
            result = @min(result, max);
        }

        return result;
    }
};

test "box model" {
    var box = Box{
        .content = .{ .x = 20, .y = 20, .width = 100, .height = 50 },
        .padding = Edges.all(5),
        .border = Edges.all(1),
        .margin = Edges.all(10),
    };

    try std.testing.expectEqual(@as(u16, 132), box.outerWidth());
    try std.testing.expectEqual(@as(u16, 82), box.outerHeight());

    const outer = box.outerRect();
    try std.testing.expectEqual(@as(u16, 4), outer.x);
    try std.testing.expectEqual(@as(u16, 4), outer.y);
}

test "box from outer" {
    const outer = Rect.init(0, 0, 100, 100);
    const box = Box.fromOuter(outer, Edges.all(5), Edges.all(1), Edges.all(10));

    try std.testing.expectEqual(@as(u16, 68), box.content.width);
    try std.testing.expectEqual(@as(u16, 68), box.content.height);
}
