//! Unified terminal backend abstraction across POSIX, Windows, ANSI streams, and Memory.

const std = @import("std");
const builtin = @import("builtin");
const core_root = @import("../core/root.zig");
const event_root = @import("../event/root.zig");
const caps_mod = @import("capabilities.zig");
const ansi_mod = @import("ansi.zig");
const memory_mod = @import("memory.zig");
const posix_mod = @import("posix.zig");
const windows_mod = @import("windows.zig");
const testing = std.testing;

pub const ClearType = ansi_mod.ClearType;
pub const CursorShape = ansi_mod.CursorShape;
pub const ImageProtocol = caps_mod.ImageProtocol;
pub const TerminalCapabilities = caps_mod.TerminalCapabilities;
pub const MemoryBackend = memory_mod.MemoryBackend;
pub const PosixBackend = posix_mod.PosixBackend;
pub const WindowsBackend = windows_mod.WindowsBackend;
pub const Size = core_root.Size;
pub const Position = core_root.Position;
pub const BufferDiff = core_root.BufferDiff;
pub const BackendMode = core_root.BackendMode;
pub const Capability = core_root.AppOptions;
pub const Event = event_root.Event;
pub const EventParser = event_root.EventParser;

/// Session flags applied when entering interactive terminal mode (synthesized by `zigantic`).
pub const EnterOptions = core_root.EnterOptions;

/// Pure ANSI writer backend targeting an explicit `std.Io.File` or buffered writer.
pub const AnsiBackend = struct {
    io: std.Io,
    out_file: std.Io.File,
    caps: TerminalCapabilities,
    fixed_size: Size = .{ .width = 80, .height = 24 },
    session: ansi_mod.SessionState = .{},

    pub fn init(io: std.Io, out_file: std.Io.File, caps: TerminalCapabilities) AnsiBackend {
        return .{ .io = io, .out_file = out_file, .caps = caps };
    }

    pub fn writeAll(self: *AnsiBackend, bytes: []const u8) !void {
        if (bytes.len == 0) return;
        try self.out_file.writeStreamingAll(self.io, bytes);
    }
};

/// Cross-platform backend union dispatching terminal operations without heap vtable overhead.
pub const Backend = union(enum) {
    memory: MemoryBackend,
    ansi: AnsiBackend,
    posix: if (posix_mod.is_posix) PosixBackend else noreturn,
    windows: if (windows_mod.is_windows) WindowsBackend else noreturn,

    /// Initializes the appropriate backend for `mode` and optional color `capability_override`.
    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        mode: BackendMode,
        capability_override: ?@import("../style/root.zig").Capability,
    ) !Backend {
        return switch (mode) {
            .memory => |sz| .{ .memory = try MemoryBackend.init(allocator, sz) },
            .ansi => blk: {
                const out = std.Io.File.stdout();
                const is_tty = out.isTty(io) catch false;
                const ansi_ok = out.supportsAnsiEscapeCodes(io) catch is_tty;
                break :blk .{ .ansi = AnsiBackend.init(io, out, caps_mod.detect(is_tty, ansi_ok, capability_override)) };
            },
            .posix => if (posix_mod.is_posix)
                .{ .posix = PosixBackend.init(allocator, io, capability_override) }
            else
                error.UnsupportedBackend,
            .windows => if (windows_mod.is_windows)
                .{ .windows = WindowsBackend.init(allocator, io, capability_override) }
            else
                error.UnsupportedBackend,
            .auto => if (windows_mod.is_windows)
                .{ .windows = WindowsBackend.init(allocator, io, capability_override) }
            else if (posix_mod.is_posix)
                .{ .posix = PosixBackend.init(allocator, io, capability_override) }
            else
                .{ .memory = try MemoryBackend.init(allocator, .{ .width = 80, .height = 24 }) },
        };
    }

    pub fn deinit(self: *Backend) void {
        switch (self.*) {
            .memory => |*m| m.deinit(),
            .ansi => {},
            .posix => |*p| if (posix_mod.is_posix) p.deinit(),
            .windows => |*w| if (windows_mod.is_windows) w.deinit(),
        }
    }

    pub fn capabilities(self: *const Backend) TerminalCapabilities {
        return switch (self.*) {
            .memory => |*m| m.caps,
            .ansi => |*a| a.caps,
            .posix => |*p| if (posix_mod.is_posix) p.caps else unreachable,
            .windows => |*w| if (windows_mod.is_windows) w.caps else unreachable,
        };
    }

    pub fn enter(self: *Backend, opts: EnterOptions) !void {
        switch (self.*) {
            .memory => |*m| {
                m.raw_mode = opts.raw_mode;
                m.in_alternate_screen = opts.alternate_screen;
                m.mouse_enabled = opts.mouse;
                m.cursor_visible = !opts.hide_cursor;
                if (opts.title) |t| m.setTitle(t);
            },
            .ansi => |*a| {
                var buf: [512]u8 = undefined;
                var w = std.Io.Writer.fixed(&buf);
                ansi_mod.writeEnterSession(&w, &a.session, opts, a.caps) catch {};
                try a.writeAll(w.buffered());
            },
            .posix => |*p| if (posix_mod.is_posix) try p.enter(opts),
            .windows => |*w| if (windows_mod.is_windows) try w.enter(opts),
        }
    }

    pub fn restore(self: *Backend) void {
        switch (self.*) {
            .memory => |*m| {
                m.raw_mode = false;
                m.in_alternate_screen = false;
                m.mouse_enabled = false;
                m.cursor_visible = true;
                m.cursor_shape = .default_shape;
            },
            .ansi => |*a| {
                var buf: [128]u8 = undefined;
                var w = std.Io.Writer.fixed(&buf);
                ansi_mod.writeLeaveSession(&w, &a.session) catch {};
                a.writeAll(w.buffered()) catch {};
            },
            .posix => |*p| if (posix_mod.is_posix) p.restore(),
            .windows => |*w| if (windows_mod.is_windows) w.restore(),
        }
    }

    pub fn size(self: *const Backend) !Size {
        return switch (self.*) {
            .memory => |*m| m.size(),
            .ansi => |*a| a.fixed_size,
            .posix => |*p| if (posix_mod.is_posix) try p.size() else unreachable,
            .windows => |*w| if (windows_mod.is_windows) w.size() else unreachable,
        };
    }

    pub fn writeBytes(self: *Backend, bytes: []const u8) !void {
        switch (self.*) {
            .memory => |*m| try m.ansi_log.appendSlice(m.allocator, bytes),
            .ansi => |*a| try a.writeAll(bytes),
            .posix => |*p| if (posix_mod.is_posix) try p.writeAll(bytes),
            .windows => |*w| if (windows_mod.is_windows) try w.writeAll(bytes),
        }
    }

    pub fn drawDiff(
        self: *Backend,
        allocator: std.mem.Allocator,
        staging: *std.ArrayList(u8),
        diff_iter: *BufferDiff,
        synchronized: bool,
    ) !void {
        switch (self.*) {
            .memory => |*m| m.drawDiff(diff_iter),
            .windows => |*w| if (windows_mod.is_windows) {
                if (!w.caps.ansi_sequences) {
                    w.drawDiffWin32Fallback(diff_iter);
                    return;
                }
                try emitAnsiDiff(self, allocator, staging, diff_iter, w.caps, synchronized);
            },
            else => {
                const caps = self.capabilities();
                try emitAnsiDiff(self, allocator, staging, diff_iter, caps, synchronized);
            },
        }
    }

    fn emitAnsiDiff(
        self: *Backend,
        allocator: std.mem.Allocator,
        staging: *std.ArrayList(u8),
        diff_iter: *BufferDiff,
        caps: TerminalCapabilities,
        synchronized: bool,
    ) !void {
        staging.clearRetainingCapacity();
        var aw = std.Io.Writer.Allocating.fromArrayList(allocator, staging);
        defer staging.* = aw.toArrayList();

        try ansi_mod.writeDiff(&aw.writer, diff_iter, caps, synchronized);
        if (aw.writer.buffered().len > 0) {
            try self.writeBytes(aw.writer.buffered());
        }
    }

    /// Appends blank lines at bottom of screen or inserts formatted lines before an inline viewport.
    pub fn insertBufferBefore(
        self: *Backend,
        allocator: std.mem.Allocator,
        staging: *std.ArrayList(u8),
        lines_buf: *const core_root.Buffer,
        vp_area: core_root.Rect,
    ) !void {
        switch (self.*) {
            .memory => |*m| try m.recordInsertedBuffer(lines_buf),
            else => {
                if (vp_area.height == 0 or lines_buf.area.height == 0) return;
                const caps = self.capabilities();
                if (!caps.ansi_sequences) return;

                staging.clearRetainingCapacity();
                var aw = std.Io.Writer.Allocating.fromArrayList(allocator, staging);
                defer staging.* = aw.toArrayList();

                // Scroll region up above viewport when top > 0, then draw inserted lines right above viewport.
                const top_rows = vp_area.top();
                if (top_rows > 0) {
                    try ansi_mod.writeScrollRegionUp(&aw.writer, 0, top_rows - 1, lines_buf.area.height);
                }
                var empty_prev = try core_root.Buffer.init(allocator, lines_buf.area);
                defer empty_prev.deinit();
                var shifted = lines_buf.diff(&empty_prev);
                const start_row: u16 = top_rows -| lines_buf.area.height;
                shifted.area.y = start_row;
                try ansi_mod.writeDiff(&aw.writer, &shifted, caps, false);

                if (aw.writer.buffered().len > 0) {
                    try self.writeBytes(aw.writer.buffered());
                }
            },
        }
    }

    pub fn clear(self: *Backend, clear_type: ClearType) !void {
        switch (self.*) {
            .memory => |*m| m.clear(clear_type),
            .windows => |*w| if (windows_mod.is_windows) {
                if (!w.caps.ansi_sequences) {
                    w.clearWin32Fallback();
                    return;
                }
                var buf: [16]u8 = undefined;
                var writer = std.Io.Writer.fixed(&buf);
                try ansi_mod.writeClear(&writer, clear_type);
                try w.writeAll(writer.buffered());
            },
            else => {
                var buf: [16]u8 = undefined;
                var writer = std.Io.Writer.fixed(&buf);
                try ansi_mod.writeClear(&writer, clear_type);
                try self.writeBytes(writer.buffered());
            },
        }
    }

    pub fn setCursor(self: *Backend, pos: Position, visible: bool) !void {
        switch (self.*) {
            .memory => |*m| {
                m.cursor_pos = pos;
                m.cursor_visible = visible;
            },
            else => {
                var buf: [48]u8 = undefined;
                var writer = std.Io.Writer.fixed(&buf);
                if (visible) {
                    try ansi_mod.writeMoveTo(&writer, pos.x, pos.y);
                    try ansi_mod.writeShowCursor(&writer);
                } else {
                    try ansi_mod.writeHideCursor(&writer);
                }
                try self.writeBytes(writer.buffered());
            },
        }
    }

    /// Sets the terminal hardware cursor shape (`DECSCUSR`) and records state for restoration on exit.
    pub fn setCursorShape(self: *Backend, shape: CursorShape) !void {
        switch (self.*) {
            .memory => |*m| m.cursor_shape = shape,
            .ansi => |*a| {
                if (!a.caps.ansi_sequences) return;
                var buf: [24]u8 = undefined;
                var writer = std.Io.Writer.fixed(&buf);
                try ansi_mod.writeCursorShape(&writer, shape);
                try a.writeAll(writer.buffered());
                a.session.cursor_shape_modified = shape != .default_shape;
            },
            .posix => |*p| if (posix_mod.is_posix) {
                if (!p.caps.ansi_sequences) return;
                var buf: [24]u8 = undefined;
                var writer = std.Io.Writer.fixed(&buf);
                try ansi_mod.writeCursorShape(&writer, shape);
                try p.writeAll(writer.buffered());
                p.session.cursor_shape_modified = shape != .default_shape;
            },
            .windows => |*w| if (windows_mod.is_windows) {
                if (!w.caps.ansi_sequences) return;
                var buf: [24]u8 = undefined;
                var writer = std.Io.Writer.fixed(&buf);
                try ansi_mod.writeCursorShape(&writer, shape);
                try w.writeAll(writer.buffered());
                w.session.cursor_shape_modified = shape != .default_shape;
            },
        }
    }

    /// Updates the terminal window/tab title (`OSC 0` and native Win32 Console title).
    pub fn setTitle(self: *Backend, title_bytes: []const u8) !void {
        switch (self.*) {
            .memory => |*m| m.setTitle(title_bytes),
            .windows => |*w| if (windows_mod.is_windows) try w.setTitle(title_bytes),
            else => {
                var buf: [300]u8 = undefined;
                var w = std.Io.Writer.fixed(&buf);
                try ansi_mod.writeTitle(&w, title_bytes[0..@min(title_bytes.len, 256)]);
                try self.writeBytes(w.buffered());
            },
        }
    }

    pub fn pollEvent(self: *Backend, parser: *EventParser, timeout_ms: i32) !Event {
        return switch (self.*) {
            .memory => |*m| m.pollEvent(),
            .ansi => .none,
            .posix => |*p| if (posix_mod.is_posix) try p.pollEvent(parser, timeout_ms) else unreachable,
            .windows => |*w| if (windows_mod.is_windows) try w.pollEvent(parser, timeout_ms) else unreachable,
        };
    }
};

test {
    testing.refAllDecls(@This());
    testing.refAllDecls(capabilities);
    testing.refAllDecls(ansi);
    testing.refAllDecls(memory);
    testing.refAllDecls(posix);
    testing.refAllDecls(windows);
}

pub const capabilities = caps_mod;
pub const ansi = ansi_mod;
pub const memory = memory_mod;
pub const posix = posix_mod;
pub const windows = windows_mod;
