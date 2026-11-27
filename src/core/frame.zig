//! Frame and UI rendering context (`Ui` / `Frame`).
//!
//! `Ui` is the unified rendering surface passed to applications and custom
//! widgets. It provides:
//! - Direct access to the target `Buffer`, `Rect` bounds, active `Theme`, and
//!   per-frame resettable scratch arena (avoiding heap churn across frames).
//! - Explicit region splitting (`splitFixed`, `rows`, `cols`, `region`, `inset`).
//! - Built-in flow cursor tracking (`advance`, `space`) so widgets can either
//!   stack automatically OR target exact rectangles.
//! - Direct high-level component methods (`ui.panel`, `ui.paragraph`, `ui.button`, ...).

const std = @import("std");
const geom = @import("geometry.zig");
const con = @import("constraint.zig");
const layout_mod = @import("layout.zig");
const buffer_mod = @import("buffer.zig");
const style_root = @import("../style/root.zig");
const testing = std.testing;

pub const Rect = geom.Rect;
pub const Position = geom.Position;
pub const Margin = geom.Margin;
pub const Padding = geom.Padding;
pub const Alignment = geom.Alignment;
pub const Direction = con.Direction;
pub const Constraint = con.Constraint;
pub const LayoutOptions = layout_mod.LayoutOptions;
pub const Buffer = buffer_mod.Buffer;
pub const AppInfo = @import("config.zig").AppInfo;
pub const Style = style_root.Style;
pub const Theme = style_root.Theme;

/// Unified rendering context representing a rectangular area within a frame.
///
/// Copying a `Ui` value creates an independent child view referencing the same
/// underlying frame buffer, theme, scratch arena, app metadata, and cursor request slot.
pub const Ui = struct {
    /// Target cell buffer for this frame.
    buffer: *Buffer,
    /// Active theme used for default widget colors and borders.
    theme: *const Theme,
    /// Per-frame arena reset on every `beginFrame()` (retaining capacity).
    scratch: *std.heap.ArenaAllocator,
    /// Shared cursor output slot for the frame (for text inputs / editors).
    cursor_request: *?Position,
    /// Clipped bounding rectangle owned by this `Ui` view.
    area: Rect,
    /// Automatic vertical flow offset within `area` for stacked components.
    flow_y: u16,
    /// Default spacing inserted after each flow-allocated component.
    flow_spacing: u16 = 0,
    /// Tab expansion width.
    tab_size: u8 = 4,
    /// Application identity and metadata associated with the owning `App` instance.
    app: AppInfo = .{},

    /// Creates a root `Ui` covering `area`.
    pub fn init(
        buffer: *Buffer,
        theme: *const Theme,
        scratch: *std.heap.ArenaAllocator,
        cursor_request: *?Position,
        area: Rect,
        tab_size: u8,
    ) Ui {
        const clipped = area.intersection(buffer.area);
        return .{
            .buffer = buffer,
            .theme = theme,
            .scratch = scratch,
            .cursor_request = cursor_request,
            .area = clipped,
            .flow_y = clipped.y,
            .tab_size = tab_size,
        };
    }

    /// Creates a root `Ui` bound to an explicit `AppInfo` identity.
    pub fn initWithApp(
        buffer: *Buffer,
        theme: *const Theme,
        scratch: *std.heap.ArenaAllocator,
        cursor_request: *?Position,
        area: Rect,
        tab_size: u8,
        app_info: AppInfo,
    ) Ui {
        var u = Ui.init(buffer, theme, scratch, cursor_request, area, tab_size);
        u.app = app_info;
        return u;
    }

    /// Returns the per-frame scratch allocator (freed automatically at the end of the frame).
    pub fn scratchAllocator(self: *Ui) std.mem.Allocator {
        return self.scratch.allocator();
    }

    /// Returns the remaining vertical flow area inside `self.area`.
    pub fn available(self: *const Ui) Rect {
        if (self.flow_y >= self.area.bottom()) return Rect.zero;
        return .{
            .x = self.area.x,
            .y = self.flow_y,
            .width = self.area.width,
            .height = self.area.bottom() - self.flow_y,
        };
    }

    /// Advances the vertical flow cursor by `height` rows (plus `flow_spacing`) and
    /// returns the allocated `Rect`, clipped to `self.area`.
    pub fn allocateRows(self: *Ui, height: u16) Rect {
        const avail = self.available();
        if (avail.isEmpty() or height == 0) return Rect.zero;
        const h = @min(height, avail.height);
        const rect = Rect.init(avail.x, avail.y, avail.width, h);
        self.flow_y = avail.y + h +| self.flow_spacing;
        return rect;
    }

    /// Resolves the target rectangle for a widget: uses `explicit` (clipped to `self.area`)
    /// if provided, otherwise allocates `default_height` rows from flow (or all remaining if `null`).
    pub fn resolveArea(self: *Ui, explicit: ?Rect, default_height: ?u16) Rect {
        if (explicit) |r| {
            return r.intersection(self.buffer.area);
        }
        const avail = self.available();
        if (avail.isEmpty()) return Rect.zero;
        if (default_height) |h| {
            return self.allocateRows(h);
        }
        self.flow_y = self.area.bottom();
        return avail;
    }

    /// Advances vertical flow by `rows` blank lines.
    pub fn space(self: *Ui, rows_count: u16) void {
        self.flow_y = @min(self.area.bottom(), self.flow_y +| rows_count);
    }

    /// Returns a child `Ui` clipped to `sub_area` (intersected with `self.area`).
    pub fn region(self: *const Ui, sub_area: Rect) Ui {
        const clipped = self.area.intersection(sub_area);
        return .{
            .buffer = self.buffer,
            .theme = self.theme,
            .scratch = self.scratch,
            .cursor_request = self.cursor_request,
            .area = clipped,
            .flow_y = clipped.y,
            .flow_spacing = self.flow_spacing,
            .tab_size = self.tab_size,
            .app = self.app,
        };
    }

    /// Returns a child `Ui` inset by `pad`.
    pub fn inset(self: *const Ui, pad: Padding) Ui {
        return self.region(self.area.inset(pad));
    }

    /// Returns a child `Ui` inset by symmetric `m`.
    pub fn margin(self: *const Ui, m: Margin) Ui {
        return self.region(self.area.inner(m));
    }

    /// Returns the dimensions of this `Ui` region.
    pub fn size(self: *const Ui) geom.Size {
        return self.area.size();
    }

    /// True when the region width is strictly less than `threshold` columns.
    /// Useful in responsive custom UI layouts switching between compact and wide panes.
    pub fn isCompact(self: *const Ui, threshold: u16) bool {
        return self.area.width < threshold;
    }

    /// Splits `self.area` into `[N]Rect` with zero heap allocation.
    pub fn splitFixed(self: *const Ui, comptime N: usize, constraints: [N]Constraint, options: LayoutOptions) [N]Rect {
        return layout_mod.splitFixed(N, self.area, constraints, options);
    }

    /// Splits `self.area` horizontally into `[N]Ui` child regions with zero heap allocation.
    pub fn cols(self: *const Ui, comptime N: usize, constraints: [N]Constraint, options: LayoutOptions) [N]Ui {
        var opts = options;
        opts.direction = .horizontal;
        const rects = layout_mod.splitFixed(N, self.area, constraints, opts);
        var children: [N]Ui = undefined;
        for (rects, 0..) |r, i| children[i] = self.region(r);
        return children;
    }

    /// Splits `self.area` vertically into `[N]Ui` child regions with zero heap allocation.
    pub fn rows(self: *const Ui, comptime N: usize, constraints: [N]Constraint, options: LayoutOptions) [N]Ui {
        var opts = options;
        opts.direction = .vertical;
        const rects = layout_mod.splitFixed(N, self.area, constraints, opts);
        var children: [N]Ui = undefined;
        for (rects, 0..) |r, i| children[i] = self.region(r);
        return children;
    }

    /// Allocates a split using the per-frame scratch arena (automatically freed at frame end).
    pub fn splitScratch(self: *Ui, constraints: []const Constraint, options: LayoutOptions) ![]Rect {
        return layout_mod.splitAlloc(self.scratchAllocator(), self.area, constraints, options);
    }

    /// Requests the terminal hardware cursor be displayed at `(x, y)` after this frame flushes.
    pub fn setCursor(self: *Ui, x: u16, y: u16) void {
        if (self.area.containsXY(x, y)) {
            self.cursor_request.* = .{ .x = x, .y = y };
        }
    }

    /// Fills `self.area` with `self.theme.surface` background and foreground style.
    pub fn fillThemeSurface(self: *Ui) void {
        self.buffer.fill(self.area, " ", self.theme.surface);
    }

    /// Renders any built-in or user-defined widget into `target_area` (or `self.area` when `null`).
    ///
    /// Supports both stateless widgets (`fn render(self, buf_or_ui, area)`) and
    /// error-returning widgets seamlessly via Zig comptime dispatch.
    pub fn renderWidget(self: *Ui, widget: anytype, target_area: ?Rect) !void {
        const dest = self.resolveArea(target_area, null);
        if (dest.isEmpty()) return;

        const T = @TypeOf(widget);
        const BaseT = switch (@typeInfo(T)) {
            .pointer => |p| p.child,
            else => T,
        };
        if (!@hasDecl(BaseT, "render")) {
            @compileError("Widget type " ++ @typeName(BaseT) ++ " must declare `pub fn render(...)`");
        }
        const render_fn = @field(BaseT, "render");
        const fn_info = @typeInfo(@TypeOf(render_fn)).@"fn";
        if (fn_info.param_types.len != 3) {
            @compileError("Widget.render must take (self, target, area)");
        }
        const TargetParam = fn_info.param_types[1].?;
        const ret_is_err = @typeInfo(fn_info.return_type.?) == .error_union;

        if (TargetParam == *Ui) {
            var child = self.region(dest);
            if (ret_is_err) {
                try widget.render(&child, dest);
            } else {
                widget.render(&child, dest);
            }
        } else if (TargetParam == *Buffer) {
            if (ret_is_err) {
                try widget.render(self.buffer, dest);
            } else {
                widget.render(self.buffer, dest);
            }
        } else {
            @compileError("Widget.render second parameter must be *Ui or *Buffer");
        }
    }

    /// Renders a stateful custom or built-in widget into `target_area`.
    pub fn renderStateful(self: *Ui, widget: anytype, state: anytype, target_area: ?Rect) !void {
        const dest = self.resolveArea(target_area, null);
        if (dest.isEmpty()) return;

        const T = @TypeOf(widget);
        const BaseT = switch (@typeInfo(T)) {
            .pointer => |p| p.child,
            else => T,
        };
        if (!@hasDecl(BaseT, "renderStateful")) {
            @compileError("Widget type " ++ @typeName(BaseT) ++ " must declare `pub fn renderStateful(...)`");
        }
        const render_fn = @field(BaseT, "renderStateful");
        const fn_info = @typeInfo(@TypeOf(render_fn)).@"fn";
        const TargetParam = fn_info.param_types[1].?;
        const ret_is_err = @typeInfo(fn_info.return_type.?) == .error_union;

        if (TargetParam == *Ui) {
            var child = self.region(dest);
            if (ret_is_err) {
                try widget.renderStateful(&child, dest, state);
            } else {
                widget.renderStateful(&child, dest, state);
            }
        } else {
            if (ret_is_err) {
                try widget.renderStateful(self.buffer, dest, state);
            } else {
                widget.renderStateful(self.buffer, dest, state);
            }
        }
    }

    // -------------------------------------------------------------------------
    // High-level flat widget helpers (zero extra option types; pass `.{ ... }`)
    // -------------------------------------------------------------------------

    /// Draws a raw UTF-8 string reusing `Paragraph` styling/alignment/wrap options directly (zero extra option type).
    pub fn text(
        self: *Ui,
        raw: []const u8,
        opts: @import("../widgets/paragraph.zig").Paragraph,
        target_area: ?Rect,
    ) !void {
        var p = opts;
        p.raw = raw;
        const dest = if (target_area) |r|
            self.resolveArea(r, null)
        else
            self.resolveArea(null, @max(@as(u16, 1), p.totalHeightForWidth(self.available().width)));
        try p.render(self, dest);
    }

    /// Renders a `Clear` surface reset over `target_area` (or remaining flow area).
    pub fn clear(self: *Ui, target_area: ?Rect) void {
        const w = @import("../widgets/clear.zig");
        const dest = self.resolveArea(target_area, null);
        w.Clear.render(.{}, self, dest);
    }

    /// Renders a `Fill` over `target_area`.
    pub fn fill(self: *Ui, opts: @import("../widgets/clear.zig").Fill, target_area: ?Rect) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.render(self, dest);
    }

    /// Renders a single-row horizontal `Divider` (or vertical when specified).
    pub fn divider(self: *Ui, opts: @import("../widgets/clear.zig").Divider, target_area: ?Rect) !void {
        const dest = self.resolveArea(target_area, if (opts.direction == .horizontal) 1 else null);
        try opts.render(self, dest);
    }

    /// Renders a standalone `Block` container frame.
    pub fn block(self: *Ui, opts: @import("../widgets/block.zig").Block, target_area: ?Rect) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.render(self, dest);
    }

    /// Renders a `Block` container and passes a clipped inner `*Ui` region to `draw_fn(ctx, *Ui)`.
    pub fn panel(
        self: *Ui,
        opts: @import("../widgets/block.zig").Block,
        target_area: ?Rect,
        ctx: anytype,
        comptime draw_fn: anytype,
    ) !void {
        const dest = self.resolveArea(target_area, null);
        if (dest.isEmpty()) return;
        try opts.render(self, dest);
        const inner_rect = opts.inner(dest);
        if (inner_rect.isEmpty()) return;
        var inner_ui = self.region(inner_rect);
        const ret_err = @typeInfo(@typeInfo(@TypeOf(draw_fn)).@"fn".return_type.?) == .error_union;
        if (ret_err) {
            try draw_fn(ctx, &inner_ui);
        } else {
            draw_fn(ctx, &inner_ui);
        }
    }

    /// Renders a `Paragraph` (measures natural height automatically when `target_area == null`).
    pub fn paragraph(self: *Ui, opts: @import("../widgets/paragraph.zig").Paragraph, target_area: ?Rect) !void {
        const dest = if (target_area) |r|
            self.resolveArea(r, null)
        else
            self.resolveArea(null, @max(@as(u16, 1), opts.totalHeightForWidth(self.available().width)));
        try opts.render(self, dest);
    }

    /// Renders an interactive `Button` (`3` rows by default, or `1` when `compact = true`).
    pub fn button(self: *Ui, opts: @import("../widgets/button.zig").Button, target_area: ?Rect) !void {
        const def_h: u16 = if (opts.compact or opts.variant == .ghost) 1 else 3;
        const dest = self.resolveArea(target_area, def_h);
        try opts.render(self, dest);
    }

    /// Renders a single-row `Checkbox`.
    pub fn checkbox(self: *Ui, opts: @import("../widgets/checkbox.zig").Checkbox, target_area: ?Rect) void {
        const dest = self.resolveArea(target_area, 1);
        opts.render(self, dest);
    }

    /// Renders a `RadioGroup` (stateless when `state == null`, stateful otherwise).
    pub fn radio(
        self: *Ui,
        opts: @import("../widgets/radio.zig").RadioGroup,
        state: ?*@import("../widgets/radio.zig").RadioState,
        target_area: ?Rect,
    ) !void {
        const def_h: u16 = if (opts.direction == .horizontal)
            (if (opts.block != null) @as(u16, 3) else 1)
        else
            @intCast(@min(std.math.maxInt(u16), opts.items.len + if (opts.block != null) @as(usize, 2) else 0));
        const dest = self.resolveArea(target_area, @max(@as(u16, 1), def_h));
        if (state) |st| {
            try opts.renderStateful(self, dest, st);
        } else {
            try opts.render(self, dest);
        }
    }

    /// Renders a `TextInput` (`3` rows when bordered, `1` when borderless).
    pub fn textInput(
        self: *Ui,
        opts: @import("../widgets/text_input.zig").TextInput,
        state: *@import("../widgets/text_input.zig").TextInputState,
        target_area: ?Rect,
    ) !void {
        const def_h: u16 = if (opts.block != null) 3 else 1;
        const dest = self.resolveArea(target_area, def_h);
        try opts.renderStateful(self, dest, state);
    }

    /// Renders a multi-line `TextArea`.
    pub fn textArea(
        self: *Ui,
        opts: @import("../widgets/text_area.zig").TextArea,
        state: *@import("../widgets/text_area.zig").TextAreaState,
        target_area: ?Rect,
    ) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.renderStateful(self, dest, state);
    }

    /// Renders a `List` (with optional mutable `ListState`).
    pub fn list(
        self: *Ui,
        opts: @import("../widgets/list.zig").List,
        state: ?*@import("../widgets/list.zig").ListState,
        target_area: ?Rect,
    ) !void {
        const dest = self.resolveArea(target_area, null);
        if (state) |st| {
            try opts.renderStateful(self, dest, st);
        } else {
            try opts.render(self, dest);
        }
    }

    /// Renders a `Table` (with optional mutable `TableState`).
    pub fn table(
        self: *Ui,
        opts: @import("../widgets/table.zig").Table,
        state: ?*@import("../widgets/table.zig").TableState,
        target_area: ?Rect,
    ) !void {
        const dest = self.resolveArea(target_area, null);
        if (state) |st| {
            try opts.renderStateful(self, dest, st);
        } else {
            try opts.render(self, dest);
        }
    }

    /// Renders horizontal `Tabs` (`3` rows when bordered, `1` otherwise).
    pub fn tabs(self: *Ui, opts: @import("../widgets/tabs.zig").Tabs, target_area: ?Rect) !void {
        const def_h: u16 = if (opts.block != null) 3 else 1;
        const dest = self.resolveArea(target_area, def_h);
        try opts.render(self, dest);
    }

    /// Renders a `Select` / dropdown combobox (`3` rows when bordered, `1` otherwise).
    pub fn select(
        self: *Ui,
        opts: @import("../widgets/select.zig").Select,
        state: *@import("../widgets/select.zig").SelectState,
        target_area: ?Rect,
    ) !void {
        const def_h: u16 = if (opts.block != null) 3 else 1;
        const dest = self.resolveArea(target_area, def_h);
        try opts.renderStateful(self, dest, state);
    }

    /// Renders a collapsible `Tree`.
    pub fn tree(
        self: *Ui,
        opts: @import("../widgets/tree.zig").Tree,
        state: *@import("../widgets/tree.zig").TreeState,
        target_area: ?Rect,
    ) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.renderStateful(self, dest, state);
    }

    /// Renders a fractional-block `Gauge`.
    pub fn gauge(self: *Ui, opts: @import("../widgets/gauge.zig").Gauge, target_area: ?Rect) !void {
        const def_h: u16 = if (opts.block != null) 3 else 1;
        const dest = self.resolveArea(target_area, def_h);
        try opts.render(self, dest);
    }

    /// Renders a single-line `LineGauge`.
    pub fn lineGauge(self: *Ui, opts: @import("../widgets/gauge.zig").LineGauge, target_area: ?Rect) !void {
        const def_h: u16 = if (opts.block != null) 3 else 1;
        const dest = self.resolveArea(target_area, def_h);
        try opts.render(self, dest);
    }

    /// Renders a `ProgressBar`.
    pub fn progress(self: *Ui, opts: @import("../widgets/gauge.zig").ProgressBar, target_area: ?Rect) !void {
        const def_h: u16 = if (opts.block != null) 3 else 1;
        const dest = self.resolveArea(target_area, def_h);
        try opts.render(self, dest);
    }

    /// Renders an animated `Spinner`.
    pub fn spinner(self: *Ui, opts: @import("../widgets/gauge.zig").Spinner, target_area: ?Rect) void {
        const dest = self.resolveArea(target_area, 1);
        opts.render(self, dest);
    }

    /// Renders a `Scrollbar`.
    pub fn scrollbar(
        self: *Ui,
        opts: @import("../widgets/scrollbar.zig").Scrollbar,
        state: *@import("../widgets/scrollbar.zig").ScrollbarState,
        target_area: ?Rect,
    ) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.renderStateful(self, dest, state);
    }

    /// Renders a `Sparkline`.
    pub fn sparkline(self: *Ui, opts: @import("../widgets/sparkline.zig").Sparkline, target_area: ?Rect) !void {
        const def_h: ?u16 = if (opts.block != null) 4 else 2;
        const dest = self.resolveArea(target_area, def_h);
        try opts.render(self, dest);
    }

    /// Renders a grouped `BarChart`.
    pub fn barChart(self: *Ui, opts: @import("../widgets/barchart.zig").BarChart, target_area: ?Rect) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.render(self, dest);
    }

    /// Renders an XY `Chart`.
    pub fn chart(self: *Ui, opts: @import("../widgets/chart.zig").Chart, target_area: ?Rect) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.render(self, dest);
    }

    /// Renders a declarative `Canvas`.
    pub fn canvas(self: *Ui, opts: @import("../widgets/canvas.zig").Canvas, target_area: ?Rect) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.render(self, dest);
    }

    /// Renders a centered/anchored modal `Popup` invoking `draw_fn(ctx, *Ui)` inside its body.
    pub fn popup(
        self: *Ui,
        opts: @import("../widgets/popup.zig").Popup,
        target_area: ?Rect,
        ctx: anytype,
        comptime draw_fn: anytype,
    ) !void {
        const dest = target_area orelse self.buffer.area;
        try opts.renderWith(self, dest, ctx, draw_fn);
    }

    /// Renders a `ConfirmDialog` synchronized with `state`.
    pub fn confirmDialog(
        self: *Ui,
        opts: @import("../widgets/popup.zig").ConfirmDialog,
        state: *@import("../widgets/popup.zig").ConfirmState,
        target_area: ?Rect,
    ) !void {
        const dest = target_area orelse self.buffer.area;
        try opts.renderStateful(self, dest, state);
    }

    /// Renders a floating `Toast` notification banner.
    pub fn toast(self: *Ui, opts: @import("../widgets/popup.zig").Toast, target_area: ?Rect) !void {
        const dest = target_area orelse self.buffer.area;
        try opts.render(self, dest);
    }

    /// Renders a top `Header` bar (`1` row).
    pub fn header(self: *Ui, opts: @import("../widgets/chrome.zig").Header, target_area: ?Rect) void {
        const dest = self.resolveArea(target_area, 1);
        opts.render(self, dest);
    }

    /// Renders a bottom `StatusBar` (`1` row).
    pub fn statusBar(self: *Ui, opts: @import("../widgets/chrome.zig").StatusBar, target_area: ?Rect) void {
        const dest = self.resolveArea(target_area, 1);
        opts.render(self, dest);
    }

    /// Renders a horizontal `MenuBar` (`1` row).
    pub fn menuBar(self: *Ui, opts: @import("../widgets/chrome.zig").MenuBar, target_area: ?Rect) void {
        const dest = self.resolveArea(target_area, 1);
        opts.render(self, dest);
    }

    /// Renders a floating `ContextMenu` overlay inside `target_area` (or `self.buffer.area`).
    pub fn contextMenu(self: *Ui, opts: @import("../widgets/chrome.zig").ContextMenu, target_area: ?Rect) !void {
        const dest = target_area orelse self.buffer.area;
        try opts.render(self, dest);
    }

    /// Renders `Breadcrumbs` navigation (`1` row).
    pub fn breadcrumbs(self: *Ui, opts: @import("../widgets/chrome.zig").Breadcrumbs, target_area: ?Rect) void {
        const dest = self.resolveArea(target_area, 1);
        opts.render(self, dest);
    }

    /// Renders a bordered `ScrollView` with proportional scrollbar and `draw_fn(ctx, *Ui, offset_y)`.
    pub fn scrollView(
        self: *Ui,
        opts: @import("../widgets/chrome.zig").ScrollView,
        state: *@import("../widgets/chrome.zig").ScrollViewState,
        target_area: ?Rect,
        ctx: anytype,
        comptime draw_fn: anytype,
    ) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.renderWith(self, dest, state, ctx, draw_fn);
    }

    /// Splits `target_area` (or `self.available()`) into two child `Ui` viewports with optional divider.
    pub fn splitPane(
        self: *Ui,
        opts: @import("../widgets/chrome.zig").SplitPane,
        target_area: ?Rect,
    ) ![2]Ui {
        const dest = self.resolveArea(target_area, null);
        return opts.split(self, dest);
    }

    /// Renders a horizontal `Navbar` (`1` row by default).
    pub fn navbar(self: *Ui, opts: @import("../widgets/chrome.zig").Navbar, target_area: ?Rect) void {
        const dest = self.resolveArea(target_area, 1);
        opts.render(self, dest);
    }

    /// Renders a dockable left/right/RTL `Sidebar`.
    pub fn sidebar(self: *Ui, opts: @import("../widgets/chrome.zig").Sidebar, target_area: ?Rect) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.render(self, dest);
    }

    /// Renders a monthly `Calendar` view synchronized with optional `CalendarState`.
    pub fn calendar(
        self: *Ui,
        opts: @import("../widgets/calendar.zig").Calendar,
        state: ?*@import("../widgets/calendar.zig").CalendarState,
        target_area: ?Rect,
    ) !void {
        const def_h: u16 = if (opts.block != null) 10 else 8;
        const dest = self.resolveArea(target_area, def_h);
        if (state) |st| {
            try opts.renderStateful(self, dest, st);
        } else {
            try opts.render(self, dest);
        }
    }

    /// Renders a single-row ON/OFF `Switch` pill control.
    pub fn switchToggle(self: *Ui, opts: @import("../widgets/controls.zig").Switch, target_area: ?Rect) void {
        const dest = self.resolveArea(target_area, 1);
        opts.render(self, dest);
    }

    /// Renders a `Slider` range control (`1` row).
    pub fn slider(
        self: *Ui,
        opts: @import("../widgets/controls.zig").Slider,
        state: *@import("../widgets/controls.zig").SliderState,
        target_area: ?Rect,
    ) !void {
        const dest = self.resolveArea(target_area, 1);
        try opts.renderStateful(self, dest, state);
    }

    /// Renders a semantic pill `Badge` (`1` row).
    pub fn badge(self: *Ui, opts: @import("../widgets/controls.zig").Badge, target_area: ?Rect) void {
        const dest = self.resolveArea(target_area, 1);
        opts.render(self, dest);
    }

    /// Renders an expandable `Accordion` section invoking `draw_fn(ctx, *Ui)` when expanded.
    pub fn accordion(
        self: *Ui,
        opts: @import("../widgets/controls.zig").Accordion,
        target_area: ?Rect,
        ctx: anytype,
        comptime draw_fn: anytype,
    ) !void {
        const dest = if (target_area) |r| self.resolveArea(r, null) else self.available();
        const used = try opts.renderWith(self, dest, ctx, draw_fn);
        if (target_area == null) self.flow_y = @min(self.area.bottom(), self.flow_y +| used +| self.flow_spacing);
    }

    /// Renders an animated `Skeleton` loading shimmer placeholder.
    pub fn skeleton(self: *Ui, opts: @import("../widgets/effects.zig").Skeleton, target_area: ?Rect) !void {
        const dest = self.resolveArea(target_area, opts.rows);
        try opts.render(self, dest);
    }

    /// Renders a block-pixel `BigText` banner (auto-sizing height for selected `BitmapFont` and `mode`).
    pub fn bigText(self: *Ui, opts: @import("../widgets/misc.zig").BigText, target_area: ?Rect) !void {
        const default_h: u16 = if (target_area == null) blk_h: {
            const font_mod = @import("../text/font.zig");
            const active_font = opts.font orelse &font_mod.BitmapFont.block_3x5;
            const cells = active_font.measureCells(opts.text, opts.mode, @max(@as(u16, 1), opts.scale_x), @max(@as(u16, 1), opts.scale_y));
            break :blk_h @max(@as(u16, 1), cells.rows);
        } else @import("../widgets/misc.zig").BigText.banner_height;
        const dest = self.resolveArea(target_area, default_h);
        try opts.render(self, dest);
    }

    /// Renders a `PieChart` or Donut chart.
    pub fn pieChart(self: *Ui, opts: @import("../widgets/pie_chart.zig").PieChart, target_area: ?Rect) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.render(self, dest);
    }

    /// Renders a 2D `Heatmap`.
    pub fn heatmap(self: *Ui, opts: @import("../widgets/heatmap.zig").Heatmap, target_area: ?Rect) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.render(self, dest);
    }

    /// Renders a structured `LogViewer`.
    pub fn logViewer(
        self: *Ui,
        opts: @import("../widgets/log_viewer.zig").LogViewer,
        state: *@import("../widgets/log_viewer.zig").LogViewerState,
        target_area: ?Rect,
    ) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.renderStateful(self, dest, state);
    }

    /// Renders a unified `DiffViewer`.
    pub fn diffViewer(
        self: *Ui,
        opts: @import("../widgets/diff_viewer.zig").DiffViewer,
        state: *@import("../widgets/diff_viewer.zig").DiffViewerState,
        target_area: ?Rect,
    ) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.renderStateful(self, dest, state);
    }

    /// Renders a horizontal/vertical workflow `Stepper`.
    pub fn stepper(self: *Ui, opts: @import("../widgets/stepper.zig").Stepper, target_area: ?Rect) !void {
        const def_h: ?u16 = if (opts.direction == .horizontal) (if (opts.block != null) @as(u16, 3) else 1) else null;
        const dest = self.resolveArea(target_area, def_h);
        try opts.render(self, dest);
    }

    /// Renders an interactive `Pagination` bar (`1` row by default).
    pub fn pagination(self: *Ui, opts: @import("../widgets/pagination.zig").Pagination, page: *usize, target_area: ?Rect) !void {
        const def_h: u16 = if (opts.block != null) 3 else 1;
        const dest = self.resolveArea(target_area, def_h);
        try opts.renderStateful(self, dest, page);
    }

    /// Renders a `KeyValueList` summary.
    pub fn keyValueList(self: *Ui, opts: @import("../widgets/key_value.zig").KeyValueList, target_area: ?Rect) !void {
        const def_h: u16 = @intCast(@min(std.math.maxInt(u16), opts.entries.len + if (opts.block != null) @as(usize, 2) else 0));
        const dest = self.resolveArea(target_area, @max(@as(u16, 1), def_h));
        try opts.render(self, dest);
    }

    /// Renders a `TerminalView` backed by a `VtScreen` ANSI/VT100 buffer.
    pub fn terminalView(self: *Ui, opts: @import("../widgets/terminal_view.zig").TerminalView, target_area: ?Rect) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.render(self, dest);
    }

    /// Renders a cascading `DropdownMenu` bar and any open submenus.
    pub fn dropdownMenu(
        self: *Ui,
        opts: @import("../widgets/chrome.zig").DropdownMenu,
        state: *const @import("../widgets/chrome.zig").MenuState,
        bar_area: Rect,
        screen: ?Rect,
    ) !void {
        try opts.render(self, bar_area, screen orelse self.buffer.area, state);
    }

    /// Renders formatted terminal `Markdown`.
    pub fn markdown(self: *Ui, opts: @import("../widgets/misc.zig").Markdown, target_area: ?Rect) !void {
        const dest = self.resolveArea(target_area, null);
        try opts.render(self, dest);
    }

    /// Renders an interactive fuzzy-filtering `CommandPalette` overlay.
    pub fn commandPalette(
        self: *Ui,
        opts: @import("../widgets/misc.zig").CommandPalette,
        state: *@import("../widgets/misc.zig").CommandPaletteState,
        target_area: ?Rect,
    ) !void {
        const dest = target_area orelse self.buffer.area;
        try opts.renderStateful(self, dest, state);
    }

    /// Renders a contextual floating `Tooltip` anchored beside `opts.anchor_rect`.
    pub fn tooltip(self: *Ui, opts: @import("../widgets/misc.zig").Tooltip, target_area: ?Rect) !void {
        const dest = target_area orelse self.buffer.area;
        try opts.render(self, dest);
    }
};

/// Alias for `Ui` so frame-oriented naming (`*tui.Frame`) works identically.
pub const Frame = Ui;

test "ui region, flow allocation, cols/rows, and custom widget dispatch" {
    const alloc = testing.allocator;
    var buf = try Buffer.init(alloc, Rect.init(0, 0, 20, 6));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?Position = null;
    const theme = Theme.dark;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    const halves = ui.cols(2, .{ .{ .length = 10 }, .{ .fill = 1 } }, .{});
    try testing.expectEqual(@as(u16, 10), halves[0].area.width);
    try testing.expectEqual(@as(u16, 10), halves[1].area.x);

    const Custom = struct {
        label: []const u8,
        pub fn render(self: @This(), target: *Buffer, area: Rect) void {
            _ = target.setStringClipped(area.x, area.y, self.label, area.width, .{}, area);
        }
    };
    var left = halves[0];
    try left.renderWidget(Custom{ .label = "Custom!" }, left.allocateRows(1));
    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.startsWith(u8, snap, "Custom!"));
}

test "ui flat widget helpers flow naturally with zero churn" {
    const alloc = testing.allocator;
    var buf = try Buffer.init(alloc, Rect.init(0, 0, 40, 14));
    defer buf.deinit();
    var scratch = std.heap.ArenaAllocator.init(alloc);
    defer scratch.deinit();
    var cursor: ?Position = null;
    const theme = Theme.nord;

    var ui = Ui.init(&buf, &theme, &scratch, &cursor, buf.area, 4);
    ui.header(.{ .title = "Demo", .right = "v0.1.0" }, null);
    try ui.panel(.{ .title = "Controls" }, Rect.init(0, 1, 40, 12), {}, struct {
        fn draw(_: void, p: *Ui) !void {
            try p.text("Flat flow text", .{}, null);
            p.checkbox(.{ .label = "Dark Mode", .checked = true }, null);
            try p.gauge(.{ .ratio = 0.6 }, null);
            try p.button(.{ .label = "Apply", .focused = true, .compact = true }, null);
        }
    }.draw);
    ui.statusBar(.{ .left = &.{.{ .text = "OK", .badge = true }} }, Rect.init(0, 13, 40, 1));

    const snap = try buf.toPlainTextAlloc(alloc);
    defer alloc.free(snap);
    try testing.expect(std.mem.indexOf(u8, snap, "Demo") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "Controls") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "[✓] Dark Mode") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "60%") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "Apply") != null);
    try testing.expect(std.mem.indexOf(u8, snap, "OK") != null);
}
