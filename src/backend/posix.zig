//! Native POSIX TTY backend (Linux, macOS, FreeBSD, NetBSD, OpenBSD).
//!
//! Uses `std.posix.tcgetattr`/`tcsetattr` for raw mode and guaranteed original
//! termios restoration, `TIOCGWINSZ` ioctl for terminal dimensions, `SIGWINCH`
//! atomic flag handling for resize detection, and `std.posix.poll` for timeout
//! input reading without spawning extra threads.

const std = @import("std");
const builtin = @import("builtin");
const core_root = @import("../core/root.zig");
const event_root = @import("../event/root.zig");
const caps_mod = @import("capabilities.zig");
const ansi_mod = @import("ansi.zig");
const testing = std.testing;

pub const is_posix = builtin.os.tag != .windows and builtin.os.tag != .wasi and builtin.os.tag != .freestanding;

pub const Size = core_root.Size;
pub const Position = core_root.Position;
pub const Event = event_root.Event;
pub const EventParser = event_root.EventParser;
pub const EnterOptions = core_root.EnterOptions;
pub const TerminalCapabilities = caps_mod.TerminalCapabilities;

var sigwinch_flag: std.atomic.Value(bool) = .init(false);

fn handleSigwinch(_: std.posix.SIG) callconv(.c) void {
    sigwinch_flag.store(true, .release);
}

/// Native POSIX terminal driver. On non-POSIX targets, this type compiles cleanly as an unavailable stub.
pub const PosixBackend = if (!is_posix) struct {
    pub fn isSupported() bool {
        return false;
    }
} else struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    in_file: std.Io.File,
    out_file: std.Io.File,
    caps: TerminalCapabilities,
    orig_termios: ?std.posix.termios = null,
    orig_sigwinch: ?std.posix.Sigaction = null,
    sigwinch_installed: bool = false,
    raw_active: bool = false,
    session: ansi_mod.SessionState = .{},
    last_size: Size = .{ .width = 80, .height = 24 },
    out_buf: std.ArrayList(u8) = .empty,

    pub fn isSupported() bool {
        return true;
    }

    pub fn init(allocator: std.mem.Allocator, io: std.Io, color_override: ?caps_mod.Capability) PosixBackend {
        const in_file = std.Io.File.stdin();
        const out_file = std.Io.File.stdout();
        const is_tty = out_file.isTty(io) catch false;
        const ansi_ok = out_file.supportsAnsiEscapeCodes(io) catch is_tty;
        var backend = PosixBackend{
            .allocator = allocator,
            .io = io,
            .in_file = in_file,
            .out_file = out_file,
            .caps = caps_mod.detect(is_tty, ansi_ok, color_override),
        };
        backend.last_size = backend.size() catch .{ .width = 80, .height = 24 };
        return backend;
    }

    pub fn deinit(self: *PosixBackend) void {
        self.restore();
        self.out_buf.deinit(self.allocator);
    }

    pub fn enter(self: *PosixBackend, opts: EnterOptions) !void {
        if (opts.raw_mode and !self.raw_active) {
            if (std.posix.tcgetattr(self.in_file.handle)) |orig| {
                self.orig_termios = orig;
                var raw = orig;
                raw.iflag.BRKINT = false;
                raw.iflag.ICRNL = false;
                raw.iflag.INPCK = false;
                raw.iflag.ISTRIP = false;
                raw.iflag.IXON = false;
                raw.oflag.OPOST = false;
                raw.cflag.CSIZE = .CS8;
                raw.lflag.ECHO = false;
                raw.lflag.ICANON = false;
                raw.lflag.IEXTEN = false;
                raw.lflag.ISIG = false;
                raw.cc[@backingInt(std.posix.V.MIN)] = 0;
                raw.cc[@backingInt(std.posix.V.TIME)] = 0;
                try std.posix.tcsetattr(self.in_file.handle, .FLUSH, raw);
                self.raw_active = true;
            } else |_| {}
        }

        if (!self.sigwinch_installed) {
            if (@hasField(std.posix.SIG, "WINCH")) {
                var act: std.posix.Sigaction = .{
                    .handler = .{ .handler = handleSigwinch },
                    .mask = std.posix.sigemptyset(),
                    .flags = 0,
                };
                var prev: std.posix.Sigaction = undefined;
                std.posix.sigaction(std.posix.SIG.WINCH, &act, &prev);
                self.orig_sigwinch = prev;
                self.sigwinch_installed = true;
            }
        }

        self.out_buf.clearRetainingCapacity();
        var aw = std.Io.Writer.Allocating.fromArrayList(self.allocator, &self.out_buf);
        defer self.out_buf = aw.toArrayList();

        try ansi_mod.writeEnterSession(&aw.writer, &self.session, opts, self.caps);
        if (aw.writer.buffered().len > 0) {
            try self.writeAll(aw.writer.buffered());
        }
    }

    pub fn restore(self: *PosixBackend) void {
        self.out_buf.clearRetainingCapacity();
        var aw = std.Io.Writer.Allocating.fromArrayList(self.allocator, &self.out_buf);
        defer self.out_buf = aw.toArrayList();

        ansi_mod.writeLeaveSession(&aw.writer, &self.session) catch {};
        if (aw.writer.buffered().len > 0) {
            self.writeAll(aw.writer.buffered()) catch {};
        }

        if (self.raw_active) {
            if (self.orig_termios) |orig| {
                std.posix.tcsetattr(self.in_file.handle, .FLUSH, orig) catch {};
            }
            self.raw_active = false;
        }
        if (self.sigwinch_installed) {
            if (@hasField(std.posix.SIG, "WINCH")) {
                if (self.orig_sigwinch) |*prev| {
                    std.posix.sigaction(std.posix.SIG.WINCH, prev, null);
                }
            }
            self.sigwinch_installed = false;
        }
    }

    pub fn size(self: *const PosixBackend) !Size {
        var ws: std.posix.winsize = .{ .row = 0, .col = 0, .xpixel = 0, .ypixel = 0 };
        const fd = self.out_file.handle;
        const ok = queryWinsize(fd, &ws) or queryWinsize(self.in_file.handle, &ws);
        if (!ok or ws.col == 0 or ws.row == 0) {
            return .{ .width = 80, .height = 24 };
        }
        return .{ .width = ws.col, .height = ws.row };
    }

    fn queryWinsize(fd: std.posix.fd_t, ws: *std.posix.winsize) bool {
        if (builtin.os.tag == .linux and !builtin.link_libc) {
            const rc = std.os.linux.syscall3(
                .ioctl,
                @as(usize, @bitCast(@as(isize, fd))),
                std.os.linux.T.IOCGWINSZ,
                @intFromPtr(ws),
            );
            return std.os.linux.errno(rc) == .SUCCESS;
        }
        const rc = std.posix.system.ioctl(fd, @intCast(std.posix.system.T.IOCGWINSZ), @intFromPtr(ws));
        return std.posix.errno(rc) == .SUCCESS;
    }

    pub fn writeAll(self: *PosixBackend, bytes: []const u8) !void {
        if (bytes.len == 0) return;
        try self.out_file.writeStreamingAll(self.io, bytes);
    }

    pub fn pollEvent(self: *PosixBackend, parser: *EventParser, timeout_ms: i32) !Event {
        if (sigwinch_flag.swap(false, .acq_rel)) {
            const sz = try self.size();
            self.last_size = sz;
            return .{ .resize = sz };
        }

        if (try parser.nextEvent(false)) |ev| return ev;

        var fds = [_]std.posix.pollfd{.{
            .fd = self.in_file.handle,
            .events = std.posix.POLL.IN,
            .revents = 0,
        }};

        const ready = std.posix.poll(&fds, timeout_ms) catch 0;
        if (sigwinch_flag.swap(false, .acq_rel)) {
            const sz = try self.size();
            self.last_size = sz;
            return .{ .resize = sz };
        }

        if (ready > 0 and (fds[0].revents & std.posix.POLL.IN) != 0) {
            var tmp: [256]u8 = undefined;
            const n = self.in_file.readStreaming(self.io, &.{&tmp}) catch |err| switch (err) {
                error.EndOfStream, error.WouldBlock => 0,
                else => return err,
            };
            if (n > 0) {
                _ = parser.feed(tmp[0..n]);
                if (try parser.nextEvent(false)) |ev| return ev;
            }
        }

        // Disambiguate a lone Escape key if no trailing bytes arrived within a brief window.
        if (parser.hasPending()) {
            var esc_fds = [_]std.posix.pollfd{.{
                .fd = self.in_file.handle,
                .events = std.posix.POLL.IN,
                .revents = 0,
            }};
            const more = std.posix.poll(&esc_fds, 15) catch 0;
            if (more > 0 and (esc_fds[0].revents & std.posix.POLL.IN) != 0) {
                var tmp: [256]u8 = undefined;
                const n = self.in_file.readStreaming(self.io, &.{&tmp}) catch 0;
                if (n > 0) _ = parser.feed(tmp[0..n]);
                if (try parser.nextEvent(false)) |ev| return ev;
            }
            if (try parser.nextEvent(true)) |ev| return ev;
        }

        return .none;
    }
};

test "posix backend availability compiles on all targets" {
    try testing.expectEqual(is_posix, PosixBackend.isSupported());
}
