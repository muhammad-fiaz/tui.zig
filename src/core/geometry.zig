//! Rectangular terminal geometry: positions, sizes, margins, padding, alignment, and rects.

const std = @import("std");
const testing = std.testing;

/// Horizontal alignment inside a rectangular area.
pub const Alignment = enum {
    left,
    center,
    right,
};

/// Vertical alignment inside a rectangular area.
pub const VerticalAlignment = enum {
    top,
    center,
    bottom,
};

/// A 2D cell coordinate (`(0, 0)` is the top-left corner).
pub const Position = struct {
    x: u16 = 0,
    y: u16 = 0,

    pub const origin: Position = .{ .x = 0, .y = 0 };

    pub fn init(x: u16, y: u16) Position {
        return .{ .x = x, .y = y };
    }

    /// Translates this position by a signed `Offset`, clamping to `0..u16 max`.
    pub fn moveBy(self: Position, delta: Offset) Position {
        const nx = std.math.clamp(@as(i32, self.x) + delta.x, 0, std.math.maxInt(u16));
        const ny = std.math.clamp(@as(i32, self.y) + delta.y, 0, std.math.maxInt(u16));
        return .{ .x = @intCast(nx), .y = @intCast(ny) };
    }

    pub fn eql(a: Position, b: Position) bool {
        return a.x == b.x and a.y == b.y;
    }
};

/// Terminal dimensions in columns (`width`) and rows (`height`).
pub const Size = struct {
    width: u16 = 0,
    height: u16 = 0,

    pub const zero: Size = .{ .width = 0, .height = 0 };

    pub fn init(width: u16, height: u16) Size {
        return .{ .width = width, .height = height };
    }

    /// Total cell count (`width * height`).
    pub fn area(self: Size) u32 {
        return @as(u32, self.width) * @as(u32, self.height);
    }

    pub fn isEmpty(self: Size) bool {
        return self.width == 0 or self.height == 0;
    }

    pub fn eql(a: Size, b: Size) bool {
        return a.width == b.width and a.height == b.height;
    }
};

/// Signed 2D coordinate delta.
pub const Offset = struct {
    x: i32 = 0,
    y: i32 = 0,

    pub const zero: Offset = .{ .x = 0, .y = 0 };

    pub fn init(x: i32, y: i32) Offset {
        return .{ .x = x, .y = y };
    }
};

/// Symmetric horizontal and vertical spacing around a `Rect`.
pub const Margin = struct {
    horizontal: u16 = 0,
    vertical: u16 = 0,

    pub const zero: Margin = .{};

    pub fn uniform(value: u16) Margin {
        return .{ .horizontal = value, .vertical = value };
    }

    pub fn symmetric(horizontal_val: u16, vertical_val: u16) Margin {
        return .{ .horizontal = horizontal_val, .vertical = vertical_val };
    }
};

/// Asymmetric interior spacing on all four sides of a container or widget.
pub const Padding = struct {
    left: u16 = 0,
    right: u16 = 0,
    top: u16 = 0,
    bottom: u16 = 0,

    pub const zero: Padding = .{};

    pub fn uniform(value: u16) Padding {
        return .{ .left = value, .right = value, .top = value, .bottom = value };
    }

    pub fn symmetric(horizontal_val: u16, vertical_val: u16) Padding {
        return .{
            .left = horizontal_val,
            .right = horizontal_val,
            .top = vertical_val,
            .bottom = vertical_val,
        };
    }

    pub fn horizontal(value: u16) Padding {
        return .{ .left = value, .right = value };
    }

    pub fn vertical(value: u16) Padding {
        return .{ .top = value, .bottom = value };
    }
};

/// Rectangular cell region in terminal coordinates.
pub const Rect = struct {
    x: u16 = 0,
    y: u16 = 0,
    width: u16 = 0,
    height: u16 = 0,

    pub const zero: Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 };

    /// Creates a `Rect` clamping `width` and `height` so `right()` and `bottom()` never overflow `u16`.
    pub fn init(x: u16, y: u16, width: u16, height: u16) Rect {
        return .{
            .x = x,
            .y = y,
            .width = (x +| width) - x,
            .height = (y +| height) - y,
        };
    }

    /// Creates a `Rect` from a top-left `Position` and `Size`.
    pub fn fromPosSize(pos: Position, sz: Size) Rect {
        return init(pos.x, pos.y, sz.width, sz.height);
    }

    pub fn area(self: Rect) u32 {
        return @as(u32, self.width) * @as(u32, self.height);
    }

    pub fn isEmpty(self: Rect) bool {
        return self.width == 0 or self.height == 0;
    }

    pub fn left(self: Rect) u16 {
        return self.x;
    }

    pub fn right(self: Rect) u16 {
        return self.x +| self.width;
    }

    pub fn top(self: Rect) u16 {
        return self.y;
    }

    pub fn bottom(self: Rect) u16 {
        return self.y +| self.height;
    }

    pub fn position(self: Rect) Position {
        return .{ .x = self.x, .y = self.y };
    }

    pub fn size(self: Rect) Size {
        return .{ .width = self.width, .height = self.height };
    }

    /// Shrinks `self` by symmetric `margin`. Returns `Rect.zero` if margins exceed dimensions.
    pub fn inner(self: Rect, margin: Margin) Rect {
        const dh = margin.horizontal *| 2;
        const dv = margin.vertical *| 2;
        if (self.width < dh or self.height < dv) return Rect.zero;
        return .{
            .x = self.x +| margin.horizontal,
            .y = self.y +| margin.vertical,
            .width = self.width - dh,
            .height = self.height - dv,
        };
    }

    /// Expands `self` outward by `margin`, clamping to valid `u16` coordinates.
    pub fn outer(self: Rect, margin: Margin) Rect {
        const nx = self.x -| margin.horizontal;
        const ny = self.y -| margin.vertical;
        const nr = self.right() +| margin.horizontal;
        const nb = self.bottom() +| margin.vertical;
        return .{
            .x = nx,
            .y = ny,
            .width = nr - nx,
            .height = nb - ny,
        };
    }

    /// Shrinks `self` by asymmetric `padding`. Returns `Rect.zero` if padding exceeds dimensions.
    pub fn inset(self: Rect, pad: Padding) Rect {
        const h = pad.left +| pad.right;
        const v = pad.top +| pad.bottom;
        if (self.width < h or self.height < v) return Rect.zero;
        return .{
            .x = self.x +| pad.left,
            .y = self.y +| pad.top,
            .width = self.width - h,
            .height = self.height - v,
        };
    }

    /// Translates `self` by signed `delta`, clamping to `bounds` (`0..u16 max`).
    pub fn offset(self: Rect, delta: Offset) Rect {
        const pos = self.position().moveBy(delta);
        return init(pos.x, pos.y, self.width, self.height);
    }

    /// Changes dimensions while preserving top-left position and `u16` bounds.
    pub fn resize(self: Rect, sz: Size) Rect {
        return init(self.x, self.y, sz.width, sz.height);
    }

    /// Returns the overlapping `Rect` between `self` and `other`, or `Rect.zero` if disjoint.
    pub fn intersection(self: Rect, other: Rect) Rect {
        const x1 = @max(self.left(), other.left());
        const y1 = @max(self.top(), other.top());
        const x2 = @min(self.right(), other.right());
        const y2 = @min(self.bottom(), other.bottom());
        if (x2 <= x1 or y2 <= y1) return Rect.zero;
        return .{
            .x = x1,
            .y = y1,
            .width = x2 - x1,
            .height = y2 - y1,
        };
    }

    /// Returns the minimal bounding box enclosing both `self` and `other`.
    pub fn unionWith(self: Rect, other: Rect) Rect {
        if (self.isEmpty()) return other;
        if (other.isEmpty()) return self;
        const x1 = @min(self.left(), other.left());
        const y1 = @min(self.top(), other.top());
        const x2 = @max(self.right(), other.right());
        const y2 = @max(self.bottom(), other.bottom());
        return .{
            .x = x1,
            .y = y1,
            .width = x2 - x1,
            .height = y2 - y1,
        };
    }

    /// Clamps `self` so it lies completely inside `bounds`.
    pub fn clamp(self: Rect, bounds: Rect) Rect {
        return self.intersection(bounds);
    }

    pub fn contains(self: Rect, pos: Position) bool {
        return pos.x >= self.x and pos.x < self.right() and pos.y >= self.y and pos.y < self.bottom();
    }

    pub fn containsXY(self: Rect, px: u16, py: u16) bool {
        return self.contains(.{ .x = px, .y = py });
    }

    pub fn intersects(self: Rect, other: Rect) bool {
        return !self.intersection(other).isEmpty();
    }

    /// Returns a rectangle of `width` x `height` centered inside `self` (clamped to `self`).
    pub fn centered(self: Rect, target_width: u16, target_height: u16) Rect {
        const w = @min(self.width, target_width);
        const h = @min(self.height, target_height);
        return .{
            .x = self.x + (self.width - w) / 2,
            .y = self.y + (self.height - h) / 2,
            .width = w,
            .height = h,
        };
    }

    /// Horizontally centers a rectangle of `target_width` spanning full height of `self`.
    pub fn centeredHorizontally(self: Rect, target_width: u16) Rect {
        const w = @min(self.width, target_width);
        return .{
            .x = self.x + (self.width - w) / 2,
            .y = self.y,
            .width = w,
            .height = self.height,
        };
    }

    /// Vertically centers a rectangle of `target_height` spanning full width of `self`.
    pub fn centeredVertically(self: Rect, target_height: u16) Rect {
        const h = @min(self.height, target_height);
        return .{
            .x = self.x,
            .y = self.y + (self.height - h) / 2,
            .width = self.width,
            .height = h,
        };
    }

    pub fn eql(a: Rect, b: Rect) bool {
        return a.x == b.x and a.y == b.y and a.width == b.width and a.height == b.height;
    }

    /// Returns a 1-row-tall `Rect` slice at `row_index` relative to `self.y`, or `null` if out of bounds.
    pub fn rowRect(self: Rect, row_index: u16) ?Rect {
        if (row_index >= self.height or self.width == 0) return null;
        return .{ .x = self.x, .y = self.y + row_index, .width = self.width, .height = 1 };
    }
};

test "rect arithmetic, inset, intersection, and centering" {
    const r = Rect.init(10, 5, 40, 20);
    try testing.expectEqual(@as(u16, 50), r.right());
    try testing.expectEqual(@as(u16, 25), r.bottom());
    try testing.expectEqual(@as(u32, 800), r.area());

    const inner = r.inner(Margin.symmetric(2, 1));
    try testing.expectEqual(Rect.init(12, 6, 36, 18), inner);

    const padded = r.inset(.{ .left = 1, .right = 3, .top = 2, .bottom = 4 });
    try testing.expectEqual(Rect.init(11, 7, 36, 14), padded);

    const c = r.centered(10, 4);
    try testing.expectEqual(Rect.init(25, 13, 10, 4), c);

    const a = Rect.init(0, 0, 10, 10);
    const b = Rect.init(5, 5, 10, 10);
    try testing.expectEqual(Rect.init(5, 5, 5, 5), a.intersection(b));
    try testing.expectEqual(Rect.init(0, 0, 15, 15), a.unionWith(b));
    try testing.expect(a.containsXY(9, 9));
    try testing.expect(!a.containsXY(10, 9));
}
