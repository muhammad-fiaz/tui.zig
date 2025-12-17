//! Platform abstraction layer for cross-platform terminal handling.
//!
//! This module provides a unified interface for terminal operations across
//! Linux, macOS, and Windows platforms.

const std = @import("std");
const builtin = @import("builtin");

/// Saved handle for control handler
var saved_windows_handle: ?WindowsHandle = null;

/// Windows control handler to restore console state on exit
fn windowsCtrlHandler(ctrl_type: u32) callconv(.winapi) std.os.windows.BOOL {
    _ = ctrl_type;
    if (saved_windows_handle) |handle| {
        const kernel32 = struct {
            extern "kernel32" fn SetConsoleMode(h: std.os.windows.HANDLE, mode: u32) callconv(.winapi) std.os.windows.BOOL;
            extern "kernel32" fn SetConsoleCP(wCodePageID: u32) callconv(.winapi) std.os.windows.BOOL;
            extern "kernel32" fn SetConsoleOutputCP(wCodePageID: u32) callconv(.winapi) std.os.windows.BOOL;
        };

        _ = kernel32.SetConsoleMode(handle.stdin_handle, handle.original_input_mode);
        _ = kernel32.SetConsoleMode(handle.stdout_handle, handle.original_output_mode);

        if (handle.original_input_cp != 0) _ = kernel32.SetConsoleCP(handle.original_input_cp);
        if (handle.original_output_cp != 0) _ = kernel32.SetConsoleOutputCP(handle.original_output_cp);
    }
    return 0;
}

/// Platform-specific terminal handle type
pub const TerminalHandle = switch (builtin.os.tag) {
    .windows => WindowsHandle,
    else => PosixHandle,
};

/// POSIX terminal handle (Linux/macOS)
pub const PosixHandle = struct {
    fd: std.posix.fd_t,
    original_termios: ?std.posix.termios = null,

    pub fn init() PosixHandle {
        return .{ .fd = std.posix.STDOUT_FILENO };
    }

    pub fn getInputFd() std.posix.fd_t {
        return std.posix.STDIN_FILENO;
    }
};

/// Windows console handle
pub const WindowsHandle = struct {
    stdout_handle: std.os.windows.HANDLE,
    stdin_handle: std.os.windows.HANDLE,
    original_input_mode: u32 = 0,
    original_output_mode: u32 = 0,
    original_input_cp: u32 = 0,
    original_output_cp: u32 = 0,

    const INVALID_HANDLE_VALUE = @as(std.os.windows.HANDLE, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));

    pub fn init() WindowsHandle {
        return .{
            .stdout_handle = std.os.windows.GetStdHandle(std.os.windows.STD_OUTPUT_HANDLE) catch INVALID_HANDLE_VALUE,
            .stdin_handle = std.os.windows.GetStdHandle(std.os.windows.STD_INPUT_HANDLE) catch INVALID_HANDLE_VALUE,
        };
    }
};

/// Terminal dimensions
pub const TerminalSize = struct {
    cols: u16,
    rows: u16,

    pub fn default() TerminalSize {
        return .{ .cols = 80, .rows = 24 };
    }
};

/// Get terminal size
pub fn getTerminalSize() !TerminalSize {
    switch (builtin.os.tag) {
        .windows => return getWindowsTerminalSize(),
        else => return getPosixTerminalSize(),
    }
}

fn getPosixTerminalSize() !TerminalSize {
    var wsz: std.posix.winsize = .{
        .col = 0,
        .row = 0,
        .xpixel = 0,
        .ypixel = 0,
    };

    const result = std.posix.system.ioctl(std.posix.STDOUT_FILENO, std.posix.T.IOCGWINSZ, @intFromPtr(&wsz));
    if (result != 0) {
        return TerminalSize.default();
    }

    return .{
        .cols = wsz.col,
        .rows = wsz.row,
    };
}

fn getWindowsTerminalSize() !TerminalSize {
    if (builtin.os.tag != .windows) {
        return TerminalSize.default();
    }

    const CONSOLE_SCREEN_BUFFER_INFO = extern struct {
        dwSize: extern struct { X: i16, Y: i16 },
        dwCursorPosition: extern struct { X: i16, Y: i16 },
        wAttributes: u16,
        srWindow: extern struct { Left: i16, Top: i16, Right: i16, Bottom: i16 },
        dwMaximumWindowSize: extern struct { X: i16, Y: i16 },
    };

    const kernel32 = struct {
        extern "kernel32" fn GetConsoleScreenBufferInfo(
            handle: std.os.windows.HANDLE,
            info: *CONSOLE_SCREEN_BUFFER_INFO,
        ) callconv(.winapi) std.os.windows.BOOL;
    };

    const handle = std.os.windows.GetStdHandle(std.os.windows.STD_OUTPUT_HANDLE) catch {
        return TerminalSize.default();
    };

    var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (kernel32.GetConsoleScreenBufferInfo(handle, &info) == 0) {
        return TerminalSize.default();
    }

    return .{
        .cols = @intCast(info.srWindow.Right - info.srWindow.Left + 1),
        .rows = @intCast(info.srWindow.Bottom - info.srWindow.Top + 1),
    };
}

/// Enable raw mode for terminal input
pub fn enableRawMode(handle: *TerminalHandle) !void {
    switch (builtin.os.tag) {
        .windows => try enableWindowsRawMode(handle),
        else => try enablePosixRawMode(handle),
    }
}

/// Disable raw mode and restore terminal
pub fn disableRawMode(handle: *TerminalHandle) void {
    switch (builtin.os.tag) {
        .windows => disableWindowsRawMode(handle),
        else => disablePosixRawMode(handle),
    }
}

fn enablePosixRawMode(handle: *PosixHandle) !void {
    handle.original_termios = try std.posix.tcgetattr(handle.fd);
    var raw = handle.original_termios.?;

    // Input flags: disable break signal, CR to NL, parity, strip, flow control
    raw.iflag.BRKINT = false;
    raw.iflag.ICRNL = false;
    raw.iflag.INPCK = false;
    raw.iflag.ISTRIP = false;
    raw.iflag.IXON = false;

    // Output flags: disable post-processing
    raw.oflag.OPOST = false;

    // Control flags: set 8-bit chars
    raw.cflag.CSIZE = .CS8;

    // Local flags: disable echo, canonical mode, signals, extended input
    raw.lflag.ECHO = false;
    raw.lflag.ICANON = false;
    raw.lflag.ISIG = false;
    raw.lflag.IEXTEN = false;

    // Read with timeout
    raw.cc[@intFromEnum(std.posix.V.MIN)] = 0;
    raw.cc[@intFromEnum(std.posix.V.TIME)] = 1; // 100ms timeout

    try std.posix.tcsetattr(handle.fd, .FLUSH, raw);
}

fn disablePosixRawMode(handle: *PosixHandle) void {
    if (handle.original_termios) |orig| {
        std.posix.tcsetattr(handle.fd, .FLUSH, orig) catch {};
        handle.original_termios = null;
    }
}

fn enableWindowsRawMode(handle: *WindowsHandle) !void {
    if (builtin.os.tag != .windows) return;

    const kernel32 = struct {
        extern "kernel32" fn GetConsoleMode(h: std.os.windows.HANDLE, mode: *u32) callconv(.winapi) std.os.windows.BOOL;
        extern "kernel32" fn SetConsoleMode(h: std.os.windows.HANDLE, mode: u32) callconv(.winapi) std.os.windows.BOOL;
        extern "kernel32" fn GetConsoleCP() callconv(.winapi) u32;
        extern "kernel32" fn SetConsoleCP(wCodePageID: u32) callconv(.winapi) std.os.windows.BOOL;
        extern "kernel32" fn GetConsoleOutputCP() callconv(.winapi) u32;
        extern "kernel32" fn SetConsoleOutputCP(wCodePageID: u32) callconv(.winapi) std.os.windows.BOOL;
        extern "kernel32" fn SetConsoleCtrlHandler(HandlerRoutine: ?*const fn (u32) callconv(.winapi) std.os.windows.BOOL, Add: std.os.windows.BOOL) callconv(.winapi) std.os.windows.BOOL;
    };

    // Save original CPs
    handle.original_input_cp = kernel32.GetConsoleCP();
    handle.original_output_cp = kernel32.GetConsoleOutputCP();

    // Set UTF-8 CP (65001)
    _ = kernel32.SetConsoleCP(65001);
    _ = kernel32.SetConsoleOutputCP(65001);

    // Save original modes
    _ = kernel32.GetConsoleMode(handle.stdin_handle, &handle.original_input_mode);
    _ = kernel32.GetConsoleMode(handle.stdout_handle, &handle.original_output_mode);

    // Register control handler
    saved_windows_handle = handle.*;
    _ = kernel32.SetConsoleCtrlHandler(windowsCtrlHandler, 1);

    // Enable virtual terminal processing for output
    const ENABLE_VIRTUAL_TERMINAL_PROCESSING: u32 = 0x0004;
    const DISABLE_NEWLINE_AUTO_RETURN: u32 = 0x0008;
    _ = kernel32.SetConsoleMode(handle.stdout_handle, handle.original_output_mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING | DISABLE_NEWLINE_AUTO_RETURN);

    // Configure input mode
    const ENABLE_EXTENDED_FLAGS: u32 = 0x0080;
    const ENABLE_WINDOW_INPUT: u32 = 0x0008;
    const ENABLE_MOUSE_INPUT: u32 = 0x0010;
    const ENABLE_VIRTUAL_TERMINAL_INPUT: u32 = 0x0200;

    // Disable line input, echo, and enable VT input
    const new_mode = ENABLE_EXTENDED_FLAGS | ENABLE_WINDOW_INPUT | ENABLE_MOUSE_INPUT | ENABLE_VIRTUAL_TERMINAL_INPUT;
    _ = kernel32.SetConsoleMode(handle.stdin_handle, new_mode);
}

fn disableWindowsRawMode(handle: *WindowsHandle) void {
    if (builtin.os.tag != .windows) return;

    const kernel32 = struct {
        extern "kernel32" fn SetConsoleMode(h: std.os.windows.HANDLE, mode: u32) callconv(.winapi) std.os.windows.BOOL;
        extern "kernel32" fn SetConsoleCP(wCodePageID: u32) callconv(.winapi) std.os.windows.BOOL;
        extern "kernel32" fn SetConsoleOutputCP(wCodePageID: u32) callconv(.winapi) std.os.windows.BOOL;
        extern "kernel32" fn SetConsoleCtrlHandler(HandlerRoutine: ?*const fn (u32) callconv(.winapi) std.os.windows.BOOL, Add: std.os.windows.BOOL) callconv(.winapi) std.os.windows.BOOL;
    };

    // Unregister control handler
    _ = kernel32.SetConsoleCtrlHandler(windowsCtrlHandler, 0);
    saved_windows_handle = null;

    _ = kernel32.SetConsoleMode(handle.stdin_handle, handle.original_input_mode);
    _ = kernel32.SetConsoleMode(handle.stdout_handle, handle.original_output_mode);

    // Restore original CPs
    if (handle.original_input_cp != 0) _ = kernel32.SetConsoleCP(handle.original_input_cp);
    if (handle.original_output_cp != 0) _ = kernel32.SetConsoleOutputCP(handle.original_output_cp);
}

/// Write bytes to terminal
pub fn write(bytes: []const u8) !void {
    const stdout = if (builtin.os.tag == .windows)
        std.fs.File{ .handle = std.os.windows.GetStdHandle(std.os.windows.STD_OUTPUT_HANDLE) catch unreachable }
    else
        std.fs.File{ .handle = std.posix.STDOUT_FILENO };
    _ = try stdout.writeAll(bytes);
}

/// Flush terminal output
pub fn flush() void {
    // stdout is typically line-buffered, but we want immediate output
    // In Zig, std.io.getStdOut() returns an unbuffered writer
}

/// Check if we're running in a terminal
pub fn isTerminal() bool {
    switch (builtin.os.tag) {
        .windows => {
            const kernel32 = struct {
                extern "kernel32" fn GetConsoleMode(h: std.os.windows.HANDLE, mode: *u32) callconv(.winapi) std.os.windows.BOOL;
            };
            const handle = std.os.windows.GetStdHandle(std.os.windows.STD_OUTPUT_HANDLE) catch return false;
            var mode: u32 = undefined;
            return kernel32.GetConsoleMode(handle, &mode) != 0;
        },
        else => {
            return std.posix.isatty(std.posix.STDOUT_FILENO);
        },
    }
}

/// Get the terminal type from TERM environment variable
pub fn getTermType() []const u8 {
    return std.process.getEnvVarOwned(std.heap.page_allocator, "TERM") catch "xterm-256color";
}

/// Check if the terminal supports true color (24-bit)
pub fn supportsTrueColor() bool {
    const colorterm = std.process.getEnvVarOwned(std.heap.page_allocator, "COLORTERM") catch return false;
    defer std.heap.page_allocator.free(colorterm);
    return std.mem.eql(u8, colorterm, "truecolor") or std.mem.eql(u8, colorterm, "24bit");
}

/// Check if the terminal supports 256 colors
pub fn supports256Colors() bool {
    const term = getTermType();
    return std.mem.indexOf(u8, term, "256color") != null;
}

test "terminal size" {
    const size = try getTerminalSize();
    try std.testing.expect(size.cols > 0);
    try std.testing.expect(size.rows > 0);
}

test "is terminal check" {
    // Just test that it doesn't crash
    _ = isTerminal();
}
