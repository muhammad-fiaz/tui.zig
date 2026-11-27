const std = @import("std");
const tui = @import("tui");

const tree_roots = [_]tui.TreeNode{
    tui.TreeNode.branch("src", &.{
        tui.TreeNode.branch("core", &.{
            tui.TreeNode.leaf("buffer.zig"),
            tui.TreeNode.leaf("layout.zig"),
            tui.TreeNode.leaf("frame.zig"),
        }),
        tui.TreeNode.branch("widgets", &.{
            tui.TreeNode.leaf("block.zig"),
            tui.TreeNode.leaf("table.zig"),
            tui.TreeNode.leaf("tree.zig"),
        }),
        tui.TreeNode.leaf("tui.zig"),
    }),
    tui.TreeNode.leaf("build.zig"),
};

const State = struct {
    tree: tui.TreeState,
    list: tui.ListState = .{ .selected = 0 },
    focus_tree: bool = true,
    tree_inner: tui.Rect = tui.Rect.zero,
    list_inner: tui.Rect = tui.Rect.zero,

    fn deinit(self: *State) void {
        self.tree.deinit();
    }
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC() or event.isChar('q')) {
        app.quit();
        return false;
    }
    if (event == .key and event.key.kind != .release and event.key.code == .tab) {
        state.focus_tree = !state.focus_tree;
        return true;
    }
    if (event == .mouse and event.mouse.kind == .down and event.mouse.button == .left) {
        if (event.mouse.isInside(state.tree_inner)) state.focus_tree = true;
        if (event.mouse.isInside(state.list_inner)) state.focus_tree = false;
    }
    if (state.focus_tree) {
        if (event == .key and event.key.kind != .release) {
            if (event.isChar('e')) {
                try state.tree.expandAll(&tree_roots);
                return true;
            }
            if (event.isChar('c')) {
                state.tree.collapseAll();
                return true;
            }
        }
        _ = try state.tree.handleEvent(event, &tree_roots, state.tree_inner, true);
    } else {
        _ = state.list.handleEvent(event, 4, @max(@as(u16, 1), state.list_inner.height), state.list_inner, true);
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});
    var hdr = layout[0];
    hdr.header(.{ .title = "Stateful Widgets", .right = "Tab Switch  e Expand All  c Collapse All" }, hdr.area);

    var mid = layout[1].margin(tui.Margin.uniform(1));
    const panes = try mid.splitPane(.{ .ratio_percent = 50 }, null);

    var left = panes[0];
    const tree_blk = tui.Block{ .title = "Module Tree", .focused = state.focus_tree };
    state.tree_inner = tree_blk.inner(left.area);
    try left.tree(.{
        .roots = &tree_roots,
        .block = tree_blk,
        .focused = state.focus_tree,
    }, &state.tree, left.area);

    var right = panes[1];
    const list_blk = tui.Block{ .title = "Quick Actions", .focused = !state.focus_tree };
    state.list_inner = list_blk.inner(right.area);
    try right.list(.{
        .raw_items = &.{ "Inspect symbols", "Run unit tests", "Format module", "Generate docs" },
        .block = list_blk,
        .focused = !state.focus_tree,
    }, &state.list, right.area);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{.{ .text = if (state.focus_tree) "TREE" else "LIST", .badge = true }},
        .right = &.{.{ .text = "Arrows / Enter / Click  Tab Switch  q Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .app = .{ .name = "Stateful Widgets", .version = tui.version },
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 80, .height = 20 } } else .auto,
        .settings = .{ .mouse = true },
    });
    defer app.deinit();

    var state = State{ .tree = app.treeState() };
    defer state.deinit();
    try state.tree.expandAll(&tree_roots);

    if (headless) {
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "buffer.zig") != null);
        // Verify collapseAll & expandAll
        _ = try onEvent(&state, .{ .key = .{ .code = .{ .char = 'c' } } }, &app);
        try app.draw(&state, render);
        const snap_collapsed = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap_collapsed, "buffer.zig") == null);
        _ = try onEvent(&state, .{ .key = .{ .code = .{ .char = 'e' } } }, &app);
        try app.draw(&state, render);
        const snap_expanded = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap_expanded, "buffer.zig") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
