//! Hierarchical `Tree`, `TreeNode`, and `TreeState` with expand/collapse and keyboard navigation.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const text_root = @import("../text/root.zig");
const event_root = @import("../event/root.zig");
const block_mod = @import("block.zig");
const testing = std.testing;

pub const Rect = core_root.Rect;
pub const Ui = core_root.Ui;
pub const Style = style_root.Style;
pub const TreeSet = style_root.TreeSet;
pub const symbols = style_root.symbols;
pub const Block = block_mod.Block;
pub const Event = event_root.Event;

/// Hierarchical node borrowed by `Tree`. Immutable data; expansion state lives in `TreeState`.
pub const TreeNode = struct {
    label: []const u8,
    children: []const TreeNode = &.{},
    style: ?Style = null,
    badge: ?[]const u8 = null,

    pub fn leaf(label: []const u8) TreeNode {
        return .{ .label = label };
    }

    pub fn branch(label: []const u8, children: []const TreeNode) TreeNode {
        return .{ .label = label, .children = children };
    }
};

/// Allocator-backed expansion, selection, and scroll state for `Tree`.
pub const TreeState = struct {
    allocator: std.mem.Allocator,
    expanded: std.AutoHashMapUnmanaged(u64, void) = .empty,
    selected: ?usize = 0,
    offset: usize = 0,

    pub fn init(allocator: std.mem.Allocator) TreeState {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *TreeState) void {
        self.expanded.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn isExpanded(self: *const TreeState, path_hash: u64) bool {
        return self.expanded.contains(path_hash);
    }

    pub fn setExpanded(self: *TreeState, path_hash: u64, open: bool) !void {
        if (open) {
            try self.expanded.put(self.allocator, path_hash, {});
        } else {
            _ = self.expanded.remove(path_hash);
        }
    }

    pub fn toggle(self: *TreeState, path_hash: u64) !bool {
        if (self.expanded.remove(path_hash)) return false;
        try self.expanded.put(self.allocator, path_hash, {});
        return true;
    }

    /// Recursively expands all branch nodes under `roots`.
    pub fn expandAll(self: *TreeState, roots: []const TreeNode) !void {
        try self.expandList(roots, 0xcbf29ce484222325);
    }

    /// Collapses every expanded node.
    pub fn collapseAll(self: *TreeState) void {
        self.expanded.clearRetainingCapacity();
        self.offset = 0;
        self.selected = 0;
    }

    /// Counts currently visible rows based on expanded nodes.
    pub fn visibleCount(self: *const TreeState, roots: []const TreeNode) usize {
        var count: usize = 0;
        self.countRec(roots, 0xcbf29ce484222325, &count);
        return count;
    }

    /// Processes Up/Down/Left/Right/Enter/Space/click events on the tree.
    pub fn handleEvent(
        self: *TreeState,
        event: Event,
        roots: []const TreeNode,
        bounds: Rect,
        focused: bool,
    ) !bool {
        const total = self.visibleCount(roots);
        if (total == 0) return false;

        switch (event) {
            .mouse => |m| {
                if (!m.isInside(bounds)) return false;
                if (m.kind == .down and m.button == .left) {
                    const row = self.offset + (m.y - bounds.top());
                    if (row < total) {
                        const already = self.selected != null and self.selected.? == row;
                        self.selected = row;
                        if (already) {
                            if (self.findRowMeta(roots, row)) |meta| {
                                if (meta.has_children) _ = try self.toggle(meta.hash);
                            }
                        }
                        return true;
                    }
                } else if (m.kind == .scroll_up) {
                    self.selected = if (self.selected) |s| (s -| 1) else 0;
                    return true;
                } else if (m.kind == .scroll_down) {
                    self.selected = if (self.selected) |s| @min(total - 1, s + 1) else 0;
                    return true;
                }
                return false;
            },
            .key => |k| {
                if (!focused or k.kind == .release) return false;
                switch (k.code) {
                    .down => {
                        self.selected = if (self.selected) |s| (s + 1) % total else 0;
                        return true;
                    },
                    .up => {
                        self.selected = if (self.selected) |s| (if (s == 0) total - 1 else s - 1) else total - 1;
                        return true;
                    },
                    .home => {
                        self.selected = 0;
                        return true;
                    },
                    .end => {
                        self.selected = total - 1;
                        return true;
                    },
                    .page_up => {
                        const step = @max(@as(usize, 1), bounds.height);
                        self.selected = if (self.selected) |s| (s -| step) else 0;
                        return true;
                    },
                    .page_down => {
                        const step = @max(@as(usize, 1), bounds.height);
                        self.selected = if (self.selected) |s| @min(total - 1, s + step) else 0;
                        return true;
                    },
                    .enter => {
                        if (self.selected) |row| {
                            if (self.findRowMeta(roots, row)) |meta| {
                                if (meta.has_children) {
                                    _ = try self.toggle(meta.hash);
                                    return true;
                                }
                            }
                        }
                        return false;
                    },
                    .right => {
                        if (self.selected) |row| {
                            if (self.findRowMeta(roots, row)) |meta| {
                                if (meta.has_children and !self.isExpanded(meta.hash)) {
                                    try self.setExpanded(meta.hash, true);
                                    return true;
                                }
                            }
                        }
                        return false;
                    },
                    .left => {
                        if (self.selected) |row| {
                            if (self.findRowMeta(roots, row)) |meta| {
                                if (meta.has_children and self.isExpanded(meta.hash)) {
                                    try self.setExpanded(meta.hash, false);
                                    return true;
                                }
                                if (meta.parent_row) |pr| {
                                    self.selected = pr;
                                    return true;
                                }
                            }
                        }
                        return false;
                    },
                    .char => |cp| {
                        if (cp == ' ') {
                            if (self.selected) |row| {
                                if (self.findRowMeta(roots, row)) |meta| {
                                    if (meta.has_children) {
                                        _ = try self.toggle(meta.hash);
                                        return true;
                                    }
                                }
                            }
                        } else if (cp == 'j') {
                            self.selected = if (self.selected) |s| (s + 1) % total else 0;
                            return true;
                        } else if (cp == 'k') {
                            self.selected = if (self.selected) |s| (if (s == 0) total - 1 else s - 1) else total - 1;
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

    const RowMeta = struct {
        hash: u64,
        has_children: bool,
        parent_row: ?usize,
    };

    fn findRowMeta(self: *const TreeState, roots: []const TreeNode, target: usize) ?RowMeta {
        var idx: usize = 0;
        return self.findRowRec(roots, 0xcbf29ce484222325, null, target, &idx);
    }

    fn findRowRec(
        self: *const TreeState,
        nodes: []const TreeNode,
        parent_hash: u64,
        parent_row: ?usize,
        target: usize,
        idx: *usize,
    ) ?RowMeta {
        for (nodes, 0..) |node, i| {
            const h = hashNodePath(parent_hash, i, node.label);
            const cur_row = idx.*;
            idx.* += 1;
            if (cur_row == target) {
                return .{
                    .hash = h,
                    .has_children = node.children.len > 0,
                    .parent_row = parent_row,
                };
            }
            if (node.children.len > 0 and self.isExpanded(h)) {
                if (self.findRowRec(node.children, h, cur_row, target, idx)) |found| return found;
            }
        }
        return null;
    }

    fn expandList(self: *TreeState, nodes: []const TreeNode, parent_hash: u64) !void {
        for (nodes, 0..) |node, i| {
            const h = hashNodePath(parent_hash, i, node.label);
            if (node.children.len > 0) {
                try self.expanded.put(self.allocator, h, {});
                try self.expandList(node.children, h);
            }
        }
    }

    fn countRec(self: *const TreeState, nodes: []const TreeNode, parent_hash: u64, count: *usize) void {
        for (nodes, 0..) |node, i| {
            const h = hashNodePath(parent_hash, i, node.label);
            count.* += 1;
            if (node.children.len > 0 and self.isExpanded(h)) {
                self.countRec(node.children, h, count);
            }
        }
    }
};

fn hashNodePath(parent_hash: u64, index: usize, label: []const u8) u64 {
    var h = std.hash.Fnv1a_64.init();
    h.update(std.mem.asBytes(&parent_hash));
    h.update(std.mem.asBytes(&index));
    h.update(label);
    return h.final();
}

/// Interactive collapsible tree view widget.
pub const Tree = struct {
    roots: []const TreeNode = &.{},
    block: ?Block = null,
    symbols_set: TreeSet = symbols.tree.unicode,
    style: ?Style = null,
    highlight_style: ?Style = null,
    guide_style: ?Style = null,
    focused: bool = true,

    /// Renders tree rows inside `area` synchronized with `state`.
    pub fn renderStateful(self: Tree, ui: *Ui, area: Rect, state: *TreeState) !void {
        const bounds = area.intersection(ui.buffer.area);
        if (bounds.isEmpty()) return;

        var inner = bounds;
        if (self.block) |b| {
            try b.render(ui, bounds);
            inner = b.inner(bounds);
        }
        if (inner.isEmpty()) return;

        const total = state.visibleCount(self.roots);
        if (total == 0) {
            state.selected = null;
            state.offset = 0;
            return;
        }
        if (state.selected) |sel| {
            if (sel >= total) state.selected = total - 1;
            if (sel < state.offset) {
                state.offset = sel;
            } else if (sel >= state.offset + inner.height) {
                state.offset = sel - inner.height + 1;
            }
        }

        const base_style = self.style orelse ui.theme.text;
        const g_style = self.guide_style orelse ui.theme.muted;
        const hl_style = self.highlight_style orelse if (self.focused) ui.theme.selection else ui.theme.muted.patch(.{ .reverse = true });

        var row_idx: usize = 0;
        var has_more_ancestors: [32]bool = @splat(false);
        self.renderRec(
            ui,
            inner,
            self.roots,
            0xcbf29ce484222325,
            0,
            &has_more_ancestors,
            state,
            &row_idx,
            base_style,
            g_style,
            hl_style,
        );
    }

    fn renderRec(
        self: Tree,
        ui: *Ui,
        inner: Rect,
        nodes: []const TreeNode,
        parent_hash: u64,
        depth: usize,
        has_more: *[32]bool,
        state: *const TreeState,
        row_idx: *usize,
        base_style: Style,
        g_style: Style,
        hl_style: Style,
    ) void {
        for (nodes, 0..) |node, i| {
            if (row_idx.* >= state.offset + inner.height) return;

            const h = hashNodePath(parent_hash, i, node.label);
            const is_last = i + 1 == nodes.len;
            const cur_row = row_idx.*;
            row_idx.* += 1;

            if (cur_row >= state.offset) {
                const screen_y = inner.top() + @as(u16, @intCast(cur_row - state.offset));
                const is_sel = if (state.selected) |s| s == cur_row else false;
                const row_style = if (is_sel)
                    hl_style
                else if (node.style) |ns|
                    base_style.patch(ns)
                else
                    base_style;

                ui.buffer.setStyle(Rect.init(inner.left(), screen_y, inner.width, 1), row_style);
                var x = inner.left();
                const eff_guide = if (is_sel) hl_style else g_style;

                if (depth > 0) {
                    const max_d = @min(depth - 1, has_more.len);
                    for (0..max_d) |d| {
                        if (x >= inner.right()) break;
                        const prefix = if (has_more[d]) self.symbols_set.vertical else self.symbols_set.empty;
                        x = ui.buffer.setStringClipped(x, screen_y, prefix, inner.right() - x, eff_guide, inner).x;
                    }
                    if (x < inner.right()) {
                        const branch_sym = if (is_last) self.symbols_set.last_branch else self.symbols_set.branch;
                        x = ui.buffer.setStringClipped(x, screen_y, branch_sym, inner.right() - x, eff_guide, inner).x;
                    }
                }

                const toggle_sym = if (node.children.len == 0)
                    self.symbols_set.leaf
                else if (state.isExpanded(h))
                    self.symbols_set.expanded
                else
                    self.symbols_set.collapsed;

                if (x < inner.right()) {
                    x = ui.buffer.setStringClipped(x, screen_y, toggle_sym, inner.right() - x, if (is_sel) hl_style else ui.theme.accent, inner).x;
                }
                if (x < inner.right()) {
                    x = ui.buffer.setStringClipped(x, screen_y, node.label, inner.right() - x, row_style, inner).x;
                }
                if (node.badge) |bg| {
                    const bg_w = text_root.displayWidth(bg);
                    if (x + 2 + bg_w <= inner.right()) {
                        _ = ui.buffer.setStringClipped(inner.right() - bg_w, screen_y, bg, bg_w, if (is_sel) hl_style else ui.theme.muted, inner);
                    }
                }
            }

            if (node.children.len > 0 and state.isExpanded(h)) {
                if (depth < has_more.len) has_more[depth] = !is_last;
                self.renderRec(ui, inner, node.children, h, depth + 1, has_more, state, row_idx, base_style, g_style, hl_style);
            }
        }
    }
};

test "tree expands, collapses, and renders hierarchy lines" {
    const alloc = testing.allocator;
    var state = TreeState.init(alloc);
    defer state.deinit();

    const roots = [_]TreeNode{
        TreeNode.branch("src", &.{
            TreeNode.leaf("main.zig"),
            TreeNode.leaf("tui.zig"),
        }),
        TreeNode.leaf("build.zig"),
    };

    try testing.expectEqual(@as(usize, 2), state.visibleCount(&roots));
    try state.expandAll(&roots);
    try testing.expectEqual(@as(usize, 4), state.visibleCount(&roots));

    var buf = try core_root.Buffer.init(alloc, Rect.init(0, 0, 26, 6));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?core_root.Position = null;
    const theme = style_root.Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    try ui.renderStateful(Tree{ .roots = &roots, .block = .{ .title = "Files", .border_type = .plain } }, &state, buf.area);
    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "main.zig") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "tui.zig") != null);
}
