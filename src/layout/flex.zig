//! Flex layout containers (FlexRow, FlexColumn)

const std = @import("std");
const layout = @import("layout.zig");
const screen_mod = @import("../core/screen.zig");
const style_mod = @import("../style/style.zig");

pub const Rect = layout.Rect;
pub const Direction = layout.Direction;
pub const MainAxisAlignment = layout.MainAxisAlignment;
pub const CrossAxisAlignment = layout.CrossAxisAlignment;
pub const Size = layout.Size;
pub const FlexItem = layout.FlexItem;
pub const Screen = screen_mod.Screen;
pub const Style = style_mod.Style;

/// Flex container configuration
pub const FlexConfig = struct {
    /// Layout direction
    direction: Direction = .vertical,

    /// Main axis alignment
    main_align: MainAxisAlignment = .start,

    /// Cross axis alignment
    cross_align: CrossAxisAlignment = .stretch,

    /// Gap between items
    gap: u16 = 0,

    /// Padding around content
    padding: layout.Edges = .{},

    /// Whether to wrap items
    wrap: bool = false,

    /// Background style
    background: ?Style = null,
};

/// Flex column container
pub fn FlexColumn(children: anytype) FlexContainer(@TypeOf(children)) {
    return FlexContainer(@TypeOf(children)).init(children, .{
        .direction = .vertical,
    });
}

/// Flex row container
pub fn FlexRow(children: anytype) FlexContainer(@TypeOf(children)) {
    return FlexContainer(@TypeOf(children)).init(children, .{
        .direction = .horizontal,
    });
}

/// Generic flex container
pub fn FlexContainer(comptime ChildrenType: type) type {
    return struct {
        children: ChildrenType,
        config: FlexConfig,
        bounds: Rect = .{},

        const Self = @This();

        pub fn init(children: ChildrenType, config: FlexConfig) Self {
            return .{
                .children = children,
                .config = config,
            };
        }

        /// Configure the container
        pub fn configure(self: Self, config: FlexConfig) Self {
            var result = self;
            result.config = config;
            return result;
        }

        /// Set gap between items
        pub fn gap(self: Self, g: u16) Self {
            var result = self;
            result.config.gap = g;
            return result;
        }

        /// Set main axis alignment
        pub fn mainAlign(self: Self, alignment_val: MainAxisAlignment) Self {
            var result = self;
            result.config.main_align = alignment_val;
            return result;
        }

        /// Set cross axis alignment
        pub fn crossAlign(self: Self, alignment_val: CrossAxisAlignment) Self {
            var result = self;
            result.config.cross_align = alignment_val;
            return result;
        }

        /// Set padding
        pub fn padding(self: Self, edges: layout.Edges) Self {
            var result = self;
            result.config.padding = edges;
            return result;
        }

        /// Layout children within a rect
        pub fn layout_children(self: *Self, rect: Rect) void {
            self.bounds = rect;

            // Apply padding
            const content_rect = rect.inset(
                self.config.padding.top,
                self.config.padding.right,
                self.config.padding.bottom,
                self.config.padding.left,
            );

            const child_info = @typeInfo(ChildrenType);

            switch (child_info) {
                .@"struct" => |s| {
                    if (s.is_tuple) {
                        self.layoutTupleChildren(content_rect, s.fields.len);
                    }
                },
                else => {},
            }
        }

        fn layoutTupleChildren(self: *Self, rect: Rect, comptime count: usize) void {
            if (count == 0) return;

            const is_vertical = self.config.direction == .vertical;
            const main_size = if (is_vertical) rect.height else rect.width;
            const cross_size = if (is_vertical) rect.width else rect.height;

            // Calculate total gap space
            const total_gap = self.config.gap * (count - 1);
            const available = main_size -| @as(u16, @intCast(total_gap));

            // Distribute space evenly for now (can be enhanced with flex grow/shrink)
            const per_child = available / @as(u16, @intCast(count));

            var offset: u16 = 0;

            inline for (0..count) |i| {
                _ = i;

                const child_main = per_child;
                const child_cross = cross_size;

                const child_rect = if (is_vertical)
                    Rect.init(rect.x, rect.y + offset, child_cross, child_main)
                else
                    Rect.init(rect.x + offset, rect.y, child_main, child_cross);

                _ = child_rect;

                offset += child_main + self.config.gap;
            }
        }

        /// Render the container to a screen
        pub fn render(self: *Self, scr: *Screen) void {
            // Render background if set
            if (self.config.background) |bg| {
                scr.setStyle(bg);
                scr.fill(
                    self.bounds.x,
                    self.bounds.y,
                    self.bounds.width,
                    self.bounds.height,
                    ' ',
                );
            }

            // Render children would go here
            _ = self.children;
        }

        /// Get preferred size
        pub fn preferredSize(self: Self) struct { width: u16, height: u16 } {
            _ = self;
            // Would calculate based on children
            return .{ .width = 0, .height = 0 };
        }
    };
}

/// Stack container - children overlap
pub fn Stack(comptime ChildrenType: type) type {
    return struct {
        children: ChildrenType,
        align_config: struct {
            horizontal: layout.Alignment = .left,
            vertical: layout.VerticalAlignment = .top,
        } = .{},
        bounds: Rect = .{},

        const Self = @This();

        pub fn init(children: ChildrenType) Self {
            return .{ .children = children };
        }

        pub fn setAlignment(self: Self, h: layout.Alignment, v: layout.VerticalAlignment) Self {
            var result = self;
            result.align_config = .{ .horizontal = h, .vertical = v };
            return result;
        }
    };
}

test "flex column creation" {
    const col = FlexColumn(.{ 1, 2, 3 });
    try std.testing.expectEqual(Direction.vertical, col.config.direction);
}

test "flex row creation" {
    const row = FlexRow(.{ 1, 2, 3 });
    try std.testing.expectEqual(Direction.horizontal, row.config.direction);
}

test "flex configuration" {
    const col = FlexColumn(.{}).gap(5).mainAlign(.center);
    try std.testing.expectEqual(@as(u16, 5), col.config.gap);
    try std.testing.expectEqual(MainAxisAlignment.center, col.config.main_align);
}
