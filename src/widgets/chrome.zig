//! Navigation, chrome, layout containers, and focus helpers:
//! `MenuBar`, `ContextMenu`, `Navbar`, `Sidebar`, `Breadcrumbs`, `StatusBar`,
//! `Header`, `ScrollView`, `SplitPane`, and `FocusGroup`.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const event_root = @import("../event/root.zig");
const clear_mod = @import("clear.zig");
const block_mod = @import("block.zig");
const list_mod = @import("list.zig");
const scrollbar_mod = @import("scrollbar.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Direction = core_root.Direction;
pub const Alignment = core_root.Alignment;
pub const Constraint = core_root.Constraint;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const BorderType = style_root.BorderType;
pub const TextDirection = text_root.TextDirection;
pub const Clear = clear_mod.Clear;
pub const Block = block_mod.Block;
pub const List = list_mod.List;
pub const ListState = list_mod.ListState;
pub const Scrollbar = scrollbar_mod.Scrollbar;
pub const ScrollbarState = scrollbar_mod.ScrollbarState;
pub const Event = event_root.Event;

/// Top-level or context menu action item (supports shortcuts, checkmarks, and nested submenus).
pub const MenuItem = struct {
    label: []const u8,
    id: ?[]const u8 = null,
    shortcut: ?[]const u8 = null,
    enabled: bool = true,
    separator: bool = false,
    checked: ?bool = null,
    children: []const MenuItem = &.{},

    pub fn actionId(self: MenuItem) []const u8 {
        return self.id orelse self.label;
    }
};

/// Top-level menu bar group (`File`, `Edit`, `View`, `Help`) with its drop-down items.
pub const MenuGroup = struct {
    label: []const u8,
    items: []const MenuItem = &.{},
    enabled: bool = true,
};

/// Outcome returned by `MenuState.handleEvent`.
pub const MenuOutcome = enum {
    none,
    moved,
    opened,
    closed,
    triggered,
};

/// Cascading drop-down menu state supporting up to 4 nested submenu levels.
pub const MenuState = struct {
    pub const max_depth: usize = 4;

    active_group: ?usize = null,
    /// `depth == 0` means only the top bar group is selected (or closed); `depth >= 1` means dropdown levels are open.
    depth: usize = 0,
    path: [max_depth]usize = .{ 0, 0, 0, 0 },
    triggered: ?MenuItem = null,

    pub fn isOpen(self: *const MenuState) bool {
        return self.active_group != null and self.depth > 0;
    }

    pub fn openGroup(self: *MenuState, groups: []const MenuGroup, group_idx: usize) void {
        if (group_idx >= groups.len or !groups[group_idx].enabled) return;
        self.active_group = group_idx;
        if (groups[group_idx].items.len > 0) {
            self.depth = 1;
            self.path[0] = firstSelectable(groups[group_idx].items) orelse 0;
        } else {
            self.depth = 0;
        }
    }

    pub fn close(self: *MenuState) void {
        self.depth = 0;
        self.active_group = null;
    }

    fn firstSelectable(items: []const MenuItem) ?usize {
        for (items, 0..) |it, i| {
            if (!it.separator and it.enabled) return i;
        }
        return null;
    }

    fn itemsAtLevel(self: *const MenuState, groups: []const MenuGroup, level: usize) []const MenuItem {
        const g_idx = self.active_group orelse return &.{};
        if (g_idx >= groups.len) return &.{};
        var cur = groups[g_idx].items;
        var l: usize = 0;
        while (l < level) : (l += 1) {
            const idx = self.path[l];
            if (idx >= cur.len) return &.{};
            cur = cur[idx].children;
        }
        return cur;
    }

    fn moveInLevel(self: *MenuState, groups: []const MenuGroup, dir: isize) bool {
        if (self.depth == 0) return false;
        const level = self.depth - 1;
        const items = self.itemsAtLevel(groups, level);
        if (items.len == 0) return false;
        var idx = @min(self.path[level], items.len - 1);
        for (0..items.len) |_| {
            idx = if (dir > 0) (idx + 1) % items.len else (if (idx == 0) items.len - 1 else idx - 1);
            if (!items[idx].separator and items[idx].enabled) {
                self.path[level] = idx;
                return true;
            }
        }
        return false;
    }

    /// Computes exact `(x, y)` coordinates for each top-level group pill.
    fn groupX(groups: []const MenuGroup, target_idx: usize, bar_area: Rect, gap: u16) u16 {
        var x = bar_area.left() +| 1;
        for (groups, 0..) |g, i| {
            if (i == target_idx) return x;
            const pill_w = 2 +| text_root.displayWidth(g.label);
            x +|= pill_w +| (gap -| 1);
        }
        return x;
    }

    fn dropdownBox(items: []const MenuItem, x: u16, y: u16, screen: Rect) Rect {
        if (screen.width < 8 or screen.height < 4 or items.len == 0) return Rect.zero;
        var max_w: u16 = 14;
        for (items) |it| {
            var w = text_root.displayWidth(it.label);
            if (it.checked != null) w +|= 4;
            if (it.shortcut) |sc| w +|= text_root.displayWidth(sc) + 3;
            if (it.children.len > 0) w +|= 3;
            max_w = @max(max_w, w + 4);
        }
        const box_w = @min(screen.width, max_w);
        const box_h: u16 = @intCast(@min(@as(usize, screen.height), items.len + 2));
        const px = @min(x, screen.right() - box_w);
        const py = @min(y, screen.bottom() - box_h);
        return Rect.init(px, py, box_w, box_h);
    }

    /// Handles keyboard & mouse interaction for `DropdownMenu` across bar and nested submenus.
    pub fn handleEvent(self: *MenuState, groups: []const MenuGroup, event: Event, bar_area: Rect, screen: Rect, gap: u16) MenuOutcome {
        if (groups.len == 0) return .none;
        self.triggered = null;

        switch (event) {
            .mouse => |m| {
                if (m.kind == .down and m.button == .left) {
                    if (m.isInside(bar_area) and m.y == bar_area.top()) {
                        var x = bar_area.left() +| 1;
                        for (groups, 0..) |g, i| {
                            if (x >= bar_area.right()) break;
                            const pill_w = 2 +| text_root.displayWidth(g.label);
                            const pill_rect = Rect.init(x, bar_area.top(), @min(pill_w, bar_area.right() - x), 1);
                            if (m.isInside(pill_rect) and g.enabled) {
                                if (self.active_group == i and self.depth > 0) {
                                    self.close();
                                    return .closed;
                                }
                                self.openGroup(groups, i);
                                return .opened;
                            }
                            x +|= pill_w +| (gap -| 1);
                        }
                        return .none;
                    }

                    if (self.isOpen()) {
                        const g_idx = self.active_group.?;
                        var cur_x = groupX(groups, g_idx, bar_area, gap);
                        var cur_y = bar_area.bottom();
                        var boxes: [max_depth]Rect = @splat(Rect.zero);
                        var l: usize = 0;
                        while (l < self.depth) : (l += 1) {
                            const items = self.itemsAtLevel(groups, l);
                            const box = dropdownBox(items, cur_x, cur_y, screen);
                            boxes[l] = box;
                            const sel = @min(self.path[l], items.len -| 1);
                            const next_x = if (box.right() + 18 <= screen.right()) box.right() else box.left() -| 18;
                            cur_x = next_x;
                            cur_y = box.top() + 1 + @as(u16, @intCast(sel));
                        }

                        // Check deepest box first
                        var rev = self.depth;
                        while (rev > 0) {
                            rev -= 1;
                            const box = boxes[rev];
                            const inner = (Block{ .border_type = .rounded }).inner(box);
                            if (m.isInside(inner)) {
                                const idx = m.y - inner.top();
                                const items = self.itemsAtLevel(groups, rev);
                                if (idx < items.len and !items[idx].separator and items[idx].enabled) {
                                    self.path[rev] = idx;
                                    self.depth = rev + 1;
                                    if (items[idx].children.len > 0 and self.depth < max_depth) {
                                        self.path[self.depth] = firstSelectable(items[idx].children) orelse 0;
                                        self.depth += 1;
                                        return .opened;
                                    }
                                    self.triggered = items[idx];
                                    return .triggered;
                                }
                                return .none;
                            }
                            if (m.isInside(box)) return .none;
                        }
                        self.close();
                        return .closed;
                    }
                }
                return .none;
            },
            .key => |k| {
                if (k.kind == .release) return .none;
                switch (k.code) {
                    .escape => {
                        if (self.depth > 1) {
                            self.depth -= 1;
                            return .closed;
                        }
                        if (self.isOpen()) {
                            self.close();
                            return .closed;
                        }
                        return .none;
                    },
                    .left => {
                        if (self.depth > 1) {
                            self.depth -= 1;
                            return .closed;
                        }
                        const cur = self.active_group orelse 0;
                        const prev_g = if (cur == 0) groups.len - 1 else cur - 1;
                        self.openGroup(groups, prev_g);
                        return .moved;
                    },
                    .right => {
                        if (self.isOpen()) {
                            const lvl = self.depth - 1;
                            const items = self.itemsAtLevel(groups, lvl);
                            const sel = self.path[lvl];
                            if (sel < items.len and items[sel].children.len > 0 and self.depth < max_depth) {
                                self.path[self.depth] = firstSelectable(items[sel].children) orelse 0;
                                self.depth += 1;
                                return .opened;
                            }
                        }
                        const cur = self.active_group orelse (groups.len - 1);
                        const next_g = (cur + 1) % groups.len;
                        self.openGroup(groups, next_g);
                        return .moved;
                    },
                    .down => {
                        if (!self.isOpen()) {
                            self.openGroup(groups, self.active_group orelse 0);
                            return .opened;
                        }
                        if (self.moveInLevel(groups, 1)) return .moved;
                        return .none;
                    },
                    .up => {
                        if (self.isOpen() and self.moveInLevel(groups, -1)) return .moved;
                        return .none;
                    },
                    .enter => {
                        if (!self.isOpen()) {
                            self.openGroup(groups, self.active_group orelse 0);
                            return .opened;
                        }
                        const lvl = self.depth - 1;
                        const items = self.itemsAtLevel(groups, lvl);
                        const sel = self.path[lvl];
                        if (sel < items.len and !items[sel].separator and items[sel].enabled) {
                            if (items[sel].children.len > 0 and self.depth < max_depth) {
                                self.path[self.depth] = firstSelectable(items[sel].children) orelse 0;
                                self.depth += 1;
                                return .opened;
                            }
                            self.triggered = items[sel];
                            return .triggered;
                        }
                        return .none;
                    },
                    else => return .none,
                }
            },
            else => return .none,
        }
    }
};

/// Complete horizontal menu bar with cascading drop-down submenus, checkmarks, and shortcuts.
pub const DropdownMenu = struct {
    groups: []const MenuGroup = &.{},
    style: ?Style = null,
    active_style: ?Style = null,
    gap: u16 = 2,

    /// Renders the top horizontal bar into `bar_area` and any open cascading submenus inside `screen`.
    pub fn render(self: DropdownMenu, ui: *Ui, bar_area: Rect, screen: Rect, state: *const MenuState) !void {
        const bar_bounds = bar_area.intersection(ui.buffer.area);
        if (bar_bounds.isEmpty()) return;

        const base_s = self.style orelse ui.theme.surface;
        const active_s = self.active_style orelse ui.theme.selection;
        ui.buffer.fill(bar_bounds, " ", base_s);

        var x = bar_bounds.left() +| 1;
        const y = bar_bounds.top();
        for (self.groups, 0..) |g, i| {
            if (x >= bar_bounds.right()) break;
            const is_active = if (state.active_group) |ag| ag == i else false;
            const s = if (!g.enabled) ui.theme.disabled else if (is_active) active_s else base_s;
            x = ui.buffer.setStringClipped(x, y, " ", 1, s, bar_bounds).x;
            x = ui.buffer.setStringClipped(x, y, g.label, bar_bounds.right() -| x, s, bar_bounds).x;
            x = ui.buffer.setStringClipped(x, y, " ", bar_bounds.right() -| x, s, bar_bounds).x;
            x +|= self.gap -| 1;
        }

        if (!state.isOpen()) return;
        const g_idx = state.active_group orelse return;
        const screen_bounds = screen.intersection(ui.buffer.area);
        var cur_x = MenuState.groupX(self.groups, g_idx, bar_bounds, self.gap);
        var cur_y = bar_bounds.bottom();

        var l: usize = 0;
        while (l < state.depth) : (l += 1) {
            const items = state.itemsAtLevel(self.groups, l);
            const box = MenuState.dropdownBox(items, cur_x, cur_y, screen_bounds);
            if (box.isEmpty()) break;
            const sel = @min(state.path[l], items.len -| 1);
            try (ContextMenu{
                .items = items,
                .selected = sel,
                .x = box.x,
                .y = box.y,
            }).render(ui, screen_bounds);
            cur_x = if (box.right() + 18 <= screen_bounds.right()) box.right() else box.left() -| 18;
            cur_y = box.top() + 1 + @as(u16, @intCast(sel));
        }
    }
};

/// Horizontal top application menu bar (`File  Edit  View  Help`).
pub const MenuBar = struct {
    items: []const []const u8 = &.{},
    active_index: ?usize = null,
    style: ?Style = null,
    active_style: ?Style = null,
    gap: u16 = 2,

    /// Handles left-click and arrow keys to change active top-level menu entry.
    pub fn handleEvent(self: MenuBar, active_index: *?usize, event: Event, area: Rect) bool {
        if (self.items.len == 0 or area.isEmpty()) return false;
        switch (event) {
            .mouse => |m| {
                if (!m.isLeftClickInside(area) or m.y != area.top()) return false;
                var x = area.left() +| 1;
                for (self.items, 0..) |item, i| {
                    if (x >= area.right()) break;
                    const pill_w = 2 +| text_root.displayWidth(item);
                    const pill_rect = Rect.init(x, area.top(), @min(pill_w, area.right() - x), 1);
                    if (m.isInside(pill_rect)) {
                        active_index.* = i;
                        return true;
                    }
                    x +|= pill_w +| (self.gap -| 1);
                }
                return false;
            },
            .key => |k| {
                if (k.kind == .release) return false;
                if (k.code == .right) {
                    active_index.* = if (active_index.*) |cur| (cur + 1) % self.items.len else 0;
                    return true;
                }
                if (k.code == .left) {
                    active_index.* = if (active_index.*) |cur| (if (cur == 0) self.items.len - 1 else cur - 1) else self.items.len - 1;
                    return true;
                }
                return false;
            },
            else => return false,
        }
    }

    /// Renders single-row horizontal menu bar.
    pub fn render(self: MenuBar, ui: *Ui, area: Rect) void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        const base_s = self.style orelse ui.theme.surface;
        const active_s = self.active_style orelse ui.theme.selection;
        ui.buffer.fill(bounds, " ", base_s);

        var x = bounds.left() +| 1;
        const y = bounds.top();
        for (self.items, 0..) |item, i| {
            if (x >= bounds.right()) break;
            const is_active = if (self.active_index) |ai| ai == i else false;
            const s = if (is_active) active_s else base_s;
            x = ui.buffer.setStringClipped(x, y, " ", 1, s, bounds).x;
            x = ui.buffer.setStringClipped(x, y, item, bounds.right() -| x, s, bounds).x;
            x = ui.buffer.setStringClipped(x, y, " ", bounds.right() -| x, s, bounds).x;
            x +|= self.gap -| 1;
        }
    }
};

/// Outcome from handling `ContextMenu` interaction.
pub const ContextMenuOutcome = enum {
    none,
    moved,
    triggered,
    dismissed,
};

/// Floating context action menu anchored at `(x, y)` inside `screen`.
pub const ContextMenu = struct {
    items: []const MenuItem = &.{},
    selected: usize = 0,
    x: u16 = 0,
    y: u16 = 0,
    title: ?[]const u8 = null,

    /// Computes exact clamped outer `Rect` inside `screen`.
    pub fn popupRect(self: ContextMenu, screen: Rect) Rect {
        if (screen.width < 8 or screen.height < 4 or self.items.len == 0) return Rect.zero;
        var max_w: u16 = 12;
        for (self.items) |it| {
            var w = text_root.displayWidth(it.label);
            if (it.checked != null) w +|= 4;
            if (it.shortcut) |sc| w +|= text_root.displayWidth(sc) + 3;
            if (it.children.len > 0) w +|= 3;
            max_w = @max(max_w, w + 4);
        }
        const box_w = @min(screen.width, max_w);
        const box_h: u16 = @intCast(@min(@as(usize, screen.height), self.items.len + 2));
        const px = @min(self.x, screen.right() - box_w);
        const py = @min(self.y, screen.bottom() - box_h);
        return Rect.init(px, py, box_w, box_h);
    }

    /// Handles Up/Down/Enter/Esc and left clicks / wheel inside `screen`.
    pub fn handleEvent(self: ContextMenu, selected: *usize, event: Event, screen: Rect) ContextMenuOutcome {
        if (self.items.len == 0) return .none;
        const box = self.popupRect(screen);
        const inner = (Block{ .border_type = .rounded }).inner(box);

        switch (event) {
            .mouse => |m| {
                if (m.kind == .down and m.button == .left) {
                    if (!m.isInside(box)) return .dismissed;
                    if (m.isInside(inner)) {
                        const idx = m.y - inner.top();
                        if (idx < self.items.len and !self.items[idx].separator and self.items[idx].enabled) {
                            selected.* = idx;
                            return .triggered;
                        }
                    }
                    return .none;
                }
                if (m.isInside(box) and (m.kind == .scroll_up or m.kind == .scroll_down)) {
                    const dir: isize = if (m.kind == .scroll_down) 1 else -1;
                    var idx = selected.*;
                    for (0..self.items.len) |_| {
                        idx = if (dir > 0) (idx + 1) % self.items.len else (if (idx == 0) self.items.len - 1 else idx - 1);
                        if (!self.items[idx].separator and self.items[idx].enabled) {
                            selected.* = idx;
                            return .moved;
                        }
                    }
                }
                return .none;
            },
            .key => |k| {
                if (k.kind == .release) return .none;
                switch (k.code) {
                    .escape => return .dismissed,
                    .enter => {
                        if (selected.* < self.items.len and !self.items[selected.*].separator and self.items[selected.*].enabled) {
                            return .triggered;
                        }
                        return .none;
                    },
                    .up, .down => {
                        const dir: isize = if (k.code == .down) 1 else -1;
                        var idx = selected.*;
                        for (0..self.items.len) |_| {
                            idx = if (dir > 0) (idx + 1) % self.items.len else (if (idx == 0) self.items.len - 1 else idx - 1);
                            if (!self.items[idx].separator and self.items[idx].enabled) {
                                selected.* = idx;
                                return .moved;
                            }
                        }
                        return .none;
                    },
                    else => return .none,
                }
            },
            else => return .none,
        }
    }

    /// Renders floating action menu clamped safely inside `screen`.
    pub fn render(self: ContextMenu, ui: *Ui, screen: Rect) !void {
        const bounds = screen.intersection(ui.buffer.area);
        const box = self.popupRect(bounds);
        if (box.isEmpty()) return;

        (Clear{ .style = ui.theme.surface }).renderToBuffer(ui.buffer, box);
        const blk = Block{
            .title = self.title,
            .border_type = .rounded,
            .focused = true,
            .style = ui.theme.surface,
            .fill_background = true,
            .shadow = .{ .enabled = true },
        };
        var full_ui = ui.*;
        full_ui.area = bounds;
        try blk.render(&full_ui, box);
        const inner = blk.inner(box);
        if (inner.isEmpty()) return;

        for (self.items, 0..) |it, i| {
            if (i >= inner.height) break;
            const gy = inner.top() + @as(u16, @intCast(i));
            const row_rect = Rect.init(inner.left(), gy, inner.width, 1);

            if (it.separator) {
                var dx = inner.left();
                while (dx < inner.right()) : (dx += 1) {
                    _ = full_ui.buffer.setStringClipped(dx, gy, style_root.symbols.line.normal.horizontal, 1, ui.theme.border, row_rect);
                }
                continue;
            }
            const is_sel = i == self.selected;
            const row_s = if (!it.enabled)
                ui.theme.disabled
            else if (is_sel)
                ui.theme.selection
            else
                ui.theme.text;
            full_ui.buffer.setStyle(row_rect, row_s);
            var lx = inner.left() +| 1;
            if (it.checked) |chk| {
                const mark = if (chk) "[✓] " else "[ ] ";
                lx = full_ui.buffer.setStringClipped(lx, gy, mark, inner.right() -| lx, row_s, row_rect).x;
            }
            _ = full_ui.buffer.setStringClipped(lx, gy, it.label, inner.right() -| lx -| 1, row_s, row_rect);
            if (it.children.len > 0) {
                _ = full_ui.buffer.setStringClipped(inner.right() -| 2, gy, "▸", 1, row_s, row_rect);
            } else if (it.shortcut) |sc| {
                const sw = text_root.displayWidth(sc);
                if (sw + 2 < inner.width) {
                    _ = full_ui.buffer.setStringClipped(inner.right() - sw - 1, gy, sc, sw, if (is_sel) row_s else ui.theme.muted, row_rect);
                }
            }
        }
    }
};

/// Path / navigation breadcrumbs (`Home › Projects › tui.zig`).
pub const Breadcrumbs = struct {
    segments: []const []const u8 = &.{},
    separator: []const u8 = " › ",
    style: ?Style = null,
    active_style: ?Style = null,
    separator_style: ?Style = null,

    pub fn render(self: Breadcrumbs, ui: *Ui, area: Rect) void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty() or self.segments.len == 0) return;

        const base_s = self.style orelse ui.theme.muted;
        const active_s = self.active_style orelse ui.theme.text.patch(.{ .bold = true });
        const sep_s = self.separator_style orelse ui.theme.border;

        var x = bounds.left();
        const y = bounds.top() + bounds.height / 2;
        for (self.segments, 0..) |seg, i| {
            if (x >= bounds.right()) break;
            if (i > 0) {
                x = ui.buffer.setStringClipped(x, y, self.separator, bounds.right() - x, sep_s, bounds).x;
                if (x >= bounds.right()) break;
            }
            const s = if (i + 1 == self.segments.len) active_s else base_s;
            x = ui.buffer.setStringClipped(x, y, seg, bounds.right() - x, s, bounds).x;
        }
    }
};

/// Key-hint or metric badge inside `StatusBar` / `Footer`.
pub const StatusSegment = struct {
    text: []const u8,
    style: ?Style = null,
    badge: bool = false,
};

/// Top application header bar with left title, optional subtitle/breadcrumbs, and right status text.
pub const Header = struct {
    title: []const u8,
    subtitle: ?[]const u8 = null,
    right: ?[]const u8 = null,
    style: ?Style = null,

    pub fn render(self: Header, ui: *Ui, area: Rect) void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        const bg = self.style orelse ui.theme.accent.patch(.{ .reverse = true, .bold = true });
        ui.buffer.fill(bounds, " ", bg);
        const y = bounds.top() + bounds.height / 2;

        var x = ui.buffer.setStringClipped(bounds.left() +| 1, y, self.title, bounds.width -| 2, bg, bounds).x;
        if (self.subtitle) |sub| {
            if (x + 3 < bounds.right()) {
                x = ui.buffer.setStringClipped(x, y, " — ", 3, bg, bounds).x;
                _ = ui.buffer.setStringClipped(x, y, sub, bounds.right() -| x, bg, bounds);
            }
        }
        if (self.right) |rt| {
            const rw = text_root.displayWidth(rt);
            if (rw + 2 <= bounds.width) {
                _ = ui.buffer.setStringClipped(bounds.right() - rw - 1, y, rt, rw, bg, bounds);
            }
        }
    }
};

/// Multi-segment bottom status bar (`StatusBar` / `Footer`).
pub const StatusBar = struct {
    left: []const StatusSegment = &.{},
    right: []const StatusSegment = &.{},
    separator: []const u8 = " │ ",
    style: ?Style = null,

    pub fn render(self: StatusBar, ui: *Ui, area: Rect) void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        const bar_s = self.style orelse ui.theme.surface;
        ui.buffer.fill(bounds, " ", bar_s);
        const y = bounds.top() + bounds.height / 2;

        var lx = bounds.left() +| 1;
        for (self.left, 0..) |seg, i| {
            if (lx >= bounds.right()) break;
            if (i > 0 and !seg.badge) {
                lx = ui.buffer.setStringClipped(lx, y, self.separator, bounds.right() - lx, ui.theme.border, bounds).x;
            } else if (i > 0) {
                lx = ui.buffer.setStringClipped(lx, y, " ", bounds.right() - lx, bar_s, bounds).x;
            }
            const s = seg.style orelse if (seg.badge) ui.theme.accent.patch(.{ .reverse = true, .bold = true }) else ui.theme.text;
            if (seg.badge and lx < bounds.right()) lx = ui.buffer.setStringClipped(lx, y, " ", 1, s, bounds).x;
            if (lx < bounds.right()) lx = ui.buffer.setStringClipped(lx, y, seg.text, bounds.right() - lx, s, bounds).x;
            if (seg.badge and lx < bounds.right()) lx = ui.buffer.setStringClipped(lx, y, " ", 1, s, bounds).x;
        }

        // Measure total right segment width so items align flush right.
        var total_rw: u16 = 0;
        const sep_w = text_root.displayWidth(self.separator);
        for (self.right, 0..) |seg, i| {
            if (i > 0) total_rw +|= if (seg.badge) 1 else sep_w;
            total_rw +|= text_root.displayWidth(seg.text) + if (seg.badge) @as(u16, 2) else 0;
        }
        var rx = bounds.right() -| (total_rw +| 1);
        if (rx <= lx) rx = lx +| 1;

        for (self.right, 0..) |seg, i| {
            if (rx >= bounds.right()) break;
            if (i > 0 and !seg.badge) {
                rx = ui.buffer.setStringClipped(rx, y, self.separator, bounds.right() - rx, ui.theme.border, bounds).x;
            } else if (i > 0) {
                rx = ui.buffer.setStringClipped(rx, y, " ", bounds.right() - rx, bar_s, bounds).x;
            }
            const s = seg.style orelse if (seg.badge) ui.theme.secondary.patch(.{ .reverse = true }) else ui.theme.muted;
            if (seg.badge and rx < bounds.right()) rx = ui.buffer.setStringClipped(rx, y, " ", 1, s, bounds).x;
            if (rx < bounds.right()) rx = ui.buffer.setStringClipped(rx, y, seg.text, bounds.right() - rx, s, bounds).x;
            if (seg.badge and rx < bounds.right()) rx = ui.buffer.setStringClipped(rx, y, " ", 1, s, bounds).x;
        }
    }
};

/// Scroll state paired with `ScrollView`.
pub const ScrollViewState = struct {
    offset_y: usize = 0,
    content_height: usize = 0,

    pub fn scrollBy(self: *ScrollViewState, delta: isize, viewport_height: u16) void {
        const max_off = self.content_height -| viewport_height;
        if (delta < 0) {
            self.offset_y -|= @intCast(-delta);
        } else {
            self.offset_y = @min(max_off, self.offset_y +| @as(usize, @intCast(delta)));
        }
    }
};

/// Bordered scrollable container combining a vertical viewport + proportional `Scrollbar`.
pub const ScrollView = struct {
    block: ?Block = .{ .border_type = .rounded },
    show_scrollbar: bool = true,
    content_height: usize = 0,

    /// Renders bordered outer frame + proportional scrollbar and passes interior `*Ui` + `state.offset_y` to `draw_fn`.
    pub fn renderWith(
        self: ScrollView,
        ui: *Ui,
        area: Rect,
        state: *ScrollViewState,
        ctx: anytype,
        comptime draw_fn: anytype,
    ) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        state.content_height = @max(state.content_height, self.content_height);
        const max_off = state.content_height -| inner.height;
        if (state.offset_y > max_off) state.offset_y = max_off;

        const need_bar = self.show_scrollbar and inner.width >= 4 and state.content_height > inner.height;
        const body_rect = if (need_bar)
            Rect.init(inner.left(), inner.top(), inner.width - 1, inner.height)
        else
            inner;

        var inner_ui = ui.region(body_rect);
        const ret_err = @typeInfo(@typeInfo(@TypeOf(draw_fn)).@"fn".return_type.?) == .error_union;
        if (ret_err) {
            try draw_fn(ctx, &inner_ui, state.offset_y);
        } else {
            draw_fn(ctx, &inner_ui, state.offset_y);
        }

        if (need_bar) {
            var sb_state = ScrollbarState{
                .content_length = state.content_height,
                .viewport_content_length = inner.height,
                .position = state.offset_y,
            };
            const bar_rect = Rect.init(inner.right() - 1, inner.top(), 1, inner.height);
            try (Scrollbar{ .orientation = .vertical_right }).renderStateful(ui, bar_rect, &sb_state);
        }
    }
};

/// Two-pane adjustable split container with optional divider line.
pub const SplitPane = struct {
    direction: Direction = .horizontal,
    ratio_percent: u16 = 50,
    min_first: u16 = 5,
    show_divider: bool = true,
    focused_pane: u8 = 0,

    const SplitMetrics = struct {
        total: u16,
        div_size: u16,
        usable: u16,
        first_len: u16,
    };

    fn metrics(self: SplitPane, bounds: Rect) SplitMetrics {
        const clamped_pct = std.math.clamp(self.ratio_percent, 5, 95);
        const total = if (self.direction == .horizontal) bounds.width else bounds.height;
        const div_size: u16 = if (self.show_divider and total >= 3) 1 else 0;
        const usable = total -| div_size;
        const first_len = @min(usable, @max(@min(usable, self.min_first), @as(u16, @intCast((@as(u32, usable) * clamped_pct) / 100))));
        return .{ .total = total, .div_size = div_size, .usable = usable, .first_len = first_len };
    }

    /// Adjusts `ratio_percent` when left mouse clicks/drags near the divider or along split bounds.
    pub fn handleEvent(self: *SplitPane, event: Event, area: Rect) bool {
        if (event != .mouse) return false;
        const m = event.mouse;
        if (!m.isInside(area)) return false;
        if ((m.kind != .drag and m.kind != .down) or m.button != .left) return false;

        const met = self.metrics(area);
        if (met.usable == 0) return false;
        const div_pos: u16 = if (self.direction == .horizontal) area.left() + met.first_len else area.top() + met.first_len;
        const mouse_pos: u16 = if (self.direction == .horizontal) m.x else m.y;

        if (m.kind == .down and (mouse_pos + 1 < div_pos or mouse_pos > div_pos + 1)) {
            return false;
        }
        const origin: u16 = if (self.direction == .horizontal) area.left() else area.top();
        const rel = mouse_pos -| origin;
        const pct = std.math.clamp(@as(u16, @intCast((@as(u32, rel) * 100) / met.usable)), 5, 95);
        if (pct == self.ratio_percent) return false;
        self.ratio_percent = pct;
        return true;
    }

    /// Splits `area` into two child `Ui` viewports (`left_or_top`, `right_or_bottom`), rendering an optional divider.
    pub fn split(self: SplitPane, ui: *Ui, area: Rect) ![2]Ui {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return .{ ui.region(Rect.zero), ui.region(Rect.zero) };

        const met = self.metrics(bounds);
        const div_size = met.div_size;
        const first_len = met.first_len;
        const second_len = met.usable -| first_len;

        if (self.direction == .horizontal) {
            const first = Rect.init(bounds.left(), bounds.top(), first_len, bounds.height);
            const second = Rect.init(bounds.left() + first_len + div_size, bounds.top(), second_len, bounds.height);
            if (div_size == 1) {
                const dx = bounds.left() + first_len;
                var y = bounds.top();
                while (y < bounds.bottom()) : (y += 1) {
                    _ = ui.buffer.setStringClipped(dx, y, style_root.symbols.line.normal.vertical, 1, ui.theme.border, bounds);
                }
            }
            return .{ ui.region(first), ui.region(second) };
        } else {
            const first = Rect.init(bounds.left(), bounds.top(), bounds.width, first_len);
            const second = Rect.init(bounds.left(), bounds.top() + first_len + div_size, bounds.width, second_len);
            if (div_size == 1) {
                const dy = bounds.top() + first_len;
                var x = bounds.left();
                while (x < bounds.right()) : (x += 1) {
                    _ = ui.buffer.setStringClipped(x, dy, style_root.symbols.line.normal.horizontal, 1, ui.theme.border, bounds);
                }
            }
            return .{ ui.region(first), ui.region(second) };
        }
    }
};

/// Ring coordinator for Tab / BackTab focus cycling across `count` interactive widgets.
pub const FocusGroup = struct {
    count: usize,
    active: usize = 0,
    wrap: bool = true,

    pub fn isFocused(self: FocusGroup, index: usize) bool {
        return self.count > 0 and self.active == index;
    }

    pub fn next(self: *FocusGroup) void {
        if (self.count == 0) return;
        if (self.active + 1 < self.count) {
            self.active += 1;
        } else if (self.wrap) {
            self.active = 0;
        }
    }

    pub fn prev(self: *FocusGroup) void {
        if (self.count == 0) return;
        if (self.active > 0) {
            self.active -= 1;
        } else if (self.wrap) {
            self.active = self.count - 1;
        }
    }

    /// Processes `Tab` / `BackTab` keys; returns `true` when focus moved.
    pub fn handleEvent(self: *FocusGroup, event: Event) bool {
        if (event != .key or event.key.kind == .release) return false;
        switch (event.key.code) {
            .tab => {
                if (event.key.modifiers.shift) self.prev() else self.next();
                return true;
            },
            .back_tab => {
                self.prev();
                return true;
            },
            else => return false,
        }
    }
};

/// Top application navigation bar supporting brand label, clickable links, right badge text,
/// and symmetrical LTR/RTL horizontal mirroring.
pub const Navbar = struct {
    brand: []const u8 = "",
    items: []const []const u8 = &.{},
    active: usize = 0,
    right_text: ?[]const u8 = null,
    direction: TextDirection = .ltr,
    gap: u16 = 2,
    style: ?Style = null,
    active_style: ?Style = null,
    brand_style: ?Style = null,

    fn navPillRects(self: Navbar, bounds: Rect, out_rects: []Rect) void {
        const len = @min(self.items.len, out_rects.len);
        const y = bounds.top() + bounds.height / 2;
        const brand_w = text_root.displayWidth(self.brand);
        if (self.direction == .rtl) {
            var x = bounds.right() -| 1;
            if (brand_w > 0) {
                x -|= brand_w +| 2;
            }
            for (self.items[0..len], 0..) |item, i| {
                const pw = text_root.displayWidth(item) +| 2;
                if (x <= bounds.left() + 1) {
                    out_rects[i] = Rect.zero;
                    continue;
                }
                const start_x = if (x > pw) @max(bounds.left(), x - pw) else bounds.left();
                const w = x - start_x;
                out_rects[i] = Rect.init(start_x, y, w, 1);
                x = start_x -| @max(@as(u16, 1), self.gap -| 1);
            }
        } else {
            var x = bounds.left() +| 1;
            if (brand_w > 0) {
                x +|= brand_w +| 3;
            }
            for (self.items[0..len], 0..) |item, i| {
                if (x >= bounds.right()) {
                    out_rects[i] = Rect.zero;
                    continue;
                }
                const pw = text_root.displayWidth(item) +| 2;
                const w = @min(pw, bounds.right() - x);
                out_rects[i] = Rect.init(x, y, w, 1);
                x +|= pw +| @max(@as(u16, 1), self.gap -| 1);
            }
        }
    }

    /// Processes left mouse clicks and arrow keys on navigation items; returns `true` when `active` changes.
    pub fn handleEvent(self: Navbar, active: *usize, event: Event, area: Rect) bool {
        if (self.items.len == 0 or area.isEmpty()) return false;
        switch (event) {
            .mouse => |m| {
                if (!m.isLeftClickInside(area)) return false;
                var rects: [32]Rect = @splat(Rect.zero);
                const count = @min(self.items.len, rects.len);
                self.navPillRects(area, rects[0..count]);
                for (rects[0..count], 0..) |r, i| {
                    if (!r.isEmpty() and m.isInside(r)) {
                        if (active.* != i) {
                            active.* = i;
                            return true;
                        }
                        return true;
                    }
                }
                return false;
            },
            .key => |k| {
                if (k.kind == .release) return false;
                if (k.code == .right) {
                    active.* = if (self.direction == .rtl)
                        (if (active.* == 0) self.items.len - 1 else active.* - 1)
                    else
                        (active.* + 1) % self.items.len;
                    return true;
                }
                if (k.code == .left) {
                    active.* = if (self.direction == .rtl)
                        (active.* + 1) % self.items.len
                    else
                        (if (active.* == 0) self.items.len - 1 else active.* - 1);
                    return true;
                }
                return false;
            },
            else => return false,
        }
    }

    pub fn render(self: Navbar, ui: *Ui, area: Rect) void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        const base_s = self.style orelse ui.theme.surface;
        const active_s = self.active_style orelse ui.theme.accent.patch(.{ .reverse = true, .bold = true });
        const brand_s = self.brand_style orelse ui.theme.accent.patch(.{ .bold = true });
        ui.buffer.fill(bounds, " ", base_s);

        const y = bounds.top() + bounds.height / 2;
        var rtl_buf: [256]u8 = undefined;

        if (self.brand.len > 0) {
            const vis_brand = text_root.visualOrderInto(self.brand, self.direction, &rtl_buf);
            const bw = text_root.displayWidth(vis_brand);
            if (self.direction == .rtl) {
                const bx = bounds.right() -| (bw +| 1);
                _ = ui.buffer.setStringClipped(bx, y, vis_brand, bounds.right() -| bx, brand_s, bounds);
            } else {
                _ = ui.buffer.setStringClipped(bounds.left() +| 1, y, vis_brand, bounds.width -| 2, brand_s, bounds);
            }
        }

        var rects: [32]Rect = @splat(Rect.zero);
        const count = @min(self.items.len, rects.len);
        self.navPillRects(bounds, rects[0..count]);
        for (self.items[0..count], 0..) |item, i| {
            const r = rects[i];
            if (r.isEmpty()) continue;
            const s = if (i == self.active) active_s else base_s;
            ui.buffer.fill(r, " ", s);
            const vis_item = text_root.visualOrderInto(item, self.direction, &rtl_buf);
            _ = ui.buffer.setStringClipped(r.left() +| 1, r.top(), vis_item, r.width -| 2, s, bounds);
        }

        if (self.right_text) |rt| {
            const vis_rt = text_root.visualOrderInto(rt, self.direction, &rtl_buf);
            const rw = text_root.displayWidth(vis_rt);
            if (self.direction == .rtl) {
                _ = ui.buffer.setStringClipped(bounds.left() +| 1, y, vis_rt, @min(rw, bounds.width / 3), ui.theme.muted, bounds);
            } else {
                const rx = bounds.right() -| (rw +| 1);
                _ = ui.buffer.setStringClipped(rx, y, vis_rt, bounds.right() -| rx, ui.theme.muted, bounds);
            }
        }
    }
};

/// Placement side for `Sidebar` dock.
pub const SidebarSide = enum {
    left,
    right,
    /// Automatically docks `.right` in RTL mode and `.left` in LTR mode.
    auto,
};

/// Single navigation destination entry inside `Sidebar`.
pub const SidebarItem = struct {
    label: []const u8,
    icon: ?[]const u8 = null,
    badge: ?[]const u8 = null,
    disabled: bool = false,
};

/// Collapsible dockable application sidebar supporting left (LTR) and right (RTL) docking.
pub const Sidebar = struct {
    items: []const SidebarItem = &.{},
    selected: usize = 0,
    title: ?[]const u8 = null,
    footer: ?[]const u8 = null,
    side: SidebarSide = .auto,
    direction: TextDirection = .ltr,
    width: u16 = 24,
    collapsed: bool = false,
    collapsed_width: u16 = 6,
    focused: bool = false,
    border_type: BorderType = .rounded,

    /// Resolves concrete dock side (`.left` or `.right`) honoring `.auto` + `direction`.
    pub fn resolvedSide(self: Sidebar) enum { left, right } {
        return switch (self.side) {
            .left => .left,
            .right => .right,
            .auto => if (self.direction == .rtl) .right else .left,
        };
    }

    /// Computes sidebar width bounded cleanly to `container_width`.
    pub fn effectiveWidth(self: Sidebar, container_width: u16) u16 {
        if (container_width == 0) return 0;
        const req = if (self.collapsed) self.collapsed_width else self.width;
        return @min(container_width, req);
    }

    /// Splits `container` into docked `sidebar` and remaining `content` rectangles.
    pub fn splitLayout(self: Sidebar, container: Rect) struct { sidebar: Rect, content: Rect } {
        const w = self.effectiveWidth(container.width);
        if (self.resolvedSide() == .right) {
            const cw = container.width -| w;
            return .{
                .content = Rect.init(container.left(), container.top(), cw, container.height),
                .sidebar = Rect.init(container.left() + cw, container.top(), w, container.height),
            };
        }
        return .{
            .sidebar = Rect.init(container.left(), container.top(), w, container.height),
            .content = Rect.init(container.left() + w, container.top(), container.width -| w, container.height),
        };
    }

    fn moveNextEnabled(self: Sidebar, selected: *usize, dir: isize) bool {
        if (self.items.len == 0) return false;
        var idx = @min(selected.*, self.items.len - 1);
        for (0..self.items.len) |_| {
            idx = if (dir > 0)
                (idx + 1) % self.items.len
            else if (idx == 0)
                self.items.len - 1
            else
                idx - 1;
            if (!self.items[idx].disabled) {
                selected.* = idx;
                return true;
            }
        }
        return false;
    }

    /// Handles mouse click selection, scroll wheel, and Up/Down/j/k navigation.
    pub fn handleEvent(self: Sidebar, selected: *usize, event: Event, area: Rect, focused: bool) bool {
        if (self.items.len == 0 or area.isEmpty()) return false;
        const inner = (Block{ .border_type = self.border_type }).inner(area);
        switch (event) {
            .mouse => |m| {
                if (!m.isInside(inner)) return false;
                if (m.kind == .down and m.button == .left) {
                    const row = m.y - inner.top();
                    if (row < self.items.len and !self.items[row].disabled) {
                        selected.* = row;
                        return true;
                    }
                    return false;
                }
                if (m.kind == .scroll_down) return self.moveNextEnabled(selected, 1);
                if (m.kind == .scroll_up) return self.moveNextEnabled(selected, -1);
                return false;
            },
            .key => |k| {
                if (!focused or k.kind == .release) return false;
                return switch (k.code) {
                    .down => self.moveNextEnabled(selected, 1),
                    .up => self.moveNextEnabled(selected, -1),
                    .char => |cp| if (cp == 'j') self.moveNextEnabled(selected, 1) else if (cp == 'k') self.moveNextEnabled(selected, -1) else false,
                    else => false,
                };
            },
            else => return false,
        }
    }

    pub fn render(self: Sidebar, ui: *Ui, area: Rect) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        const is_rtl = self.direction == .rtl;
        const title_align: Alignment = if (is_rtl) .right else .left;
        const blk = Block{
            .title = if (self.collapsed) null else self.title,
            .title_alignment = title_align,
            .border_type = self.border_type,
            .focused = self.focused,
            .fill_background = true,
            .style = ui.theme.surface,
        };
        try blk.render(ui, bounds);
        const inner = blk.inner(bounds);
        if (inner.isEmpty()) return;

        const footer_rows: u16 = if (self.footer != null and !self.collapsed and inner.height >= 4) 1 else 0;
        const item_rows = inner.height -| footer_rows;
        var rtl_buf: [256]u8 = undefined;

        for (self.items, 0..) |it, i| {
            if (i >= item_rows) break;
            const gy = inner.top() + @as(u16, @intCast(i));
            const row_rect = Rect.init(inner.left(), gy, inner.width, 1);
            const is_sel = i == self.selected;

            const row_s = if (it.disabled)
                ui.theme.disabled
            else if (is_sel)
                (if (self.focused) ui.theme.selection else ui.theme.accent.patch(.{ .reverse = true, .bold = true }))
            else
                ui.theme.text;

            ui.buffer.fill(row_rect, " ", row_s);

            if (self.collapsed or inner.width <= 5) {
                const glyph = it.icon orelse blk_g: {
                    var git = text_root.GraphemeIterator.init(it.label);
                    break :blk_g if (git.next()) |g| g.slice else "•";
                };
                const gw = text_root.displayWidth(glyph);
                const cx = inner.left() + (inner.width -| gw) / 2;
                _ = ui.buffer.setStringClipped(cx, gy, glyph, inner.right() -| cx, row_s, row_rect);
                continue;
            }

            const marker = if (is_sel) (if (is_rtl) " ◀" else "▶ ") else "  ";
            const vis_label = text_root.visualOrderInto(it.label, self.direction, &rtl_buf);

            if (is_rtl) {
                var rx = inner.right();
                const mw = text_root.displayWidth(marker);
                rx -|= mw;
                _ = ui.buffer.setStringClipped(rx, gy, marker, mw, if (is_sel) row_s else ui.theme.accent, row_rect);

                if (it.icon) |ic| {
                    const iw = text_root.displayWidth(ic);
                    if (rx > inner.left() + iw + 1) {
                        rx -|= iw + 1;
                        _ = ui.buffer.setStringClipped(rx, gy, ic, iw, row_s, row_rect);
                    }
                }
                const lw = text_root.displayWidth(vis_label);
                const badge_space: u16 = if (it.badge) |bg| text_root.displayWidth(bg) + 1 else 0;
                const avail_lw = (rx -| inner.left()) -| badge_space;
                const draw_lw = @min(lw, avail_lw);
                _ = ui.buffer.setStringClipped(rx -| draw_lw, gy, vis_label, draw_lw, row_s, row_rect);

                if (it.badge) |bg| {
                    const bg_w = text_root.displayWidth(bg);
                    if (inner.left() + bg_w < rx -| draw_lw) {
                        _ = ui.buffer.setStringClipped(inner.left(), gy, bg, bg_w, if (is_sel) row_s else ui.theme.muted, row_rect);
                    }
                }
            } else {
                var lx = ui.buffer.setStringClipped(inner.left(), gy, marker, inner.width, if (is_sel) row_s else ui.theme.accent, row_rect).x;
                if (it.icon) |ic| {
                    lx = ui.buffer.setStringClipped(lx, gy, ic, inner.right() -| lx, row_s, row_rect).x;
                    lx = ui.buffer.setStringClipped(lx, gy, " ", inner.right() -| lx, row_s, row_rect).x;
                }
                const badge_w: u16 = if (it.badge) |bg| text_root.displayWidth(bg) + 1 else 0;
                const max_lw = (inner.right() -| lx) -| badge_w;
                _ = ui.buffer.setStringClipped(lx, gy, vis_label, max_lw, row_s, row_rect);
                if (it.badge) |bg| {
                    const bg_w = text_root.displayWidth(bg);
                    if (inner.right() > bg_w and inner.right() - bg_w >= lx + 1) {
                        _ = ui.buffer.setStringClipped(inner.right() - bg_w, gy, bg, bg_w, if (is_sel) row_s else ui.theme.muted, row_rect);
                    }
                }
            }
        }

        if (footer_rows > 0) {
            if (self.footer) |ft| {
                const vis_ft = text_root.visualOrderInto(ft, self.direction, &rtl_buf);
                const fw = text_root.displayWidth(vis_ft);
                const fx = if (is_rtl) inner.right() -| @min(fw, inner.width) else inner.left();
                _ = ui.buffer.setStringClipped(fx, inner.bottom() - 1, vis_ft, inner.width, ui.theme.muted, inner);
            }
        }
    }
};

test "header, breadcrumbs, status bar, split pane, and focus group work cohesively" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 48, 8));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    try ui.renderWidget(Header{ .title = "tui.zig", .subtitle = "Inspector", .right = "v0.1.0" }, Rect.init(0, 0, 48, 1));
    try ui.renderWidget(Breadcrumbs{ .segments = &.{ "Home", "Widgets", "Table" } }, Rect.init(0, 1, 48, 1));
    try ui.renderWidget(StatusBar{
        .left = &.{ .{ .text = "NORMAL", .badge = true }, .{ .text = "3 widgets" } },
        .right = &.{.{ .text = "q Quit" }},
    }, Rect.init(0, 7, 48, 1));

    const panes = try (SplitPane{ .ratio_percent = 50 }).split(&ui, Rect.init(0, 2, 48, 5));
    try testing.expect(panes[0].area.width > 0);
    try testing.expect(panes[1].area.width > 0);

    var fg = FocusGroup{ .count = 3 };
    try testing.expect(fg.handleEvent(.{ .key = .{ .code = .tab } }));
    try testing.expect(fg.isFocused(1));

    var sp = SplitPane{ .ratio_percent = 50 };
    try testing.expect(sp.handleEvent(.{ .mouse = .{ .kind = .drag, .button = .left, .x = 30, .y = 3 } }, Rect.init(0, 2, 48, 5)));
    try testing.expect(sp.ratio_percent > 55);

    var menu_idx: ?usize = 0;
    const mbar = MenuBar{ .items = &.{ "File", "Edit" } };
    try testing.expect(mbar.handleEvent(&menu_idx, .{ .mouse = .{ .kind = .down, .button = .left, .x = 9, .y = 0 } }, Rect.init(0, 0, 48, 1)));
    try testing.expectEqual(@as(?usize, 1), menu_idx);

    var cm_sel: usize = 0;
    const cmenu = ContextMenu{ .items = &.{ .{ .label = "New" }, .{ .label = "Open" } }, .x = 0, .y = 1 };
    const cm_res = cmenu.handleEvent(&cm_sel, .{ .mouse = .{ .kind = .down, .button = .left, .x = 2, .y = 3 } }, buf.area);
    try testing.expectEqual(ContextMenuOutcome.triggered, cm_res);
    try testing.expectEqual(@as(usize, 1), cm_sel);

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "tui.zig") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "Widgets") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "NORMAL") != null);
}

test "sidebar docks left/right (LTR/RTL) and navbar clicks select active routes" {
    const alloc = testing.allocator;
    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 64, 10));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    var nav_idx: usize = 0;
    const nav = Navbar{ .brand = "App", .items = &.{ "Home", "Logs" }, .direction = .ltr };
    try testing.expect(nav.handleEvent(&nav_idx, .{ .key = .{ .code = .right } }, Rect.init(0, 0, 64, 1)));
    try testing.expectEqual(@as(usize, 1), nav_idx);
    nav.render(&ui, Rect.init(0, 0, 64, 1));

    var sb_idx: usize = 0;
    const sb_rtl = Sidebar{
        .title = "القائمة",
        .items = &.{ .{ .label = "Overview", .icon = "•" }, .{ .label = "Metrics", .icon = "★" } },
        .side = .auto,
        .direction = .rtl,
        .width = 20,
    };
    const split = sb_rtl.splitLayout(Rect.init(0, 1, 64, 8));
    try testing.expectEqual(@as(u16, 44), split.sidebar.x);
    try testing.expectEqual(@as(u16, 0), split.content.x);
    try testing.expect(sb_rtl.handleEvent(&sb_idx, .{ .mouse = .{ .kind = .down, .button = .left, .x = 48, .y = 3 } }, split.sidebar, true));
    try testing.expectEqual(@as(usize, 1), sb_idx);
    try sb_rtl.render(&ui, split.sidebar);

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "App") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "Metrics") != null);
}
