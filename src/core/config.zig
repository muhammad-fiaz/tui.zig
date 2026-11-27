//! Single-source `zigantic` schema definitions with `z.withDefault` for runtime,
//! terminal session, and JSON theme configuration.
//!
//! Instead of maintaining duplicate parallel config/model structs, every
//! validated configuration type here is synthesized directly by `zigantic`'s
//! `objectOf` and `withDefault` combinators.

const std = @import("std");
const z = @import("zigantic");
const geom = @import("geometry.zig");
const style_root = @import("../style/root.zig");
const testing = std.testing;

pub const Rect = geom.Rect;
pub const Theme = style_root.Theme;
pub const Capability = style_root.Capability;

/// Viewport rendering mode for `App`.
pub const Viewport = union(enum) {
    /// Uses the full terminal dimensions (typically with alternate screen).
    fullscreen,
    /// Renders an inline area of `height` rows anchored below scrollback output.
    inline_height: u16,
    /// Renders strictly inside a caller-chosen rectangular region.
    fixed: Rect,
};

/// Client application identity and window metadata bound to an `App` instance.
pub const AppInfo = struct {
    /// Application display name (exposed to UI components and fallback window title).
    name: []const u8 = "tui.zig",
    /// Client application version string (for headers, status bars, and diagnostics).
    version: []const u8 = "0.1.0",
    /// Short application summary or tagline.
    description: []const u8 = "",
    /// Maintainer or organization name.
    author: []const u8 = "",
    /// Optional explicit terminal window/tab title (`null` falls back to `name` when applied).
    title: ?[]const u8 = null,

    /// Resolves the window/brand title (`title` if set, otherwise `name`).
    pub fn effectiveTitle(self: AppInfo) []const u8 {
        return self.title orelse self.name;
    }
};

/// Terminal hardware cursor shape (`DECSCUSR`).
pub const CursorShape = enum(u8) {
    /// Reset to user's terminal default cursor shape (`CSI 0 SP q`).
    default_shape = 0,
    blinking_block = 1,
    steady_block = 2,
    blinking_underline = 3,
    steady_underline = 4,
    blinking_bar = 5,
    steady_bar = 6,
};

/// Backend driver selection.
pub const BackendMode = union(enum) {
    /// Automatically chooses Windows Console or POSIX TTY when interactive,
    /// or falls back cleanly when stdout is not a TTY.
    auto,
    /// Native POSIX termios + ANSI/VT sequences.
    posix,
    /// Native Windows Console API + VT sequences.
    windows,
    /// Pure ANSI/VT writer over provided or standard handles without OS mode mutation.
    ansi,
    /// Headless in-memory buffer backend for automated tests and snapshot rendering.
    memory: geom.Size,
};

/// Single-source schema for interactive terminal session flags shared across
/// `Backend`, `PosixBackend`, and `WindowsBackend`.
pub const EnterOptionsSchema = z.objectOf(.{
    .raw_mode = z.withDefault(z.boolean(.{}), true),
    .alternate_screen = z.withDefault(z.boolean(.{}), true),
    .mouse = z.withDefault(z.boolean(.{}), false),
    .bracketed_paste = z.withDefault(z.boolean(.{}), true),
    .focus_events = z.withDefault(z.boolean(.{}), false),
    .hide_cursor = z.withDefault(z.boolean(.{}), true),
    .title = z.withDefault(z.nullable(z.string(.{ .max = 256 })), null),
}, .{});

/// Typed session entry options synthesized with `zigantic.withDefault`.
pub const EnterOptions = EnterOptionsSchema.Value;

/// Single-source validated schema for serializable `App` runtime settings.
pub const AppSettingsSchema = z.objectOf(.{
    .alternate_screen = z.withDefault(z.boolean(.{}), true),
    .raw_mode = z.withDefault(z.boolean(.{}), true),
    .mouse = z.withDefault(z.boolean(.{}), false),
    .bracketed_paste = z.withDefault(z.boolean(.{}), true),
    .focus_events = z.withDefault(z.boolean(.{}), false),
    .hide_cursor = z.withDefault(z.boolean(.{}), true),
    .synchronized_output = z.withDefault(z.boolean(.{}), true),
    .title = z.withDefault(z.nullable(z.string(.{ .max = 256 })), null),
    .fps = z.withDefault(z.integer(u16, .{ .min = 1, .max = 240 }), 60),
    .tab_size = z.withDefault(z.integer(u8, .{ .min = 1, .max = 16 }), 4),
}, .{});

/// Runtime behavioral configuration synthesized with `zigantic.withDefault`.
pub const AppSettings = AppSettingsSchema.Value;

/// Complete client options passed to `tui.init(allocator, options)`.
pub const AppOptions = struct {
    /// Client application metadata & initial window title bound to this `App` instance.
    app: AppInfo = .{},
    /// Optional `std.Io` instance (for example `init.io` from `std.process.Init`).
    /// Defaults to `std.Options.debug_io` when omitted.
    io: ?std.Io = null,
    /// Backend selection (`auto` by default).
    backend: BackendMode = .auto,
    /// Viewport mode (`.fullscreen` by default).
    viewport: Viewport = .fullscreen,
    /// Color capability override (`null` enables automatic capability detection).
    capability: ?Capability = null,
    /// Active UI theme (defaults to `Theme.dark`).
    theme: Theme = Theme.dark,
    /// Optional hardware cursor shape applied on session entry (`null` leaves terminal default).
    cursor_shape: ?CursorShape = null,
    /// Schema-validated runtime behavioral flags (`fps`, `tab_size`, `mouse`, etc.).
    settings: AppSettings = .{},

    /// Parses JSON bytes into validated `AppOptions` applying `z.withDefault` for omitted keys.
    pub fn parseSettingsJson(allocator: std.mem.Allocator, json_bytes: []const u8) !AppSettings {
        var parsed = try z.parse(AppSettingsSchema, allocator, json_bytes, .{});
        defer parsed.deinit();
        return parsed.value orelse return error.InvalidConfiguration;
    }

    /// Resolves effective session window title if explicitly set in `settings.title` or `app.title`.
    pub fn resolvedTitle(self: AppOptions) ?[]const u8 {
        return self.settings.title orelse self.app.title;
    }

    /// Builds `EnterOptions` directly from `self.settings` and `self.app`.
    pub fn enterOptions(self: AppOptions) EnterOptions {
        return .{
            .raw_mode = self.settings.raw_mode,
            .alternate_screen = self.settings.alternate_screen,
            .mouse = self.settings.mouse,
            .bracketed_paste = self.settings.bracketed_paste,
            .focus_events = self.settings.focus_events,
            .hide_cursor = self.settings.hide_cursor,
            .title = self.resolvedTitle(),
        };
    }

    /// Validates numeric and string bounds directly against `AppSettingsSchema` on stack memory.
    pub fn validate(self: AppOptions) error{InvalidConfiguration}!void {
        var scratch: [1024]u8 = undefined;
        const issue = z.checkFirst(AppSettingsSchema, self.settings, &scratch, .{}) catch return error.InvalidConfiguration;
        if (issue != null) return error.InvalidConfiguration;
    }
};

/// Single-source `zigantic` schema for JSON theme definitions with semantic defaults.
pub const ThemeSpecSchema = z.objectOf(.{
    .name = z.withDefault(z.string(.{ .min = 1, .max = 64 }), "custom"),
    .primary = z.withDefault(z.hexColor(.{}), "#38bdf8"),
    .secondary = z.withDefault(z.hexColor(.{}), "#818cf8"),
    .success = z.withDefault(z.hexColor(.{}), "#22c55e"),
    .warning = z.withDefault(z.hexColor(.{}), "#eab308"),
    .err = z.withDefault(z.hexColor(.{}), "#ef4444"),
    .info = z.withDefault(z.hexColor(.{}), "#06b6d4"),
    .text = z.withDefault(z.hexColor(.{}), "#f8fafc"),
    .muted = z.withDefault(z.hexColor(.{}), "#94a3b8"),
    .background = z.withDefault(z.hexColor(.{}), "#0f172a"),
    .surface = z.withDefault(z.hexColor(.{}), "#1e293b"),
}, .{});

/// Synthesized JSON theme spec type (zero separate model duplication).
pub const ThemeSpec = ThemeSpecSchema.Value;

/// Parses and validates a JSON theme definition via `zigantic` (filling omitted colors from
/// `z.withDefault`) and converts it into a `Theme`.
pub fn parseThemeJson(allocator: std.mem.Allocator, json_bytes: []const u8) !Theme {
    var result = try z.parse(ThemeSpecSchema, allocator, json_bytes, .{});
    defer result.deinit();

    const spec = result.value orelse return error.InvalidThemeJson;
    const base = style_root.theme.TintTheme.create(spec.name, .{
        .primary = (style_root.Color.parse(spec.primary) orelse return error.InvalidThemeJson).toTint().?,
        .secondary = (style_root.Color.parse(spec.secondary) orelse return error.InvalidThemeJson).toTint().?,
        .success = (style_root.Color.parse(spec.success) orelse return error.InvalidThemeJson).toTint().?,
        .warning = (style_root.Color.parse(spec.warning) orelse return error.InvalidThemeJson).toTint().?,
        .err = (style_root.Color.parse(spec.err) orelse return error.InvalidThemeJson).toTint().?,
        .info = (style_root.Color.parse(spec.info) orelse return error.InvalidThemeJson).toTint().?,
        .text = (style_root.Color.parse(spec.text) orelse return error.InvalidThemeJson).toTint().?,
        .muted = (style_root.Color.parse(spec.muted) orelse return error.InvalidThemeJson).toTint().?,
        .background = (style_root.Color.parse(spec.background) orelse return error.InvalidThemeJson).toTint().?,
        .surface = (style_root.Color.parse(spec.surface) orelse return error.InvalidThemeJson).toTint().?,
    });
    return Theme.fromTint(base);
}

/// Exposes `zigantic` string format validators cleanly for interactive form/input widgets.
pub const validators = z.validators;

test "AppOptions and AppSettingsSchema defaults + validation via zigantic" {
    const valid: AppOptions = .{};
    try valid.validate();
    try testing.expectEqual(@as(u16, 60), valid.settings.fps);
    try testing.expectEqual(@as(u8, 4), valid.settings.tab_size);

    const parsed = try AppOptions.parseSettingsJson(testing.allocator, "{\"fps\": 30, \"mouse\": true}");
    try testing.expectEqual(@as(u16, 30), parsed.fps);
    try testing.expect(parsed.mouse);
    try testing.expectEqual(@as(u8, 4), parsed.tab_size);

    const invalid_fps: AppOptions = .{ .settings = .{ .fps = 0 } };
    try testing.expectError(error.InvalidConfiguration, invalid_fps.validate());
}

test "parseThemeJson fills omitted fields via zigantic withDefault" {
    const partial_json = "{\"name\":\"ocean\",\"primary\":\"#0ea5e9\"}";
    const theme = try parseThemeJson(testing.allocator, partial_json);
    try testing.expectEqual(@as(u8, 0x0e), theme.base.primary.toRgb().r);
    try testing.expectEqual(@as(u8, 0x22), theme.base.success.toRgb().r);
}
