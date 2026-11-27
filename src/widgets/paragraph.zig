//! Multi-line rich `Paragraph` widget with word/char wrapping, horizontal truncation,
//! alignment, vertical/horizontal scroll, and optional container `Block`.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Alignment = core_root.Alignment;
pub const Buffer = core_root.Buffer;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const Block = block_mod.Block;
pub const Text = text_root.Text;
pub const Line = text_root.Line;
pub const Span = text_root.Span;
pub const WrapMode = text_root.WrapMode;
pub const Truncation = text_root.Truncation;

/// Two-axis scroll offset for text viewports.
pub const ScrollOffset = struct {
    x: u16 = 0,
    y: u16 = 0,
};

/// Multi-line paragraph supporting either raw UTF-8 text or styled multi-span `Text`.
///
/// Both plain string wrapping and multi-span rich lines run without heap churn
/// by streaming wrapped visual segments directly into `Buffer` (or using `ui.scratch`
/// only when needed).
pub const Paragraph = struct {
    /// Rich multi-line text (`lines`). Used when `raw == null`.
    text: Text = .{},
    /// Convenience raw UTF-8 string overriding `text` when non-null.
    raw: ?[]const u8 = null,
    /// Optional surrounding container block.
    block: ?Block = null,
    /// Base style applied over the inner area and inherited by text spans.
    style: ?Style = null,
    /// Horizontal alignment for every line (`text.alignment` used if `null`, else `.left`).
    alignment: ?Alignment = null,
    /// Line wrapping mode (`.word`, `.char`, or `.none`).
    wrap: WrapMode = .none,
    /// Truncation style when `wrap == .none` and text exceeds available width.
    truncation: Truncation = .end,
    /// Horizontal/vertical viewport scroll offset.
    scroll: ScrollOffset = .{},
    /// Optional tab expansion width (`null` uses `ui.tab_size`).
    tab_size: ?u8 = null,

    /// Creates a `Paragraph` wrapping a plain UTF-8 string slice.
    pub fn fromSlice(raw: []const u8) Paragraph {
        return .{ .raw = raw };
    }

    /// Creates a `Paragraph` wrapping a styled `Text`.
    pub fn fromText(t: Text) Paragraph {
        return .{ .text = t };
    }

    /// Creates a `Paragraph` wrapping a borrowed slice of `Line`s.
    pub fn fromLines(lines: []const Line) Paragraph {
        return .{ .text = Text.fromLines(lines) };
    }

    /// Attaches a container `Block`.
    pub fn withBlock(self: Paragraph, b: Block) Paragraph {
        var copy = self;
        copy.block = b;
        return copy;
    }

    /// Sets wrapping mode.
    pub fn wrapped(self: Paragraph, mode: WrapMode) Paragraph {
        var copy = self;
        copy.wrap = mode;
        return copy;
    }

    /// Sets horizontal alignment.
    pub fn aligned(self: Paragraph, a: Alignment) Paragraph {
        var copy = self;
        copy.alignment = a;
        return copy;
    }

    /// Computes total rendered line count for a given inner width (without borders).
    pub fn lineCount(self: Paragraph, inner_width: u16) usize {
        if (inner_width == 0) return 0;
        const tab_w = self.tab_size orelse 4;
        if (self.raw) |raw_str| {
            var count: usize = 0;
            var raw_it = text_root.splitLinesIter(raw_str);
            var tab_buf: [4096]u8 = undefined;
            while (raw_it.next()) |logical_line| {
                const expanded = expandTabsInto(logical_line, 0, tab_w, &tab_buf);
                if (self.wrap == .none) {
                    count += 1;
                } else {
                    var wit = text_root.WrapIterator.init(expanded, inner_width, .{ .mode = self.wrap });
                    while (wit.next() != null) count += 1;
                }
            }
            return count;
        }

        if (self.wrap == .none) return self.text.lines.len;

        var total: usize = 0;
        for (self.text.lines) |ln| {
            total += countWrappedRichLine(ln, inner_width, self.wrap, tab_w);
        }
        return total;
    }

    /// Computes total wrapped line count inside outer `area` (accounting for optional `Block`).
    pub fn totalHeightForWidth(self: Paragraph, total_width: u16) u16 {
        const inner_w = if (self.block) |b|
            b.inner(Rect.init(0, 0, total_width, 10)).width
        else
            total_width;
        const lines = self.lineCount(inner_w);
        const extra_h: usize = if (self.block) |b|
            @as(usize, @intFromBool(b.borders.top)) +
                @intFromBool(b.borders.bottom) +
                b.padding.top + b.padding.bottom
        else
            0;
        return @intCast(@min(std.math.maxInt(u16), lines + extra_h));
    }

    /// Renders this paragraph onto `ui` inside `area`.
    pub fn render(self: Paragraph, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        const base_style = if (self.style) |s| ui.theme.text.patch(s) else ui.theme.text;
        if (self.style != null) {
            ui.buffer.setStyle(inner, base_style);
        }

        const eff_align = self.alignment orelse self.text.alignment orelse .left;
        const tab_w = @max(@as(u8, 1), self.tab_size orelse ui.tab_size);

        if (self.raw) |raw_str| {
            self.renderRaw(ui.buffer, inner, raw_str, base_style, eff_align, tab_w);
            return;
        }

        const text_style = base_style.patch(self.text.style);
        var visual_row: usize = 0;
        for (self.text.lines) |ln| {
            if (visual_row >= @as(usize, self.scroll.y) + inner.height) break;

            if (self.wrap == .none) {
                if (visual_row >= self.scroll.y) {
                    const screen_y = inner.y + @as(u16, @intCast(visual_row - self.scroll.y));
                    renderRichLineSingleRow(ui.buffer, inner, screen_y, ln, eff_align, text_style, self.scroll.x, self.truncation, tab_w);
                }
                visual_row += 1;
            } else {
                visual_row = renderWrappedRichLine(
                    ui.buffer,
                    inner,
                    ln,
                    eff_align,
                    text_style,
                    self.wrap,
                    self.scroll.y,
                    visual_row,
                    tab_w,
                );
            }
        }
    }

    fn renderRaw(
        self: Paragraph,
        buf: *Buffer,
        inner: Rect,
        raw_str: []const u8,
        base_style: Style,
        eff_align: Alignment,
        tab_size: u8,
    ) void {
        var visual_row: usize = 0;
        var raw_it = text_root.splitLinesIter(raw_str);
        var tab_buf: [4096]u8 = undefined;
        while (raw_it.next()) |logical_line| {
            if (visual_row >= @as(usize, self.scroll.y) + inner.height) break;
            const expanded = expandTabsInto(logical_line, 0, tab_size, &tab_buf);

            if (self.wrap == .none) {
                if (visual_row >= self.scroll.y) {
                    const screen_y = inner.y + @as(u16, @intCast(visual_row - self.scroll.y));
                    renderRawLineSlice(buf, inner, screen_y, expanded, base_style, eff_align, self.scroll.x, self.truncation);
                }
                visual_row += 1;
            } else {
                var wit = text_root.WrapIterator.init(expanded, inner.width, .{ .mode = self.wrap });
                while (wit.next()) |seg| {
                    if (visual_row >= @as(usize, self.scroll.y) + inner.height) break;
                    if (visual_row >= self.scroll.y) {
                        const screen_y = inner.y + @as(u16, @intCast(visual_row - self.scroll.y));
                        const x = alignedX(inner, seg.width, eff_align);
                        _ = buf.setStringClipped(x, screen_y, seg.slice, inner.width, base_style, inner);
                    }
                    visual_row += 1;
                }
            }
        }
    }
};

fn expandTabsInto(slice: []const u8, start_col: u16, tab_size: u8, out: []u8) []const u8 {
    if (std.mem.indexOfScalar(u8, slice, '\t') == null) return slice;
    const tw: u16 = @max(@as(u16, 1), tab_size);
    var col = start_col;
    var pos: usize = 0;
    var git = text_root.GraphemeIterator.init(slice);
    while (git.next()) |g| {
        if (g.slice.len == 1 and g.slice[0] == '\t') {
            const spaces = tw - (col % tw);
            var s: u16 = 0;
            while (s < spaces and pos < out.len) : (s += 1) {
                out[pos] = ' ';
                pos += 1;
            }
            col +|= spaces;
            continue;
        }
        if (g.width == 0) continue;
        if (pos + g.slice.len > out.len) break;
        @memcpy(out[pos .. pos + g.slice.len], g.slice);
        pos += g.slice.len;
        col +|= g.width;
    }
    return out[0..pos];
}

const sixteen_spaces = "                ";

fn lineWidthWithTabs(ln: Line, tab_size: u8) u16 {
    const tw: u16 = @max(@as(u16, 1), tab_size);
    var col: u16 = 0;
    for (ln.spans) |sp| {
        if (std.mem.indexOfScalar(u8, sp.content, '\t') == null) {
            col +|= sp.width();
            continue;
        }
        var git = text_root.GraphemeIterator.init(sp.content);
        while (git.next()) |g| {
            if (g.slice.len == 1 and g.slice[0] == '\t') {
                col +|= tw - (col % tw);
            } else {
                col +|= g.width;
            }
        }
    }
    return col;
}

fn alignedX(inner: Rect, content_width: u16, align_mode: Alignment) u16 {
    if (content_width >= inner.width) return inner.x;
    return switch (align_mode) {
        .left => inner.x,
        .center => inner.x + (inner.width - content_width) / 2,
        .right => inner.x + (inner.width - content_width),
    };
}

/// Renders a single raw UTF-8 slice into row `screen_y` inside `inner`, supporting horizontal scroll and ellipsis truncation.
pub fn renderRawLineSlice(
    buf: *Buffer,
    inner: Rect,
    screen_y: u16,
    slice: []const u8,
    style: Style,
    align_mode: Alignment,
    scroll_x: u16,
    truncation: Truncation,
) void {
    if (inner.width == 0) return;

    // Advance past `scroll_x` display columns by grapheme boundaries.
    var visible = slice;
    if (scroll_x > 0) {
        var skipped: u16 = 0;
        var it = text_root.GraphemeIterator.init(slice);
        var byte_start: usize = slice.len;
        while (it.next()) |g| {
            if (skipped >= scroll_x) {
                byte_start = it.index - g.slice.len;
                break;
            }
            skipped += g.width;
        }
        if (skipped < scroll_x) return;
        visible = slice[byte_start..];
    }

    const total_w = text_root.displayWidth(visible);
    if (total_w > inner.width and truncation != .clip) {
        var trunc_buf: [512]u8 = undefined;
        const truncated = text_root.truncateInto(visible, inner.width, truncation, &trunc_buf);
        const w = text_root.displayWidth(truncated);
        const x = alignedX(inner, w, align_mode);
        _ = buf.setStringClipped(x, screen_y, truncated, inner.width, style, inner);
        return;
    }

    const draw_w = @min(total_w, inner.width);
    const x = alignedX(inner, draw_w, align_mode);
    _ = buf.setStringClipped(x, screen_y, visible, inner.width, style, inner);
}

fn renderRichLineSingleRow(
    buf: *Buffer,
    inner: Rect,
    screen_y: u16,
    ln: Line,
    fallback_align: Alignment,
    base_style: Style,
    scroll_x: u16,
    truncation: Truncation,
    tab_size: u8,
) void {
    const line_style = base_style.patch(ln.style);
    if (!line_style.background.isInherit() or !line_style.foreground.isInherit()) {
        buf.setStyle(Rect.init(inner.x, screen_y, inner.width, 1), line_style);
    }

    const eff_align = ln.alignment orelse fallback_align;
    const total_w = lineWidthWithTabs(ln, tab_size);
    const scrolled_w = total_w -| scroll_x;
    var cursor_x: u16 = alignedX(inner, @min(scrolled_w, inner.width), eff_align);

    // Track horizontal column offset while advancing across spans.
    var logical_col: u16 = 0;
    var skipped_cols: u16 = 0;
    const tw: u16 = @max(@as(u16, 1), tab_size);
    const reserve_ellipsis: u16 = if (truncation == .end and scrolled_w > inner.width and inner.width >= 1) 1 else 0;
    const max_end_x = inner.right() -| reserve_ellipsis;

    for (ln.spans) |sp| {
        if (cursor_x >= max_end_x) break;
        const sp_style = line_style.patch(sp.style);
        var git = text_root.GraphemeIterator.init(sp.content);
        while (git.next()) |g| {
            if (g.slice.len == 1 and g.slice[0] == '\t') {
                const spaces = tw - (logical_col % tw);
                logical_col +|= spaces;
                var s_rem = spaces;
                while (s_rem > 0) : (s_rem -= 1) {
                    if (skipped_cols < scroll_x) {
                        skipped_cols += 1;
                        continue;
                    }
                    if (cursor_x + 1 > max_end_x) {
                        if (reserve_ellipsis == 1 and cursor_x < inner.right()) {
                            _ = buf.setStringClipped(cursor_x, screen_y, "…", 1, sp_style, inner);
                        }
                        return;
                    }
                    cursor_x = buf.setStringClipped(cursor_x, screen_y, " ", 1, sp_style, inner).x;
                }
                continue;
            }
            if (g.width == 0) continue;
            logical_col +|= g.width;
            if (skipped_cols < scroll_x) {
                skipped_cols += g.width;
                continue;
            }
            if (cursor_x + g.width > max_end_x) {
                if (reserve_ellipsis == 1 and cursor_x < inner.right()) {
                    _ = buf.setStringClipped(cursor_x, screen_y, "…", 1, sp_style, inner);
                }
                return;
            }
            const end_pos = buf.setStringClipped(cursor_x, screen_y, g.slice, g.width, sp_style, inner);
            cursor_x = end_pos.x;
        }
    }
}

const WrappedSpanSegment = struct {
    slice: []const u8,
    style: Style,
    width: u16,
};

fn countWrappedRichLine(ln: Line, max_width: u16, mode: WrapMode, tab_size: u8) usize {
    if (ln.spans.len == 0) return 1;
    const tw: u16 = @max(@as(u16, 1), tab_size);
    var rows: usize = 1;
    var col: u16 = 0;
    for (ln.spans) |sp| {
        if (mode == .char) {
            var it = text_root.GraphemeIterator.init(sp.content);
            while (it.next()) |g| {
                const gw: u16 = if (g.slice.len == 1 and g.slice[0] == '\t') tw - (col % tw) else g.width;
                if (gw == 0) continue;
                if (col > 0 and col + gw > max_width) {
                    rows += 1;
                    col = 0;
                }
                col += gw;
            }
        } else {
            // Word-aware estimation across spans: split by space/tab boundaries inside each span.
            var pos: usize = 0;
            while (pos < sp.content.len) {
                if (sp.content[pos] == ' ') {
                    if (col > 0 and col < max_width) col += 1;
                    pos += 1;
                    continue;
                }
                if (sp.content[pos] == '\t') {
                    const step = tw - (col % tw);
                    if (col + step <= max_width) {
                        col += step;
                    } else {
                        rows += 1;
                        col = 0;
                    }
                    pos += 1;
                    continue;
                }
                const next_ws = std.mem.indexOfAnyPos(u8, sp.content, pos, " \t") orelse sp.content.len;
                const word = sp.content[pos..next_ws];
                const w = text_root.displayWidth(word);
                if (col > 0 and col + w > max_width) {
                    rows += 1;
                    col = 0;
                }
                if (w > max_width) {
                    // Long word wraps mid-word.
                    var git = text_root.GraphemeIterator.init(word);
                    while (git.next()) |g| {
                        if (col > 0 and col + g.width > max_width) {
                            rows += 1;
                            col = 0;
                        }
                        col += g.width;
                    }
                } else {
                    col += w;
                }
                pos = next_ws;
            }
        }
    }
    return rows;
}

fn renderWrappedRichLine(
    buf: *Buffer,
    inner: Rect,
    ln: Line,
    fallback_align: Alignment,
    base_style: Style,
    mode: WrapMode,
    scroll_y: u16,
    start_row: usize,
    tab_size: u8,
) usize {
    const line_style = base_style.patch(ln.style);
    const eff_align = ln.alignment orelse fallback_align;
    const tw: u16 = @max(@as(u16, 1), tab_size);

    if (ln.spans.len == 0) {
        if (start_row >= scroll_y and start_row < @as(usize, scroll_y) + inner.height) {
            const sy = inner.y + @as(u16, @intCast(start_row - scroll_y));
            if (!line_style.background.isInherit() or !line_style.foreground.isInherit()) {
                buf.setStyle(Rect.init(inner.x, sy, inner.width, 1), line_style);
            }
        }
        return start_row + 1;
    }

    // Two-pass per-row token collector using fixed stack segments for zero heap churn.
    var row_segs: [64]WrappedSpanSegment = undefined;
    var seg_count: usize = 0;
    var col: u16 = 0;
    var row_idx: usize = start_row;

    const flushRow = struct {
        fn call(
            b: *Buffer,
            r: Rect,
            r_idx: usize,
            sy_scroll: u16,
            segs: []const WrappedSpanSegment,
            row_w: u16,
            align_m: Alignment,
            ln_style: Style,
        ) void {
            if (r_idx < sy_scroll or r_idx >= @as(usize, sy_scroll) + r.height) return;
            const sy = r.y + @as(u16, @intCast(r_idx - sy_scroll));
            if (!ln_style.background.isInherit() or !ln_style.foreground.isInherit()) {
                b.setStyle(Rect.init(r.x, sy, r.width, 1), ln_style);
            }
            var x = alignedX(r, row_w, align_m);
            for (segs) |seg| {
                const pos = b.setStringClipped(x, sy, seg.slice, seg.width, seg.style, r);
                x = pos.x;
            }
        }
    }.call;

    for (ln.spans) |sp| {
        const sp_style = line_style.patch(sp.style);
        var pos: usize = 0;
        while (pos < sp.content.len) {
            if (mode == .char) {
                var git = text_root.GraphemeIterator.init(sp.content[pos..]);
                const g = git.next() orelse break;
                pos += git.index;
                if (g.slice.len == 1 and g.slice[0] == '\t') {
                    const spaces = tw - (col % tw);
                    const emit = @min(spaces, sixteen_spaces.len);
                    if (col > 0 and col + emit > inner.width) {
                        flushRow(buf, inner, row_idx, scroll_y, row_segs[0..seg_count], col, eff_align, line_style);
                        row_idx += 1;
                        col = 0;
                        seg_count = 0;
                    }
                    const next_spaces = tw - (col % tw);
                    const next_emit = @min(next_spaces, inner.width -| col);
                    if (next_emit > 0 and seg_count < row_segs.len) {
                        const chunk = @min(next_emit, sixteen_spaces.len);
                        row_segs[seg_count] = .{ .slice = sixteen_spaces[0..chunk], .style = sp_style, .width = chunk };
                        seg_count += 1;
                        col += chunk;
                    }
                    continue;
                }
                if (g.width == 0) continue;
                if (col > 0 and col + g.width > inner.width) {
                    flushRow(buf, inner, row_idx, scroll_y, row_segs[0..seg_count], col, eff_align, line_style);
                    row_idx += 1;
                    col = 0;
                    seg_count = 0;
                }
                if (seg_count > 0 and row_segs[seg_count - 1].slice.ptr + row_segs[seg_count - 1].slice.len == g.slice.ptr and
                    std.meta.eql(row_segs[seg_count - 1].style, sp_style))
                {
                    const prev = &row_segs[seg_count - 1];
                    prev.slice = prev.slice.ptr[0 .. prev.slice.len + g.slice.len];
                    prev.width += g.width;
                } else if (seg_count < row_segs.len) {
                    row_segs[seg_count] = .{ .slice = g.slice, .style = sp_style, .width = g.width };
                    seg_count += 1;
                }
                col += g.width;
            } else {
                // Word mode.
                if (sp.content[pos] == ' ') {
                    pos += 1;
                    if (col == 0) continue; // Trim leading spaces after wrap.
                    if (col + 1 <= inner.width and seg_count < row_segs.len) {
                        row_segs[seg_count] = .{ .slice = " ", .style = sp_style, .width = 1 };
                        seg_count += 1;
                        col += 1;
                    } else {
                        flushRow(buf, inner, row_idx, scroll_y, row_segs[0..seg_count], col, eff_align, line_style);
                        row_idx += 1;
                        col = 0;
                        seg_count = 0;
                    }
                    continue;
                }
                if (sp.content[pos] == '\t') {
                    pos += 1;
                    const spaces = tw - (col % tw);
                    const emit = @min(spaces, sixteen_spaces.len);
                    if (col + emit <= inner.width and seg_count < row_segs.len) {
                        row_segs[seg_count] = .{ .slice = sixteen_spaces[0..emit], .style = sp_style, .width = emit };
                        seg_count += 1;
                        col += emit;
                    } else {
                        flushRow(buf, inner, row_idx, scroll_y, row_segs[0..seg_count], col, eff_align, line_style);
                        row_idx += 1;
                        col = 0;
                        seg_count = 0;
                    }
                    continue;
                }
                const next_ws = std.mem.indexOfAnyPos(u8, sp.content, pos, " \t") orelse sp.content.len;
                const word = sp.content[pos..next_ws];
                const ww = text_root.displayWidth(word);
                pos = next_ws;

                if (col > 0 and col + ww > inner.width) {
                    flushRow(buf, inner, row_idx, scroll_y, row_segs[0..seg_count], col, eff_align, line_style);
                    row_idx += 1;
                    col = 0;
                    seg_count = 0;
                }
                if (ww <= inner.width and seg_count < row_segs.len) {
                    row_segs[seg_count] = .{ .slice = word, .style = sp_style, .width = ww };
                    seg_count += 1;
                    col += ww;
                } else {
                    var git = text_root.GraphemeIterator.init(word);
                    while (git.next()) |g| {
                        if (g.width == 0) continue;
                        if (col > 0 and col + g.width > inner.width) {
                            flushRow(buf, inner, row_idx, scroll_y, row_segs[0..seg_count], col, eff_align, line_style);
                            row_idx += 1;
                            col = 0;
                            seg_count = 0;
                        }
                        if (seg_count < row_segs.len) {
                            row_segs[seg_count] = .{ .slice = g.slice, .style = sp_style, .width = g.width };
                            seg_count += 1;
                        }
                        col += g.width;
                    }
                }
            }
        }
    }

    flushRow(buf, inner, row_idx, scroll_y, row_segs[0..seg_count], col, eff_align, line_style);
    return row_idx + 1;
}

test "paragraph word wraps, scrolls, and preserves rich span styling" {
    const alloc = testing.allocator;
    var buf = try Buffer.init(alloc, Rect.init(0, 0, 14, 5));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    const p = Paragraph.fromSlice("Hello Zig terminal world")
        .withBlock(.{ .title = "Msg", .border_type = .plain })
        .wrapped(.word);

    try testing.expectEqual(@as(usize, 3), p.lineCount(12));
    try testing.expectEqual(@as(usize, 2), p.lineCount(14));
    try ui.renderWidget(p, buf.area);

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Hello Zig") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "terminal") != null);

    // Rich spans wrapped across lines preserve bold attribute on second span.
    buf.clear();
    const spans = [_]Span{
        Span.raw("alpha "),
        Span.styled("beta", .{ .bold = true }),
    };
    const rich = Paragraph.fromLines(&.{Line.fromSpans(&spans)}).wrapped(.word);
    try ui.renderWidget(rich, Rect.init(0, 0, 7, 2));
    try testing.expect(buf.get(0, 1).?.style().bold);
    try testing.expectEqualStrings("b", buf.get(0, 1).?.symbol());

    // Tab stops expand cleanly to configured tab_size.
    buf.clear();
    try ui.renderWidget(Paragraph{ .raw = "A\tB", .tab_size = 4 }, Rect.init(0, 0, 10, 1));
    try testing.expectEqualStrings("A", buf.get(0, 0).?.symbol());
    try testing.expectEqualStrings(" ", buf.get(3, 0).?.symbol());
    try testing.expectEqualStrings("B", buf.get(4, 0).?.symbol());
}
