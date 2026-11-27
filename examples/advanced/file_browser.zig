const std = @import("std");
const tui = @import("tui");

const repo_tree = [_]tui.TreeNode{
    tui.TreeNode.branch("src", &.{
        tui.TreeNode.branch("core", &.{
            tui.TreeNode.leaf("buffer.zig"),
            tui.TreeNode.leaf("layout.zig"),
        }),
        tui.TreeNode.branch("widgets", &.{
            tui.TreeNode.leaf("block.zig"),
            tui.TreeNode.leaf("table.zig"),
        }),
        tui.TreeNode.leaf("tui.zig"),
    }),
    tui.TreeNode.branch("examples", &.{
        tui.TreeNode.leaf("hello_world.zig"),
        tui.TreeNode.leaf("charts.zig"),
    }),
    tui.TreeNode.leaf("build.zig"),
    tui.TreeNode.leaf("README.md"),
};

fn previewForLabel(label: []const u8) []const u8 {
    if (std.mem.eql(u8, label, "buffer.zig")) return "Cell & Buffer double-buffered diff engine with 32-byte inline grapheme storage.";
    if (std.mem.eql(u8, label, "layout.zig")) return "Zero-allocation constraint solver (`rows`, `cols`, `splitFixed`) supporting flex spacing.";
    if (std.mem.eql(u8, label, "block.zig")) return "Container frame supporting 16 border sets, multiple titles, shadows, and edge merging.";
    if (std.mem.eql(u8, label, "table.zig")) return "Column-constrained data table with sticky header/footer and striped highlight rows.";
    if (std.mem.eql(u8, label, "hello_world.zig")) return "Minimal interactive application showing `tui.init`, `defer app.deinit()`, and `app.run`.";
    if (std.mem.eql(u8, label, "build.zig")) return "Zig package build graph defining module exports, unit tests, and 34 example binaries.";
    return "//! tui.zig public entry point\npub const style = @import(\"style/root.zig\");\npub const core = @import(\"core/root.zig\");\npub const widgets = @import(\"widgets/root.zig\");";
}

const State = struct {
    tree: tui.TreeState,
    filter: tui.TextInputState,
    focus_filter: bool = false,
    filter_rect: tui.Rect = tui.Rect.zero,
    tree_inner: tui.Rect = tui.Rect.zero,
    selected_name: []const u8 = "src",

    fn deinit(self: *State) void {
        self.tree.deinit();
        self.filter.deinit();
    }
};

fn findVisibleLabel(state: *const tui.TreeState, nodes: []const tui.TreeNode, parent_hash: u64, target: usize, idx: *usize) ?[]const u8 {
    for (nodes, 0..) |node, i| {
        const cur = idx.*;
        idx.* += 1;
        if (cur == target) return node.label;
        var hasher = std.hash.Fnv1a_64.init();
        hasher.update(std.mem.asBytes(&parent_hash));
        hasher.update(std.mem.asBytes(&i));
        hasher.update(node.label);
        const h = hasher.final();
        if (node.children.len > 0 and state.isExpanded(h)) {
            if (findVisibleLabel(state, node.children, h, target, idx)) |lbl| return lbl;
        }
    }
    return null;
}

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isCtrlC() or event.isEscape()) {
        app.quit();
        return false;
    }
    if (!state.focus_filter and event.isChar('q')) {
        app.quit();
        return false;
    }
    if (event == .mouse and event.mouse.kind == .down and event.mouse.button == .left) {
        if (event.mouse.isInside(state.filter_rect)) {
            state.focus_filter = true;
            return true;
        }
        if (event.mouse.isInside(state.tree_inner)) {
            state.focus_filter = false;
        }
    }
    if (event == .key and event.key.kind != .release and event.key.code == .tab) {
        state.focus_filter = !state.focus_filter;
        return true;
    }
    if (state.focus_filter) {
        _ = try state.filter.handleEvent(event, true);
    } else {
        _ = try state.tree.handleEvent(event, &repo_tree, state.tree_inner, true);
        if (state.tree.selected) |row| {
            var idx: usize = 0;
            if (findVisibleLabel(&state.tree, &repo_tree, 0xcbf29ce484222325, row, &idx)) |lbl| {
                state.selected_name = lbl;
            }
        }
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(4, .{
        .{ .length = 1 },
        .{ .length = 3 },
        .{ .fill = 1 },
        .{ .length = 1 },
    }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "File Browser", .right = "Tab Filter/Tree  Enter Expand" }, hdr.area);

    var search_ui = layout[1];
    state.filter_rect = search_ui.area;
    try search_ui.textInput(.{
        .prefix = "🔍 ",
        .placeholder = "Filter note / jump...",
        .focused = state.focus_filter,
    }, &state.filter, search_ui.area);

    var split_area = layout[2];
    const panes = try split_area.splitPane(.{ .ratio_percent = 40 }, null);

    var left = panes[0];
    const tree_blk = tui.Block{ .title = "Workspace", .focused = !state.focus_filter };
    state.tree_inner = tree_blk.inner(left.area);
    try left.tree(.{
        .roots = &repo_tree,
        .block = tree_blk,
        .focused = !state.focus_filter,
    }, &state.tree, left.area);

    var right = panes[1];
    try right.panel(.{ .title = "Preview", .padding = tui.Padding.uniform(1) }, right.area, state, struct {
        fn draw(st: *State, p: *tui.Ui) !void {
            p.breadcrumbs(.{ .segments = &.{ "tui.zig", st.selected_name } }, null);
            p.space(1);
            try p.paragraph(.{
                .raw = previewForLabel(st.selected_name),
                .wrap = .word,
            }, null);
            if (st.filter.text().len > 0) {
                p.space(1);
                var q_buf: [64]u8 = undefined;
                const q_txt = std.fmt.bufPrint(&q_buf, "Active Filter Query: \"{s}\"", .{st.filter.text()}) catch "";
                try p.text(q_txt, .{ .style = .{ .foreground = tui.palette.sky.c400 } }, null);
            }
        }
    }.draw);

    var ft = layout[3];
    ft.statusBar(.{
        .left = &.{ .{ .text = "BROWSER", .badge = true }, .{ .text = state.selected_name } },
        .right = &.{.{ .text = "Tab Filter  Arrows/Click Browse  Esc Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .app = .{ .name = "File Browser", .version = tui.version },
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 90, .height = 24 } } else .auto,
        .settings = .{ .mouse = true },
    });
    defer app.deinit();

    var state = State{
        .tree = app.treeState(),
        .filter = app.textInput(),
    };
    defer state.deinit();
    try state.tree.expandAll(&repo_tree);

    if (headless) {
        try app.draw(&state, render);
        _ = try onEvent(&state, .{ .key = .{ .code = .down } }, &app);
        _ = try onEvent(&state, .{ .key = .{ .code = .down } }, &app);
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "buffer.zig") != null);
        std.debug.assert(std.mem.indexOf(u8, snap, "Preview") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
