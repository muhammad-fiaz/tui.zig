//! Bordered container (`Block`), titles, drop shadows, and collapsing adjacent borders.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const clear_mod = @import("clear.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Padding = core_root.Padding;
pub const Alignment = core_root.Alignment;
pub const Buffer = core_root.Buffer;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const BorderSides = style_root.BorderSides;
pub const BorderType = style_root.BorderType;
pub const BorderSet = style_root.BorderSet;
pub const MergeStrategy = style_root.MergeStrategy;
pub const symbols = style_root.symbols;
pub const Span = text_root.Span;
pub const Line = text_root.Line;

/// Edge where a `Title` sits along a `Block`.
pub const TitlePosition = enum {
    top,
    bottom,
};

/// Title descriptor placed on a `Block`'s top or bottom border row.
///
/// Accepts either plain text (`text`) or rich multi-span `spans` (borrowed).
pub const Title = struct {
    text: []const u8 = "",
    spans: []const Span = &.{},
    alignment: Alignment = .left,
    position: TitlePosition = .top,
    style: ?Style = null,

    /// Creates a plain-text top-left title.
    pub fn init(content: []const u8) Title {
        return .{ .text = content };
    }

    /// Creates a multi-span top-left title from borrowed `spans`.
    pub fn fromSpans(spans: []const Span) Title {
        return .{ .spans = spans };
    }

    /// Returns a copy placed on `pos` (`.top` or `.bottom`).
    pub fn on(self: Title, pos: TitlePosition) Title {
        var copy = self;
        copy.position = pos;
        return copy;
    }

    /// Returns a copy horizontally aligned to `align_mode`.
    pub fn aligned(self: Title, align_mode: Alignment) Title {
        var copy = self;
        copy.alignment = align_mode;
        return copy;
    }

    /// Returns a copy with explicit `style`.
    pub fn styled(self: Title, s: Style) Title {
        var copy = self;
        copy.style = s;
        return copy;
    }
};

/// Optional drop shadow drawn outside the bottom-right edges of a floating `Block`.
pub const Shadow = struct {
    enabled: bool = false,
    offset_x: u16 = 2,
    offset_y: u16 = 1,
    symbol: []const u8 = symbols.block.light_shade,
    style: ?Style = null,
};

/// Rectangular container widget with configurable borders, titles, padding,
/// background fill, drop shadow, and adjacent border collapsing.
pub const Block = struct {
    /// Convenience top title string (rendered at `title_alignment`).
    title: ?[]const u8 = null,
    /// Alignment for `title`.
    title_alignment: Alignment = .left,
    /// Optional style override for `title`.
    title_style: ?Style = null,
    /// Convenience bottom status/hint title string.
    title_bottom: ?[]const u8 = null,
    /// Alignment for `title_bottom`.
    title_bottom_alignment: Alignment = .right,
    /// Additional borrowed titles placed on top or bottom edges.
    titles: []const Title = &.{},
    /// Border sides mask (`all` by default).
    borders: BorderSides = BorderSides.all,
    /// Built-in border aesthetic preset (`rounded` by default).
    border_type: BorderType = .rounded,
    /// Custom symbol set overriding `border_type` when non-null.
    custom_border_set: ?BorderSet = null,
    /// Border glyph style (`theme.border` or `theme.border_focused` when null).
    border_style: ?Style = null,
    /// Focus state used when `border_style == null` to highlight with `theme.border_focused`.
    focused: bool = false,
    /// Background and base content style inside the block.
    style: ?Style = null,
    /// Fill interior cells with `style` (or `theme.surface` when true).
    fill_background: bool = false,
    /// Inner padding inside the border edges.
    padding: Padding = .{},
    /// Merging behavior when two neighboring blocks share a border edge.
    merge_borders: MergeStrategy = .fuzzy,
    /// Optional drop shadow for floating cards and dialogs.
    shadow: Shadow = .{},

    /// Returns the usable interior `Rect` after subtracting enabled borders and `padding`.
    pub fn inner(self: Block, area: Rect) Rect {
        var r = area;
        if (self.borders.left) {
            r.x +|= 1;
            r.width -|= 1;
        }
        if (self.borders.right) {
            r.width -|= 1;
        }
        if (self.borders.top) {
            r.y +|= 1;
            r.height -|= 1;
        }
        if (self.borders.bottom) {
            r.height -|= 1;
        }
        return r.inset(self.padding);
    }

    /// Returns the resolved `BorderSet` for this block.
    pub fn resolvedBorderSet(self: Block) BorderSet {
        return self.custom_border_set orelse self.border_type.symbolsSet();
    }

    /// Renders this `Block` into `ui.buffer` within `area`.
    pub fn render(self: Block, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        // 1. Optional floating drop shadow outside bounds (never overwrites bounds).
        if (self.shadow.enabled) {
            const sh_style = self.shadow.style orelse ui.theme.muted;
            const sh_x = bounds.left() +| self.shadow.offset_x;
            const sh_y = bounds.top() +| self.shadow.offset_y;
            const shadow_rect = Rect.init(sh_x, sh_y, bounds.width, bounds.height).intersection(ui.buffer.area);
            if (!shadow_rect.isEmpty()) {
                var sy: u16 = shadow_rect.top();
                while (sy < shadow_rect.bottom()) : (sy += 1) {
                    var sx: u16 = shadow_rect.left();
                    while (sx < shadow_rect.right()) : (sx += 1) {
                        if (bounds.containsXY(sx, sy)) continue;
                        if (ui.buffer.getMut(sx, sy)) |cell| {
                            try ui.buffer.setCellSymbol(cell, self.shadow.symbol);
                            cell.diff_option = .none;
                            cell.setStyle(sh_style);
                        }
                    }
                }
            }
        }

        // 2. Interior background fill when styled or requested.
        if (self.fill_background or self.style != null) {
            const bg_style = self.style orelse ui.theme.surface;
            (clear_mod.Clear{ .style = bg_style }).renderToBuffer(ui.buffer, bounds);
        }

        // 3. Borders.
        const bset = self.resolvedBorderSet();
        const bstyle = self.border_style orelse if (self.focused) ui.theme.border_focused else ui.theme.border;

        if (self.borders.left) {
            const top_skip: u16 = @intFromBool(self.borders.top);
            const bot_skip: u16 = @intFromBool(self.borders.bottom);
            var y: u16 = bounds.top() +| top_skip;
            const end_y = bounds.bottom() -| bot_skip;
            while (y < end_y) : (y += 1) {
                try putMerged(ui.buffer, bounds.left(), y, bset.vertical_left, bstyle, self.merge_borders);
            }
        }
        if (self.borders.right and bounds.right() > 0) {
            const rx = bounds.right() - 1;
            const top_skip: u16 = @intFromBool(self.borders.top);
            const bot_skip: u16 = @intFromBool(self.borders.bottom);
            var y: u16 = bounds.top() +| top_skip;
            const end_y = bounds.bottom() -| bot_skip;
            while (y < end_y) : (y += 1) {
                try putMerged(ui.buffer, rx, y, bset.vertical_right, bstyle, self.merge_borders);
            }
        }
        if (self.borders.top) {
            const left_skip: u16 = @intFromBool(self.borders.left);
            const right_skip: u16 = @intFromBool(self.borders.right);
            var x: u16 = bounds.left() +| left_skip;
            const end_x = bounds.right() -| right_skip;
            while (x < end_x) : (x += 1) {
                try putMerged(ui.buffer, x, bounds.top(), bset.horizontal_top, bstyle, self.merge_borders);
            }
        }
        if (self.borders.bottom and bounds.bottom() > 0 and !(bounds.height == 1 and self.borders.top)) {
            const by = bounds.bottom() - 1;
            const left_skip: u16 = @intFromBool(self.borders.left);
            const right_skip: u16 = @intFromBool(self.borders.right);
            var x: u16 = bounds.left() +| left_skip;
            const end_x = bounds.right() -| right_skip;
            while (x < end_x) : (x += 1) {
                try putMerged(ui.buffer, x, by, bset.horizontal_bottom, bstyle, self.merge_borders);
            }
        }

        // Corners.
        if (self.borders.top and self.borders.left) {
            try putMerged(ui.buffer, bounds.left(), bounds.top(), bset.top_left, bstyle, self.merge_borders);
        }
        if (self.borders.top and self.borders.right and bounds.width > 1) {
            try putMerged(ui.buffer, bounds.right() - 1, bounds.top(), bset.top_right, bstyle, self.merge_borders);
        }
        if (self.borders.bottom and self.borders.left and bounds.height > 1) {
            try putMerged(ui.buffer, bounds.left(), bounds.bottom() - 1, bset.bottom_left, bstyle, self.merge_borders);
        }
        if (self.borders.bottom and self.borders.right and bounds.width > 1 and bounds.height > 1) {
            try putMerged(ui.buffer, bounds.right() - 1, bounds.bottom() - 1, bset.bottom_right, bstyle, self.merge_borders);
        }

        // 4. Titles inside horizontal edge strip.
        const default_title_style = self.title_style orelse if (self.focused) ui.theme.accent.patch(.{ .bold = true }) else ui.theme.title;
        if (self.title) |t| {
            self.renderTitle(ui.buffer, bounds, .{
                .text = t,
                .alignment = self.title_alignment,
                .position = .top,
                .style = default_title_style,
            }, default_title_style);
        }
        if (self.title_bottom) |tb| {
            self.renderTitle(ui.buffer, bounds, .{
                .text = tb,
                .alignment = self.title_bottom_alignment,
                .position = .bottom,
                .style = ui.theme.muted,
            }, default_title_style);
        }
        for (self.titles) |t| {
            self.renderTitle(ui.buffer, bounds, t, default_title_style);
        }
    }

    fn renderTitle(
        self: Block,
        buf: *Buffer,
        bounds: Rect,
        t: Title,
        fallback_style: Style,
    ) void {
        if (bounds.height == 0 or bounds.width == 0) return;
        if (t.position == .bottom and bounds.height < 2 and (self.borders.top or self.title != null)) return;
        const y: u16 = switch (t.position) {
            .top => bounds.top(),
            .bottom => bounds.bottom() - 1,
        };
        if (t.position == .top and !self.borders.top and bounds.height < 2) {
            // Still render on top row even for borderless header containers.
        }

        const left_pad: u16 = if (self.borders.left) 1 else 0;
        const right_pad: u16 = if (self.borders.right) 1 else 0;
        if (bounds.width <= left_pad + right_pad) return;

        const strip = Rect.init(
            bounds.left() + left_pad,
            y,
            bounds.width - left_pad - right_pad,
            1,
        );
        const eff_style = t.style orelse fallback_style;

        if (t.spans.len > 0) {
            const line = Line{
                .spans = t.spans,
                .alignment = t.alignment,
                .style = eff_style,
            };
            line.render(buf, strip, t.alignment, .{});
            return;
        }

        if (t.text.len == 0) return;
        // Pad single-space breathing room around title when border edge is drawn and space permits.
        const has_edge = (t.position == .top and self.borders.top) or (t.position == .bottom and self.borders.bottom);
        var buf_padded: [256]u8 = undefined;
        var draw_text = t.text;
        if (has_edge and strip.width >= text_root.displayWidth(t.text) + 2 and t.text.len + 2 <= buf_padded.len) {
            buf_padded[0] = ' ';
            @memcpy(buf_padded[1 .. 1 + t.text.len], t.text);
            buf_padded[1 + t.text.len] = ' ';
            draw_text = buf_padded[0 .. t.text.len + 2];
        }

        const w = text_root.displayWidth(draw_text);
        const clamped_w = @min(w, strip.width);
        const x: u16 = switch (t.alignment) {
            .left => strip.x,
            .center => strip.x + (strip.width - clamped_w) / 2,
            .right => strip.right() - clamped_w,
        };
        _ = buf.setStringClipped(x, y, draw_text, clamped_w, eff_style, strip);
    }

    fn putMerged(buf: *Buffer, x: u16, y: u16, sym: []const u8, style: Style, strategy: MergeStrategy) !void {
        if (buf.getMut(x, y)) |cell| {
            cell.mergeSymbol(sym, strategy);
            cell.diff_option = .none;
            cell.setStyle(style);
        }
    }
};

test "block draws rounded borders, collapses adjacent shared edges, and computes inner area" {
    const alloc = testing.allocator;
    var buf = try Buffer.init(alloc, Rect.init(0, 0, 20, 6));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    const b1 = Block{ .title = "Left", .border_type = .plain, .padding = Padding.symmetric(1, 0) };
    const inner = b1.inner(Rect.init(0, 0, 10, 4));
    try testing.expectEqual(Rect.init(2, 1, 6, 2), inner);

    // Adjacent blocks sharing column x=9 should merge T-junctions nicely.
    try b1.render(&ui, Rect.init(0, 0, 10, 4));
    try (Block{ .title = "Right", .border_type = .plain }).render(&ui, Rect.init(9, 0, 10, 4));

    try testing.expectEqualStrings("┬", buf.get(9, 0).?.symbol());
    try testing.expectEqualStrings("┴", buf.get(9, 3).?.symbol());

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Left") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "Right") != null);
}
