//! Centralized `App` application & terminal runtime managing session lifecycle,
//! double-buffered diff rendering, window title/metadata, event parsing, frame timing,
//! and reusable allocator-owned snapshots.

const std = @import("std");
const core_root = @import("../core/root.zig");
const style_root = @import("../style/root.zig");
const event_root = @import("../event/root.zig");
const backend_root = @import("../backend/root.zig");
const widgets_root = @import("../widgets/root.zig");
const testing = std.testing;

pub const AppInfo = core_root.AppInfo;
pub const AppOptions = core_root.AppOptions;
pub const Viewport = core_root.Viewport;
pub const Buffer = core_root.Buffer;
pub const Theme = style_root.Theme;
pub const Rect = core_root.Rect;
pub const Size = core_root.Size;
pub const Position = core_root.Position;
pub const CursorShape = core_root.CursorShape;
pub const Ui = core_root.Ui;
pub const Backend = backend_root.Backend;
pub const TerminalCapabilities = backend_root.TerminalCapabilities;
pub const Event = event_root.Event;
pub const EventParser = event_root.EventParser;

/// Primary application and terminal runtime created by `tui.init(allocator, options)`.
///
/// Owns all rendering buffers (`front`/`back`), scratch arena, ANSI staging, snapshot cache,
/// event parser, window title state, and backend handles tied to the single `allocator`
/// passed to `tui.init(...)`. Call `defer app.deinit();` immediately after initialization
/// to guarantee full terminal restoration and zero memory leaks.
pub const App = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    app_info: AppInfo,
    options: AppOptions,
    viewport: Viewport,
    viewport_area: Rect,
    theme: Theme,
    backend: Backend,
    front: Buffer,
    back: Buffer,
    out_staging: std.ArrayList(u8) = .empty,
    snapshot_buf: std.ArrayList(u8) = .empty,
    parser: EventParser,
    scratch_arena: std.heap.ArenaAllocator,
    window_title_buf: [256]u8 = @splat(0),
    window_title_len: usize = 0,
    cursor_request: ?Position = null,
    cursor_pos: ?Position = null,
    last_cursor_visible: bool = true,
    entered: bool = false,
    should_quit: bool = false,
    frame_count: u64 = 0,
    tick_count: u64 = 0,
    delta_ms: u32 = 16,
    elapsed_ms: u64 = 0,
    last_clock_ns: ?i96 = null,

    /// Initializes the unified `App` with explicit `allocator` and typed `options`.
    /// Validates `options` via `zigantic` before allocating backend and double buffers.
    pub fn init(allocator: std.mem.Allocator, options: AppOptions) !App {
        try options.validate();
        const io = options.io orelse std.Options.debug_io;

        var backend = try Backend.init(allocator, io, options.backend, options.capability);
        errdefer backend.deinit();

        const term_size = try backend.size();
        const vp_area = computeViewportArea(term_size, options.viewport);

        var front = try Buffer.init(allocator, vp_area);
        errdefer front.deinit();
        var back = try Buffer.init(allocator, vp_area);
        errdefer back.deinit();

        var app_inst = App{
            .allocator = allocator,
            .io = io,
            .app_info = options.app,
            .options = options,
            .viewport = options.viewport,
            .viewport_area = vp_area,
            .theme = options.theme,
            .backend = backend,
            .front = front,
            .back = back,
            .parser = EventParser.init(allocator),
            .scratch_arena = std.heap.ArenaAllocator.init(allocator),
        };
        const init_title = options.resolvedTitle() orelse options.app.effectiveTitle();
        const n = @min(init_title.len, app_inst.window_title_buf.len);
        @memcpy(app_inst.window_title_buf[0..n], init_title[0..n]);
        app_inst.window_title_len = n;
        if (options.resolvedTitle() != null) {
            app_inst.app_info.title = app_inst.window_title_buf[0..n];
        }
        return app_inst;
    }

    /// Restores terminal state (if entered) and frees all owned buffers and caches. Idempotent.
    pub fn deinit(self: *App) void {
        self.restore();
        self.snapshot_buf.deinit(self.allocator);
        self.out_staging.deinit(self.allocator);
        self.scratch_arena.deinit();
        self.parser.deinit();
        self.front.deinit();
        self.back.deinit();
        self.backend.deinit();
    }

    fn computeViewportArea(term_size: Size, viewport: Viewport) Rect {
        return switch (viewport) {
            .fullscreen => Rect.fromPosSize(.origin, term_size),
            .inline_height => |h| blk: {
                const clamped_h = @min(h, term_size.height);
                const start_y = term_size.height -| clamped_h;
                break :blk Rect.init(0, start_y, term_size.width, clamped_h);
            },
            .fixed => |rect| rect.clamp(Rect.fromPosSize(.origin, term_size)),
        };
    }

    /// Enters interactive terminal mode (raw mode, alternate screen, mouse, paste, title, cursor).
    /// Idempotent: calling `enter()` when already entered is a no-op.
    pub fn enter(self: *App) !void {
        if (self.entered) return;
        var enter_opts = self.options.enterOptions();
        if (self.app_info.title) |t| enter_opts.title = t;
        try self.backend.enter(enter_opts);
        self.entered = true;
        if (self.options.cursor_shape) |shape| {
            try self.setCursorShape(shape);
        }
    }

    /// Restores the terminal back to its original pre-application state. Idempotent.
    pub fn restore(self: *App) void {
        if (!self.entered) return;
        self.backend.restore();
        self.entered = false;
    }

    /// True while interactive terminal session mode is entered.
    pub fn isEntered(self: *const App) bool {
        return self.entered;
    }

    /// Returns metadata bound to this `App` instance (`name`, `version`, `description`, `author`, `title`).
    pub fn info(self: *const App) AppInfo {
        return self.app_info;
    }

    /// Updates `AppInfo` metadata on this instance and updates the live window title if set.
    pub fn setInfo(self: *App, next_info: AppInfo) !void {
        self.app_info = next_info;
        try self.setTitle(next_info.effectiveTitle());
    }

    /// Returns the active terminal window title associated with this `App` instance.
    pub fn title(self: *const App) []const u8 {
        if (self.window_title_len > 0) return self.window_title_buf[0..self.window_title_len];
        return self.app_info.effectiveTitle();
    }

    /// Updates the live terminal window/tab title (`OSC 0` + Win32 `SetConsoleTitleW` + headless record).
    pub fn setTitle(self: *App, next_title: []const u8) !void {
        const n = @min(next_title.len, self.window_title_buf.len);
        @memcpy(self.window_title_buf[0..n], next_title[0..n]);
        self.window_title_len = n;
        self.app_info.title = self.window_title_buf[0..n];
        try self.backend.setTitle(self.window_title_buf[0..n]);
    }

    /// Returns detected/active terminal capabilities (`color`, `unicode`, `mouse`, `image_protocol`, etc.).
    pub fn capabilities(self: *const App) TerminalCapabilities {
        return self.backend.capabilities();
    }

    /// Sets the terminal hardware cursor shape (`DECSCUSR`). Restored to default automatically on exit.
    pub fn setCursorShape(self: *App, shape: CursorShape) !void {
        try self.backend.setCursorShape(shape);
    }

    /// Clears the terminal screen and invalidates the front buffer so the next frame redraws everything.
    pub fn clear(self: *App) !void {
        try self.backend.clear(.all);
        self.front.clear();
        self.back.clear();
    }

    /// Signals `run()` / `isRunning()` loops to terminate cleanly.
    pub fn quit(self: *App) void {
        self.should_quit = true;
    }

    /// True while the application has not been signaled to quit.
    pub fn isRunning(self: *const App) bool {
        return !self.should_quit;
    }

    /// Replaces the active `Theme` used by subsequent frames.
    pub fn setTheme(self: *App, next_theme: Theme) void {
        self.theme = next_theme;
    }

    /// Current terminal viewport rectangle.
    pub fn area(self: *const App) Rect {
        return self.viewport_area;
    }

    /// Current terminal dimensions.
    pub fn size(self: *const App) Size {
        return self.viewport_area.size();
    }

    /// Last rendered hardware cursor coordinate (or `null` when hidden).
    pub fn cursorPos(self: *const App) ?Position {
        return self.cursor_pos;
    }

    /// Total frames flushed by this `App` instance.
    pub fn frameCount(self: *const App) u64 {
        return self.frame_count;
    }

    /// Checks whether backend dimensions changed and resizes internal buffers if needed.
    pub fn syncSize(self: *App) !?Size {
        const term_size = try self.backend.size();
        const next_area = computeViewportArea(term_size, self.viewport);
        if (next_area.eql(self.viewport_area)) return null;

        try self.resizeBuffers(next_area);
        return term_size;
    }

    fn resizeBuffers(self: *App, new_area: Rect) !void {
        self.viewport_area = new_area;
        try self.front.resize(new_area);
        try self.back.resize(new_area);
        if (self.viewport == .fullscreen) {
            try self.backend.clear(.all);
        }
    }

    /// Begins a new frame: resets per-frame scratch retaining capacity, synchronizes
    /// terminal dimensions, clears the back buffer, and returns a `Ui` bound to this `App`.
    pub fn beginFrame(self: *App) !Ui {
        _ = self.scratch_arena.reset(.retain_capacity);
        self.cursor_request = null;
        _ = try self.syncSize();
        self.back.clear();
        self.cursor_pos = null;

        var info_copy = self.app_info;
        info_copy.title = self.title();

        var ui = Ui.initWithApp(
            &self.back,
            &self.theme,
            &self.scratch_arena,
            &self.cursor_request,
            self.viewport_area,
            self.options.settings.tab_size,
            info_copy,
        );
        ui.fillThemeSurface();
        return ui;
    }

    /// Flushes the completed frame diff to the backend, updates cursor state,
    /// and swaps buffers cleanly.
    pub fn endFrame(self: *App, ui: *Ui) !void {
        _ = ui;
        var diff = self.back.diff(&self.front);
        try self.backend.drawDiff(self.allocator, &self.out_staging, &diff, self.options.settings.synchronized_output);

        if (self.cursor_request) |pos| {
            try self.backend.setCursor(pos, true);
            self.last_cursor_visible = true;
            self.cursor_pos = pos;
        } else if (self.last_cursor_visible) {
            try self.backend.setCursor(.origin, false);
            self.last_cursor_visible = false;
        }

        const tmp = self.front;
        self.front = self.back;
        self.back = tmp;

        self.frame_count += 1;
    }

    /// Executes `render_fn(ctx, &ui)` inside a managed `beginFrame` / `endFrame` transaction.
    pub fn draw(self: *App, ctx: anytype, comptime render_fn: anytype) !void {
        var ui = try self.beginFrame();
        const fn_info = @typeInfo(@TypeOf(render_fn)).@"fn";
        const ret_is_err = @typeInfo(fn_info.return_type.?) == .error_union;
        if (ret_is_err) try render_fn(ctx, &ui) else render_fn(ctx, &ui);
        try self.endFrame(&ui);
    }

    /// Inserts `height` rows rendered by `draw_fn(ctx, *Buffer)` above an `.inline_height` viewport.
    pub fn insertBefore(
        self: *App,
        height: u16,
        ctx: anytype,
        comptime draw_fn: anytype,
    ) !void {
        if (self.viewport != .inline_height or height == 0 or self.viewport_area.width == 0) return;
        const area_rect = Rect.init(0, 0, self.viewport_area.width, height);
        var buf = try Buffer.init(self.allocator, area_rect);
        defer buf.deinit();

        const fn_info = @typeInfo(@TypeOf(draw_fn)).@"fn";
        const ret_is_err = @typeInfo(fn_info.return_type.?) == .error_union;
        if (ret_is_err) try draw_fn(ctx, &buf) else draw_fn(ctx, &buf);

        try self.backend.insertBufferBefore(self.allocator, &self.out_staging, &buf, self.viewport_area);
    }

    /// Dynamically resizes an `.inline_height` viewport.
    pub fn setViewportHeight(self: *App, new_height: u16) !void {
        switch (self.viewport) {
            .inline_height => |*h| {
                if (h.* == new_height) return;
                h.* = new_height;
                const term_size = try self.backend.size();
                const next_area = computeViewportArea(term_size, self.viewport);
                try self.clear();
                try self.resizeBuffers(next_area);
            },
            else => {},
        }
    }

    /// Polls for an input/resize event up to `timeout_ms` (`-1` blocks, `0` non-blocking).
    pub fn pollEvent(self: *App, timeout_ms: i32) !Event {
        return try self.backend.pollEvent(&self.parser, timeout_ms);
    }

    /// Reads the next input/resize event, blocking until one arrives.
    pub fn nextEvent(self: *App) !Event {
        return self.pollEvent(-1);
    }

    /// Configured target frame interval in milliseconds based on `settings.fps`.
    pub fn targetFrameMs(self: *const App) u32 {
        return @intCast(@max(@as(u16, 1), 1000 / @max(@as(u16, 1), self.options.settings.fps)));
    }

    /// Last frame delta in milliseconds.
    pub fn deltaMs(self: *const App) u32 {
        return self.delta_ms;
    }

    /// Last frame delta in seconds.
    pub fn deltaSeconds(self: *const App) f64 {
        return @as(f64, @floatFromInt(self.delta_ms)) / 1000.0;
    }

    /// Total elapsed runtime across animation ticks in milliseconds.
    pub fn elapsedMs(self: *const App) u64 {
        return self.elapsed_ms;
    }

    /// Total elapsed runtime across animation ticks in seconds.
    pub fn elapsedSeconds(self: *const App) f64 {
        return @as(f64, @floatFromInt(self.elapsed_ms)) / 1000.0;
    }

    /// Total number of `.tick` intervals emitted by `run()` or `advanceTimer()`.
    pub fn tickCount(self: *const App) u64 {
        return self.tick_count;
    }

    /// Updates `delta_ms`, `elapsed_ms`, and `tick_count` from the monotonic clock for custom loops.
    pub fn advanceTimer(self: *App) u32 {
        const now_ns = std.Io.Clock.awake.now(self.io).nanoseconds;
        const frame_ms = self.targetFrameMs();
        const measured_ms: u32 = if (self.last_clock_ns) |prev| blk: {
            const diff_ns = @max(@as(i96, 0), now_ns - prev);
            const raw_ms = @divTrunc(diff_ns, std.time.ns_per_ms);
            break :blk @intCast(std.math.clamp(raw_ms, @as(i96, 0), @as(i96, 250)));
        } else frame_ms;
        self.last_clock_ns = now_ns;
        self.delta_ms = if (self.backend == .memory) @max(frame_ms, measured_ms) else @max(@as(u32, 1), measured_ms);
        self.elapsed_ms +|= self.delta_ms;
        self.tick_count +%= 1;
        return self.delta_ms;
    }

    /// Sleeps for up to one configured frame interval in custom loops without `run()`.
    pub fn sleepFrame(self: *const App) void {
        if (self.backend == .memory) return;
        std.Io.sleep(self.io, std.Io.Duration.fromMilliseconds(self.targetFrameMs()), .awake) catch {};
    }

    fn dispatchEvent(self: *App, state: anytype, ev: Event, comptime callbacks: anytype) !void {
        const CbT = @TypeOf(callbacks);
        if (@hasField(CbT, "onEvent")) {
            const ev_fn = callbacks.onEvent;
            const e_info = @typeInfo(@TypeOf(ev_fn)).@"fn";
            const ret_info = @typeInfo(e_info.return_type.?);
            const keep_going = switch (ret_info) {
                .error_union => |eu| blk: {
                    if (eu.payload == bool) break :blk try ev_fn(state, ev, self);
                    try ev_fn(state, ev, self);
                    break :blk true;
                },
                .bool => ev_fn(state, ev, self),
                else => blk: {
                    ev_fn(state, ev, self);
                    break :blk true;
                },
            };
            if (!keep_going) self.quit();
        } else {
            if (ev.isCtrlC() or ev.isEscape()) self.quit();
        }
    }

    /// Managed application loop: enters terminal, guarantees restoration on return,
    /// renders frames at `settings.fps`, emits real periodic `.tick` events, and exits cleanly.
    pub fn run(self: *App, state: anytype, comptime callbacks: anytype) !void {
        try self.enter();
        defer self.restore();

        const render_fn = callbacks.render;
        const r_info = @typeInfo(@TypeOf(render_fn)).@"fn";
        const frame_ms: i32 = @intCast(self.targetFrameMs());
        self.last_clock_ns = std.Io.Clock.awake.now(self.io).nanoseconds;

        while (self.isRunning()) {
            var ui = try self.beginFrame();
            if (@typeInfo(r_info.return_type.?) == .error_union) {
                try render_fn(state, &ui);
            } else {
                render_fn(state, &ui);
            }
            try self.endFrame(&ui);

            const now_before_poll = std.Io.Clock.awake.now(self.io).nanoseconds;
            const since_last_ms: i64 = if (self.last_clock_ns) |prev|
                @intCast(@max(@as(i96, 0), @divTrunc(now_before_poll - prev, std.time.ns_per_ms)))
            else
                0;
            const wait_ms: i32 = if (since_last_ms >= frame_ms) 0 else @intCast(@as(i64, frame_ms) - since_last_ms);

            const ev = try self.pollEvent(wait_ms);
            if (ev == .none) {
                _ = self.advanceTimer();
                try self.dispatchEvent(state, .tick, callbacks);
            } else {
                try self.dispatchEvent(state, ev, callbacks);
                if (self.isRunning()) {
                    const now_after = std.Io.Clock.awake.now(self.io).nanoseconds;
                    const after_ms: i64 = if (self.last_clock_ns) |prev|
                        @intCast(@max(@as(i96, 0), @divTrunc(now_after - prev, std.time.ns_per_ms)))
                    else
                        frame_ms;
                    if (after_ms >= frame_ms) {
                        _ = self.advanceTimer();
                        try self.dispatchEvent(state, .tick, callbacks);
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Allocator-reusing factories bound to this `App` instance
    // -------------------------------------------------------------------------

    /// Creates an empty `TextInputState` bound to `self.allocator`.
    pub fn textInput(self: *const App) widgets_root.TextInputState {
        return widgets_root.TextInputState.init(self.allocator);
    }

    /// Creates a pre-filled `TextInputState` bound to `self.allocator`.
    pub fn textInputWith(self: *const App, initial: []const u8) !widgets_root.TextInputState {
        return widgets_root.TextInputState.initWithText(self.allocator, initial);
    }

    /// Creates an empty `TextAreaState` bound to `self.allocator`.
    pub fn textArea(self: *const App) widgets_root.TextAreaState {
        return widgets_root.TextAreaState.init(self.allocator);
    }

    /// Creates a pre-filled `TextAreaState` bound to `self.allocator`.
    pub fn textAreaWith(self: *const App, initial: []const u8) !widgets_root.TextAreaState {
        return widgets_root.TextAreaState.initWithText(self.allocator, initial);
    }

    /// Creates a `TreeState` bound to `self.allocator`.
    pub fn treeState(self: *const App) widgets_root.TreeState {
        return widgets_root.TreeState.init(self.allocator);
    }

    /// Creates a `CommandPaletteState` bound to `self.allocator`.
    pub fn commandPalette(self: *const App) widgets_root.CommandPaletteState {
        return widgets_root.CommandPaletteState.init(self.allocator);
    }

    // -------------------------------------------------------------------------
    // Headless testing & reusable snapshot API
    // -------------------------------------------------------------------------

    /// Pushes a synthetic event into a `.memory` backend for deterministic tests.
    pub fn pushTestEvent(self: *App, ev: Event) !void {
        switch (self.backend) {
            .memory => |*m| try m.pushEvent(ev),
            else => return error.UnsupportedBackend,
        }
    }

    /// Resizes a `.memory` backend for testing responsive layouts.
    pub fn resizeTest(self: *App, new_size: Size) !void {
        switch (self.backend) {
            .memory => |*m| try m.resize(new_size),
            else => return error.UnsupportedBackend,
        }
    }

    /// Returns scrollback rows recorded via `insertBefore` when running on `.memory` backend.
    pub fn scrollback(self: *const App) []const u8 {
        return switch (self.backend) {
            .memory => |*m| m.scrollbackSlice(),
            else => "",
        };
    }

    /// Captures a plain-text snapshot of the rendered screen into a reusable buffer owned
    /// by this `App` instance (freed automatically on `app.deinit()`, zero caller `free` required).
    pub fn snapshot(self: *App) ![]const u8 {
        switch (self.backend) {
            .memory => |*m| return try m.snapshot(),
            else => {
                try self.front.writePlainText(self.allocator, &self.snapshot_buf);
                return self.snapshot_buf.items;
            },
        }
    }
};

test "app init, frame lifecycle, app info, title, and reusable snapshots work cleanly" {
    var app = try App.init(testing.allocator, .{
        .app = .{
            .name = "MyTUI",
            .version = "2.1.0",
            .title = "Initial Window",
        },
        .io = testing.io,
        .backend = .{ .memory = Size.init(36, 4) },
    });
    defer app.deinit();

    try testing.expectEqualStrings("MyTUI", app.info().name);
    try testing.expectEqualStrings("2.1.0", app.info().version);
    try testing.expectEqualStrings("Initial Window", app.title());

    try app.enter();
    try testing.expectEqualStrings("Initial Window", app.backend.memory.titleSlice());
    try app.setTitle("Live Updated Title");
    try testing.expectEqualStrings("Live Updated Title", app.title());
    try testing.expectEqualStrings("Live Updated Title", app.backend.memory.titleSlice());

    try app.pushTestEvent(.{ .key = .{ .code = .escape } });
    var state: u32 = 0;
    try app.run(&state, .{
        .render = struct {
            fn r(count: *u32, ui: *Ui) void {
                count.* += 1;
                _ = ui.buffer.setString(1, 1, ui.app.name, ui.theme.text);
                _ = ui.buffer.setString(7, 1, ui.app.version, ui.theme.muted);
            }
        }.r,
        .onEvent = struct {
            fn on(_: *u32, ev: Event, a: *App) void {
                if (ev.isEscape()) a.quit();
            }
        }.on,
    });
    try testing.expectEqual(@as(u32, 1), state);
    const snap = try app.snapshot();
    try testing.expect(std.mem.indexOf(u8, snap, "MyTUI 2.1.0") != null);

    var inp = app.textInput();
    defer inp.deinit();
    try inp.setText("reused");
    try testing.expectEqualStrings("reused", inp.text());
}

test "app inline viewport insertBefore and setViewportHeight" {
    var app = try App.init(testing.allocator, .{
        .io = testing.io,
        .backend = .{ .memory = Size.init(20, 10) },
        .viewport = .{ .inline_height = 4 },
    });
    defer app.deinit();

    try app.insertBefore(1, {}, struct {
        fn log(_: void, buf: *core_root.Buffer) void {
            _ = buf.setString(0, 0, "Log: started", .{});
        }
    }.log);
    try app.setViewportHeight(6);
    try testing.expectEqual(@as(u16, 6), app.area().height);
    try testing.expect(std.mem.indexOf(u8, app.scrollback(), "Log: started") != null);
}

test "app applies configured cursor shape on enter and resets on restore" {
    var app = try App.init(testing.allocator, .{
        .io = testing.io,
        .backend = .{ .memory = Size.init(20, 4) },
        .cursor_shape = .blinking_bar,
    });
    defer app.deinit();

    try app.enter();
    try testing.expectEqual(CursorShape.blinking_bar, app.backend.memory.cursor_shape);
    try app.setCursorShape(.steady_underline);
    try testing.expectEqual(CursorShape.steady_underline, app.backend.memory.cursor_shape);
    app.restore();
    try testing.expectEqual(CursorShape.default_shape, app.backend.memory.cursor_shape);
}

test "app init cleans up cleanly on OOM without double-free and run emits ticks" {
    const OomCtx = struct {
        fn attempt(alloc: std.mem.Allocator) !void {
            var a = try App.init(alloc, .{
                .io = testing.io,
                .backend = .{ .memory = Size.init(20, 4) },
            });
            a.deinit();
        }
    };
    try testing.checkAllAllocationFailures(testing.allocator, OomCtx.attempt, .{});

    var app = try App.init(testing.allocator, .{
        .io = testing.io,
        .backend = .{ .memory = Size.init(20, 4) },
        .settings = .{ .fps = 60 },
    });
    defer app.deinit();

    var ticks_seen: usize = 0;
    try app.run(&ticks_seen, .{
        .render = struct {
            fn r(_: *usize, ui: *Ui) void {
                _ = ui.buffer.setString(0, 0, "TickLoop", ui.theme.text);
            }
        }.r,
        .onEvent = struct {
            fn on(ticks: *usize, ev: Event, _: *App) bool {
                if (ev == .tick) ticks.* += 1;
                return ticks.* < 3;
            }
        }.on,
    });
    try testing.expectEqual(@as(usize, 3), ticks_seen);
    try testing.expect(app.elapsedMs() > 0);
}
