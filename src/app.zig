//! Application core for TUI.zig
//!
//! Provides the main application runner with event loop, rendering,
//! and widget management.

const std = @import("std");
const builtin = @import("builtin");

const terminal = @import("core/terminal.zig");
const screen_mod = @import("core/screen.zig");
const renderer_mod = @import("core/renderer.zig");
const platform = @import("platform/platform.zig");
const events = @import("event/events.zig");
const input = @import("event/input.zig");
const theme_mod = @import("style/theme.zig");
const widget = @import("widgets/widget.zig");
const animation = @import("animation/animation.zig");

pub const Screen = screen_mod.Screen;
pub const Renderer = renderer_mod.Renderer;
pub const Terminal = terminal.Terminal;
pub const Event = events.Event;
pub const Theme = theme_mod.Theme;
pub const RenderContext = widget.RenderContext;

/// Application configuration
pub const AppConfig = struct {
    /// Initial theme
    theme: Theme = Theme.default_theme,

    /// Enable alternate screen buffer
    alternate_screen: bool = true,

    /// Hide cursor
    hide_cursor: bool = true,

    /// Enable mouse input
    enable_mouse: bool = true,

    /// Enable bracketed paste
    enable_paste: bool = true,

    /// Enable focus events
    enable_focus: bool = true,

    /// Target frames per second
    target_fps: u16 = 60,

    /// Tick rate for animation (ms)
    tick_rate_ms: u16 = 16,

    /// Input poll timeout (ms)
    poll_timeout_ms: u16 = 10,
};

/// Application state
pub const AppState = enum {
    uninitialized,
    running,
    paused,
    stopping,
    stopped,
};

/// Main application struct
pub const App = struct {
    allocator: std.mem.Allocator,
    config: AppConfig,

    /// Terminal handler
    term: ?Terminal = null,

    /// Screen buffer
    screen: ?Screen = null,

    /// Renderer
    renderer: ?Renderer = null,

    /// Current theme
    theme: Theme,

    /// Application state
    state: AppState = .uninitialized,

    /// Root widget (type-erased)
    root: ?*anyopaque = null,
    root_render_fn: ?*const fn (*anyopaque, *RenderContext) void = null,
    root_event_fn: ?*const fn (*anyopaque, Event) widget.EventResult = null,

    /// Input reader
    input_reader: input.InputReader,

    /// Event queue
    event_queue: events.EventQueue,

    /// Time tracking
    start_time_ns: i128 = 0,
    last_frame_ns: i128 = 0,
    tick_count: u64 = 0,

    /// FPS tracking
    fps_counter: animation.FpsCounter = .{},

    /// Quit requested
    should_quit: bool = false,

    /// Needs redraw
    needs_redraw: bool = true,

    /// Create a new application
    pub fn init(config: AppConfig) !App {
        const allocator = std.heap.page_allocator;

        return App{
            .allocator = allocator,
            .config = config,
            .theme = config.theme,
            .input_reader = input.InputReader.init(allocator),
            .event_queue = events.EventQueue.init(allocator, 256),
        };
    }

    /// Create with custom allocator
    pub fn initWithAllocator(allocator: std.mem.Allocator, config: AppConfig) !App {
        return App{
            .allocator = allocator,
            .config = config,
            .theme = config.theme,
            .input_reader = input.InputReader.init(allocator),
            .event_queue = events.EventQueue.init(allocator, 256),
        };
    }

    /// Clean up resources
    pub fn deinit(self: *App) void {
        if (self.term) |*t| {
            t.deinit();
        }

        if (self.renderer) |*r| {
            r.deinit();
        }

        if (self.screen) |*s| {
            s.deinit();
        }

        self.event_queue.deinit();
        self.state = .stopped;
    }

    /// Set the root widget
    pub fn setRoot(self: *App, root_ptr: anytype) !void {
        const T = @TypeOf(root_ptr.*);

        self.root = @ptrCast(root_ptr);

        if (@hasDecl(T, "render")) {
            self.root_render_fn = @ptrCast(&struct {
                fn render(ptr: *anyopaque, ctx: *RenderContext) void {
                    const typed: *T = @ptrCast(@alignCast(ptr));
                    typed.render(ctx);
                }
            }.render);
        }

        if (@hasDecl(T, "handleEvent")) {
            self.root_event_fn = @ptrCast(&struct {
                fn handleEvent(ptr: *anyopaque, event: Event) widget.EventResult {
                    const typed: *T = @ptrCast(@alignCast(ptr));
                    return typed.handleEvent(event);
                }
            }.handleEvent);
        }
    }

    /// Set the theme
    pub fn setTheme(self: *App, theme: Theme) void {
        self.theme = theme;
        self.needs_redraw = true;
    }

    /// Request application quit
    pub fn quit(self: *App) void {
        self.should_quit = true;
    }

    /// Request redraw
    pub fn requestRedraw(self: *App) void {
        self.needs_redraw = true;
    }

    /// Run the application
    pub fn run(self: *App) !void {
        try self.setup();
        defer self.teardown();

        self.state = .running;
        self.start_time_ns = std.time.nanoTimestamp();
        self.last_frame_ns = self.start_time_ns;

        // Main loop
        while (self.state == .running and !self.should_quit) {
            try self.runFrame();
        }
    }

    /// Set up the application
    fn setup(self: *App) !void {
        // Initialize terminal
        self.term = try Terminal.init(.{
            .alternate_screen = self.config.alternate_screen,
            .hide_cursor = self.config.hide_cursor,
            .enable_mouse = self.config.enable_mouse,
            .enable_paste = self.config.enable_paste,
            .enable_focus = self.config.enable_focus,
        });

        // Get terminal size
        const size = try self.term.?.getSize();

        // Initialize screen buffer
        self.screen = try Screen.init(self.allocator, size.cols, size.rows);

        // Initialize renderer
        self.renderer = Renderer.init(self.allocator);

        self.state = .running;
    }

    /// Tear down the application
    fn teardown(self: *App) void {
        self.state = .stopping;
    }

    /// Run a single frame
    fn runFrame(self: *App) !void {
        const current_time = std.time.nanoTimestamp();
        const delta_ns = current_time - self.last_frame_ns;
        const delta_ms: u32 = @intCast(@divTrunc(delta_ns, 1_000_000));

        // Process input
        try self.processInput();

        // Process events
        self.processEvents();

        // Update animations and timers
        self.tick_count += 1;

        // Render if needed
        if (self.needs_redraw) {
            try self.render();
            self.needs_redraw = false;
        }

        // Update FPS counter
        self.fps_counter.update(delta_ms);

        // Frame timing
        self.last_frame_ns = current_time;

        // Sleep to maintain target FPS
        const frame_time_ns = @divTrunc(@as(i128, 1_000_000_000), @as(i128, self.config.target_fps));
        const elapsed_ns = std.time.nanoTimestamp() - current_time;

        if (elapsed_ns < frame_time_ns) {
            const sleep_ns: u64 = @intCast(frame_time_ns - elapsed_ns);
            std.Thread.sleep(sleep_ns);
        }
    }

    /// Process input from terminal
    fn processInput(self: *App) !void {
        // Read input (non-blocking would be ideal)
        // For now, we'll use a simple approach
        const stdin = if (builtin.os.tag == .windows)
            std.fs.File{ .handle = std.os.windows.GetStdHandle(std.os.windows.STD_INPUT_HANDLE) catch unreachable }
        else
            std.fs.File{ .handle = std.posix.STDIN_FILENO };
        var buf: [32]u8 = undefined;

        // Try to read with a timeout (platform-specific)
        const bytes_read = stdin.read(&buf) catch 0;

        if (bytes_read > 0) {
            // Parse input into events
            if (try self.input_reader.parse(buf[0..bytes_read])) |event| {
                try self.event_queue.push(event);
            }
        }
    }

    /// Process queued events
    fn processEvents(self: *App) void {
        while (self.event_queue.pop()) |event| {
            // Check for quit key (Ctrl+C or Ctrl+Q)
            if (event == .key) {
                const key_event = event.key;
                if (key_event.modifiers.ctrl) {
                    if (key_event.key == .char) {
                        const c = key_event.key.char;
                        if (c == 'c' or c == 'q' or c == 'C' or c == 'Q') {
                            self.should_quit = true;
                            return;
                        }
                    }
                }
            }

            // Handle resize
            if (event == .resize) {
                self.handleResize(event.resize) catch {};
            }

            // Pass to root widget
            if (self.root != null and self.root_event_fn != null) {
                const result = self.root_event_fn.?(self.root.?, event);
                if (result == .needs_redraw) {
                    self.needs_redraw = true;
                }
            }
        }
    }

    /// Handle terminal resize
    fn handleResize(self: *App, resize: events.ResizeEvent) !void {
        if (self.screen) |*scr| {
            try scr.resize(resize.cols, resize.rows);
        }

        if (self.renderer) |*rend| {
            rend.invalidate();
        }

        self.needs_redraw = true;
    }

    /// Render the UI
    fn render(self: *App) !void {
        if (self.screen == null or self.renderer == null) return;

        var scr = &self.screen.?;

        // Clear screen
        scr.clear();

        // Create render context
        var ctx = RenderContext{
            .screen = scr,
            .theme = &self.theme,
            .bounds = .{
                .x = 0,
                .y = 0,
                .width = scr.width,
                .height = scr.height,
            },
            .clip = .{
                .x = 0,
                .y = 0,
                .width = scr.width,
                .height = scr.height,
            },
            .focused_id = null,
            .time_ns = @intCast(std.time.nanoTimestamp() - self.start_time_ns),
        };

        // Render root widget
        if (self.root != null and self.root_render_fn != null) {
            self.root_render_fn.?(self.root.?, &ctx);
        }

        // Render to terminal
        try self.renderer.?.render(scr);
    }

    /// Get current FPS
    pub fn getFps(self: *App) f32 {
        return self.fps_counter.getFps();
    }

    /// Get elapsed time since start
    pub fn getElapsedTime(self: *App) u64 {
        const ns = std.time.nanoTimestamp() - self.start_time_ns;
        return @intCast(@divTrunc(ns, 1_000_000));
    }

    /// Get tick count
    pub fn getTickCount(self: *App) u64 {
        return self.tick_count;
    }

    /// Get screen dimensions
    pub fn getScreenSize(self: *App) struct { width: u16, height: u16 } {
        if (self.screen) |scr| {
            return .{ .width = scr.width, .height = scr.height };
        }
        return .{ .width = 80, .height = 24 };
    }
};

/// Simple runner for quick applications
pub fn run(comptime RootWidget: type, initial_state: RootWidget) !void {
    var state = initial_state;
    var app = try App.init(.{});
    defer app.deinit();

    try app.setRoot(&state);
    try app.run();
}

test "app creation" {
    var app = try App.init(.{});
    defer app.deinit();

    try std.testing.expect(app.state == .uninitialized);
}
