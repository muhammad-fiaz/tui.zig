//! Searchable, severity-filtered structured `LogViewer` with per-source target
//! filtering (`EWIDT` level matrix), match highlighting, and follow-tail scrolling.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const event_root = @import("../event/root.zig");
const text_root = @import("../text/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const Block = block_mod.Block;
pub const Event = event_root.Event;

/// Severity level for `LogEntry` and `LogViewer` filtering.
pub const LogLevel = enum(u8) {
    trace = 0,
    debug = 1,
    info = 2,
    warn = 3,
    err = 4,

    pub fn tag(self: LogLevel) []const u8 {
        return switch (self) {
            .trace => "TRC",
            .debug => "DBG",
            .info => "INF",
            .warn => "WRN",
            .err => "ERR",
        };
    }

    pub fn shortChar(self: LogLevel) u8 {
        return switch (self) {
            .err => 'E',
            .warn => 'W',
            .info => 'I',
            .debug => 'D',
            .trace => 'T',
        };
    }

    pub fn raise(self: LogLevel) LogLevel {
        return switch (self) {
            .err => .warn,
            .warn => .info,
            .info => .debug,
            .debug => .trace,
            .trace => .trace,
        };
    }

    pub fn lower(self: LogLevel) LogLevel {
        return switch (self) {
            .trace => .debug,
            .debug => .info,
            .info => .warn,
            .warn => .err,
            .err => .err,
        };
    }
};

/// Single structured log record rendered inside `LogViewer`.
pub const LogEntry = struct {
    timestamp: ?[]const u8 = null,
    level: LogLevel = .info,
    source: ?[]const u8 = null,
    message: []const u8,
};

/// Per-source minimum display threshold stored inside `LogViewerState`.
pub const SourceFilter = struct {
    name: []const u8 = "",
    min_level: LogLevel = .trace,
    enabled: bool = true,
};

/// Scroll, filter, target-matrix, and auto-follow state for `LogViewer`.
pub const LogViewerState = struct {
    pub const max_sources: usize = 32;

    scroll_y: usize = 0,
    selected: ?usize = null,
    min_level: LogLevel = .trace,
    follow_tail: bool = true,
    filter: []const u8 = "",

    /// Toggleable left-hand source/target selector pane (`h` key).
    show_targets: bool = false,
    /// When true and `show_targets` is open, arrow keys control the target selector instead of log scroll.
    target_pane_focused: bool = false,
    /// Selected row in the target selector pane.
    target_cursor: usize = 0,
    /// Solo-focused source name (`null` shows all sources).
    focused_source: ?[]const u8 = null,
    /// Fixed-capacity per-source threshold overrides (zero heap allocations).
    source_filters: [max_sources]SourceFilter = @splat(SourceFilter{}),
    source_filter_len: usize = 0,

    /// Returns the effective minimum `LogLevel` for `source`, or `null` if disabled.
    pub fn effectiveSourceLevel(self: *const LogViewerState, source: ?[]const u8) ?LogLevel {
        const src = source orelse return self.min_level;
        for (self.source_filters[0..self.source_filter_len]) |sf| {
            if (std.mem.eql(u8, sf.name, src)) {
                if (!sf.enabled) return null;
                return if (@backingInt(sf.min_level) > @backingInt(self.min_level)) sf.min_level else self.min_level;
            }
        }
        return self.min_level;
    }

    /// Sets or updates a per-source level filter.
    pub fn setSourceLevel(self: *LogViewerState, source: []const u8, level: LogLevel) void {
        for (self.source_filters[0..self.source_filter_len]) |*sf| {
            if (std.mem.eql(u8, sf.name, source)) {
                sf.min_level = level;
                sf.enabled = true;
                return;
            }
        }
        if (self.source_filter_len < max_sources) {
            self.source_filters[self.source_filter_len] = .{
                .name = source,
                .min_level = level,
                .enabled = true,
            };
            self.source_filter_len += 1;
        }
    }

    /// Toggles whether `source` is enabled in the log view.
    pub fn toggleSourceEnabled(self: *LogViewerState, source: []const u8) void {
        for (self.source_filters[0..self.source_filter_len]) |*sf| {
            if (std.mem.eql(u8, sf.name, source)) {
                sf.enabled = !sf.enabled;
                return;
            }
        }
        if (self.source_filter_len < max_sources) {
            self.source_filters[self.source_filter_len] = .{
                .name = source,
                .min_level = self.min_level,
                .enabled = false,
            };
            self.source_filter_len += 1;
        }
    }

    pub fn handleEvent(self: *LogViewerState, event: Event, visible_count: usize, viewport_rows: u16, bounds: Rect, focused: bool) bool {
        switch (event) {
            .mouse => |m| {
                if (!m.isInside(bounds)) return false;
                if (m.kind == .scroll_up) {
                    self.follow_tail = false;
                    self.scroll_y -|= 3;
                    return true;
                }
                if (m.kind == .scroll_down) {
                    const max_off = visible_count -| viewport_rows;
                    self.scroll_y = @min(max_off, self.scroll_y + 3);
                    self.follow_tail = self.scroll_y >= max_off;
                    return true;
                }
                if (m.isLeftClickInside(bounds) and visible_count > 0) {
                    const idx = self.scroll_y + (m.y - bounds.top());
                    if (idx < visible_count) {
                        self.selected = idx;
                        self.follow_tail = false;
                        return true;
                    }
                }
                return false;
            },
            .key => |k| {
                if (!focused or k.kind == .release) return false;
                const max_off = visible_count -| viewport_rows;
                const page = @max(@as(usize, 1), viewport_rows);
                switch (k.code) {
                    .tab => {
                        if (self.show_targets) {
                            self.target_pane_focused = !self.target_pane_focused;
                            return true;
                        }
                        return false;
                    },
                    .down => {
                        if (self.show_targets and self.target_pane_focused) {
                            self.target_cursor +|= 1;
                            return true;
                        }
                        if (self.scroll_y < max_off) self.scroll_y += 1;
                        self.follow_tail = self.scroll_y >= max_off;
                        return true;
                    },
                    .up => {
                        if (self.show_targets and self.target_pane_focused) {
                            self.target_cursor -|= 1;
                            return true;
                        }
                        self.follow_tail = false;
                        self.scroll_y -|= 1;
                        return true;
                    },
                    .page_down => {
                        self.scroll_y = @min(max_off, self.scroll_y + page);
                        self.follow_tail = self.scroll_y >= max_off;
                        return true;
                    },
                    .page_up => {
                        self.follow_tail = false;
                        self.scroll_y -|= page;
                        return true;
                    },
                    .home => {
                        self.follow_tail = false;
                        self.scroll_y = 0;
                        return true;
                    },
                    .end => {
                        self.follow_tail = true;
                        self.scroll_y = max_off;
                        return true;
                    },
                    .char => |cp| {
                        if (cp == 'h') {
                            self.show_targets = !self.show_targets;
                            self.target_pane_focused = self.show_targets;
                            return true;
                        }
                        if (cp == 'f') {
                            self.follow_tail = !self.follow_tail;
                            return true;
                        }
                        if (cp == 'j') {
                            if (self.scroll_y < max_off) self.scroll_y += 1;
                            self.follow_tail = self.scroll_y >= max_off;
                            return true;
                        }
                        if (cp == 'k') {
                            self.follow_tail = false;
                            self.scroll_y -|= 1;
                            return true;
                        }
                        if (cp == '+') {
                            self.min_level = self.min_level.raise();
                            return true;
                        }
                        if (cp == '-') {
                            self.min_level = self.min_level.lower();
                            return true;
                        }
                        return false;
                    },
                    else => return false,
                }
            },
            else => return false,
        }
    }
};

fn indexOfIgnoreCase(haystack: []const u8, needle: []const u8) ?usize {
    if (needle.len == 0) return 0;
    if (needle.len > haystack.len) return null;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[i .. i + needle.len], needle)) return i;
    }
    return null;
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    return indexOfIgnoreCase(haystack, needle) != null;
}

/// Searchable, severity-filtered structured log viewer supporting per-source target
/// filtering (`EWIDT` matrix), match highlighting, and follow-tail playback.
pub const LogViewer = struct {
    entries: []const LogEntry = &.{},
    block: ?Block = .{ .title = "Logs" },
    show_timestamps: bool = true,
    show_line_numbers: bool = false,
    show_status_line: bool = true,
    target_pane_width: u16 = 22,
    focused: bool = true,

    /// Handles keyboard & mouse events including target-selector level adjustments.
    pub fn handleEvent(self: LogViewer, state: *LogViewerState, event: Event, bounds: Rect) bool {
        if (state.show_targets and state.target_pane_focused and event == .key and event.key.kind != .release) {
            var sources: [LogViewerState.max_sources][]const u8 = undefined;
            const src_count = self.collectSources(&sources);
            if (src_count > 0) {
                state.target_cursor = @min(state.target_cursor, src_count - 1);
                const cur_src = sources[state.target_cursor];
                switch (event.key.code) {
                    .left => {
                        const cur_lvl = state.effectiveSourceLevel(cur_src) orelse state.min_level;
                        state.setSourceLevel(cur_src, cur_lvl.lower());
                        return true;
                    },
                    .right => {
                        const cur_lvl = state.effectiveSourceLevel(cur_src) orelse state.min_level;
                        state.setSourceLevel(cur_src, cur_lvl.raise());
                        return true;
                    },
                    .char => |cp| {
                        if (cp == ' ') {
                            state.toggleSourceEnabled(cur_src);
                            return true;
                        }
                        if (cp == 's') {
                            if (state.focused_source) |fs| {
                                state.focused_source = if (std.mem.eql(u8, fs, cur_src)) null else cur_src;
                            } else {
                                state.focused_source = cur_src;
                            }
                            return true;
                        }
                    },
                    else => {},
                }
            }
        }
        const inner = if (self.block) |b| b.inner(bounds) else bounds;
        const vis = self.visibleCount(state.*);
        const vp_h = inner.height -| @as(u16, if (self.show_status_line and inner.height > 2) 1 else 0);
        return state.handleEvent(event, vis, vp_h, inner, self.focused);
    }

    fn collectSources(self: LogViewer, out: *[LogViewerState.max_sources][]const u8) usize {
        var count: usize = 0;
        for (self.entries) |e| {
            const src = e.source orelse continue;
            var seen = false;
            for (out[0..count]) |existing| {
                if (std.mem.eql(u8, existing, src)) {
                    seen = true;
                    break;
                }
            }
            if (!seen and count < LogViewerState.max_sources) {
                out[count] = src;
                count += 1;
            }
        }
        return count;
    }

    fn entryMatches(entry: LogEntry, state: LogViewerState) bool {
        if (state.focused_source) |fs| {
            const src = entry.source orelse return false;
            if (!std.mem.eql(u8, src, fs)) return false;
        }
        const eff_min = state.effectiveSourceLevel(entry.source) orelse return false;
        if (@backingInt(entry.level) < @backingInt(eff_min)) return false;
        if (!containsIgnoreCase(entry.message, state.filter) and
            !(if (entry.source) |src| containsIgnoreCase(src, state.filter) else false))
        {
            return false;
        }
        return true;
    }

    /// Counts entries matching `state.min_level`, per-source filters, and `state.filter`.
    pub fn visibleCount(self: LogViewer, state: LogViewerState) usize {
        var count: usize = 0;
        for (self.entries) |e| {
            if (entryMatches(e, state)) count += 1;
        }
        return count;
    }

    fn drawHighlighted(ui: *Ui, x_start: u16, y: u16, text: []const u8, filter: []const u8, base_s: Style, hl_s: Style, row_rect: Rect) u16 {
        var x = x_start;
        if (filter.len == 0) {
            return ui.buffer.setStringClipped(x, y, text, row_rect.right() -| x, base_s, row_rect).x;
        }
        var pos: usize = 0;
        while (pos < text.len and x < row_rect.right()) {
            if (indexOfIgnoreCase(text[pos..], filter)) |rel| {
                if (rel > 0) {
                    x = ui.buffer.setStringClipped(x, y, text[pos .. pos + rel], row_rect.right() -| x, base_s, row_rect).x;
                }
                const match_end = pos + rel + filter.len;
                x = ui.buffer.setStringClipped(x, y, text[pos + rel .. match_end], row_rect.right() -| x, hl_s, row_rect).x;
                pos = match_end;
            } else {
                x = ui.buffer.setStringClipped(x, y, text[pos..], row_rect.right() -| x, base_s, row_rect).x;
                break;
            }
        }
        return x;
    }

    pub fn renderStateful(self: LogViewer, ui: *Ui, area: Rect, state: *LogViewerState) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        var log_area = inner;
        if (state.show_targets and inner.width > self.target_pane_width + 12) {
            const target_rect = Rect.init(inner.left(), inner.top(), self.target_pane_width, inner.height);
            const sep_x = inner.left() + self.target_pane_width;
            log_area = Rect.init(sep_x + 1, inner.top(), inner.width - self.target_pane_width - 1, inner.height);

            // Vertical divider
            var sy = inner.top();
            while (sy < inner.bottom()) : (sy += 1) {
                _ = ui.buffer.setStringClipped(sep_x, sy, style_root.symbols.line.normal.vertical, 1, ui.theme.border, inner);
            }

            // Target selector header + EWIDT rows
            _ = ui.buffer.setStringClipped(target_rect.left(), target_rect.top(), "EWIDT Target", target_rect.width, ui.theme.muted.patch(.{ .bold = true }), target_rect);
            var sources: [LogViewerState.max_sources][]const u8 = undefined;
            const src_count = self.collectSources(&sources);
            if (src_count > 0) state.target_cursor = @min(state.target_cursor, src_count - 1);

            const levels = [_]LogLevel{ .err, .warn, .info, .debug, .trace };
            for (sources[0..src_count], 0..) |src, si| {
                const ry = target_rect.top() + 1 + @as(u16, @intCast(si));
                if (ry >= target_rect.bottom()) break;
                const r_rect = Rect.init(target_rect.left(), ry, target_rect.width, 1);
                const is_cur = state.target_pane_focused and si == state.target_cursor;
                if (is_cur) ui.buffer.setStyle(r_rect, ui.theme.selection);

                const eff = state.effectiveSourceLevel(src);
                var tx = target_rect.left();
                for (levels) |lvl| {
                    const active = if (eff) |e| @backingInt(lvl) >= @backingInt(e) else false;
                    const ch = [_]u8{lvl.shortChar()};
                    const ls = if (active) ui.theme.accent.patch(.{ .bold = true, .reverse = !is_cur }) else ui.theme.muted;
                    tx = ui.buffer.setStringClipped(tx, ry, &ch, 1, ls, r_rect).x;
                }
                const is_solo = if (state.focused_source) |fs| std.mem.eql(u8, fs, src) else false;
                tx = ui.buffer.setStringClipped(tx, ry, if (is_solo) "*" else " ", 1, ui.theme.warning, r_rect).x;
                _ = ui.buffer.setStringClipped(tx, ry, src, r_rect.right() -| tx, if (is_cur) ui.theme.selection else ui.theme.text, r_rect);
            }
        }

        const status_rows: u16 = if (self.show_status_line and log_area.height > 2) 1 else 0;
        const view_area = Rect.init(log_area.left(), log_area.top(), log_area.width, log_area.height -| status_rows);

        const vis_total = self.visibleCount(state.*);
        const max_off = vis_total -| view_area.height;
        if (state.follow_tail) {
            state.scroll_y = max_off;
        } else if (state.scroll_y > max_off) {
            state.scroll_y = max_off;
        }

        var vis_idx: usize = 0;
        var drawn: u16 = 0;
        var ln_buf: [16]u8 = undefined;
        const hl_style = ui.theme.warning.patch(.{ .reverse = true, .bold = true });

        for (self.entries) |entry| {
            if (!entryMatches(entry, state.*)) continue;

            if (vis_idx < state.scroll_y) {
                vis_idx += 1;
                continue;
            }
            if (drawn >= view_area.height) break;

            const gy = view_area.top() + drawn;
            const row_rect = Rect.init(view_area.left(), gy, view_area.width, 1);
            const is_sel = if (state.selected) |s| s == vis_idx else false;
            if (is_sel) {
                ui.buffer.setStyle(row_rect, ui.theme.selection);
            }

            var x = view_area.left();
            if (self.show_line_numbers) {
                const num_s = std.fmt.bufPrint(&ln_buf, "{d:>4} ", .{vis_idx + 1}) catch "";
                x = ui.buffer.setStringClipped(x, gy, num_s, view_area.right() -| x, ui.theme.muted, row_rect).x;
            }
            if (self.show_timestamps) {
                if (entry.timestamp) |ts| {
                    x = ui.buffer.setStringClipped(x, gy, ts, view_area.right() -| x, ui.theme.muted, row_rect).x;
                    x = ui.buffer.setStringClipped(x, gy, " ", view_area.right() -| x, ui.theme.muted, row_rect).x;
                }
            }

            const lvl_s = switch (entry.level) {
                .trace => ui.theme.muted,
                .debug => ui.theme.secondary,
                .info => ui.theme.info,
                .warn => ui.theme.warning,
                .err => ui.theme.err,
            };
            x = ui.buffer.setStringClipped(x, gy, entry.level.tag(), view_area.right() -| x, lvl_s.patch(.{ .bold = true }), row_rect).x;
            x = ui.buffer.setStringClipped(x, gy, " ", view_area.right() -| x, ui.theme.text, row_rect).x;

            if (entry.source) |src| {
                x = ui.buffer.setStringClipped(x, gy, "[", view_area.right() -| x, ui.theme.muted, row_rect).x;
                x = drawHighlighted(ui, x, gy, src, state.filter, ui.theme.accent, hl_style, row_rect);
                x = ui.buffer.setStringClipped(x, gy, "] ", view_area.right() -| x, ui.theme.muted, row_rect).x;
            }

            const msg_s = if (is_sel) ui.theme.selection else ui.theme.text;
            _ = drawHighlighted(ui, x, gy, entry.message, state.filter, msg_s, hl_style, row_rect);

            vis_idx += 1;
            drawn += 1;
        }

        if (status_rows > 0) {
            const sy = view_area.bottom();
            const s_rect = Rect.init(log_area.left(), sy, log_area.width, 1);
            var st_buf: [96]u8 = undefined;
            const mode_s = if (state.follow_tail) "FOLLOW" else "PAUSED";
            const status_txt = std.fmt.bufPrint(&st_buf, "{s}  min:{s}  {d}/{d}  h:targets f:follow +/-:lvl", .{
                mode_s,
                state.min_level.tag(),
                vis_total,
                self.entries.len,
            }) catch "";
            _ = ui.buffer.setStringClipped(s_rect.left(), sy, status_txt, s_rect.width, ui.theme.muted, s_rect);
        }
    }
};

test "log viewer filters by minimum level, per-source level, and renders entries" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 56, 7));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    var log_st = LogViewerState{ .min_level = .info, .show_targets = true };
    log_st.setSourceLevel("db", .warn);
    try (LogViewer{
        .entries = &.{
            .{ .level = .debug, .source = "net", .message = "Filtered debug" },
            .{ .level = .info, .source = "db", .message = "Filtered db info" },
            .{ .level = .info, .source = "net", .message = "Listening on :8080" },
        },
    }).renderStateful(&ui, buf.area, &log_st);

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Listening") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "Filtered debug") == null);
    try testing.expect(std.mem.indexOf(u8, snap, "Filtered db info") == null);
    try testing.expect(std.mem.indexOf(u8, snap, "EWIDT") != null);
}
