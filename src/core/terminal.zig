//! Terminal handling for raw mode, alternate screen, and control sequences.

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("../platform/platform.zig");

/// ANSI escape sequence constants
pub const Escape = struct {
    // Cursor control
    pub const hide_cursor = "\x1b[?25l";
    pub const show_cursor = "\x1b[?25h";
    pub const save_cursor = "\x1b[s";
    pub const restore_cursor = "\x1b[u";
    pub const home = "\x1b[H";

    // Screen control
    pub const clear_screen = "\x1b[2J";
    pub const clear_line = "\x1b[2K";
    pub const clear_to_end = "\x1b[0J";
    pub const clear_to_start = "\x1b[1J";
    pub const clear_line_to_end = "\x1b[0K";
    pub const clear_line_to_start = "\x1b[1K";

    // Alternate screen buffer
    pub const enter_alt_screen = "\x1b[?1049h";
    pub const exit_alt_screen = "\x1b[?1049l";

    // Mouse mode
    pub const enable_mouse = "\x1b[?1000h\x1b[?1002h\x1b[?1003h\x1b[?1006h";
    pub const disable_mouse = "\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l";

    // Bracketed paste mode
    pub const enable_paste = "\x1b[?2004h";
    pub const disable_paste = "\x1b[?2004l";

    // Focus events
    pub const enable_focus = "\x1b[?1004h";
    pub const disable_focus = "\x1b[?1004l";

    // Style reset
    pub const reset = "\x1b[0m";
    pub const reset_fg = "\x1b[39m";
    pub const reset_bg = "\x1b[49m";

    // Text attributes
    pub const bold = "\x1b[1m";
    pub const dim = "\x1b[2m";
    pub const italic = "\x1b[3m";
    pub const underline = "\x1b[4m";
    pub const blink = "\x1b[5m";
    pub const reverse = "\x1b[7m";
    pub const hidden = "\x1b[8m";
    pub const strikethrough = "\x1b[9m";

    // Attribute off
    pub const bold_off = "\x1b[22m";
    pub const italic_off = "\x1b[23m";
    pub const underline_off = "\x1b[24m";
    pub const blink_off = "\x1b[25m";
    pub const reverse_off = "\x1b[27m";
    pub const hidden_off = "\x1b[28m";
    pub const strikethrough_off = "\x1b[29m";

    // Scroll region
    pub fn setScrollRegion(top: u16, bottom: u16) [16]u8 {
        var buf: [16]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "\x1b[{d};{d}r", .{ top + 1, bottom + 1 }) catch "";
        return buf;
    }

    // Move cursor
    pub fn moveTo(x: u16, y: u16) [16]u8 {
        var buf: [16]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "\x1b[{d};{d}H", .{ y + 1, x + 1 }) catch "";
        return buf;
    }

    // Move cursor relative
    pub fn moveUp(n: u16) [8]u8 {
        var buf: [8]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "\x1b[{d}A", .{n}) catch "";
        return buf;
    }

    pub fn moveDown(n: u16) [8]u8 {
        var buf: [8]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "\x1b[{d}B", .{n}) catch "";
        return buf;
    }

    pub fn moveRight(n: u16) [8]u8 {
        var buf: [8]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "\x1b[{d}C", .{n}) catch "";
        return buf;
    }

    pub fn moveLeft(n: u16) [8]u8 {
        var buf: [8]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "\x1b[{d}D", .{n}) catch "";
        return buf;
    }
};

/// Terminal configuration
pub const TerminalConfig = struct {
    /// Whether to use the alternate screen buffer
    alternate_screen: bool = true,

    /// Whether to hide the cursor
    hide_cursor: bool = true,

    /// Whether to enable mouse input
    enable_mouse: bool = true,

    /// Whether to enable bracketed paste
    enable_paste: bool = true,

    /// Whether to enable focus events
    enable_focus: bool = true,
};

/// Terminal state manager
pub const Terminal = struct {
    handle: platform.TerminalHandle,
    config: TerminalConfig,
    stdout: std.fs.File,
    is_initialized: bool = false,

    /// Get stdout handle in a cross-platform way for Zig 0.15+
    fn getStdout() std.fs.File {
        if (builtin.os.tag == .windows) {
            const handle = std.os.windows.GetStdHandle(std.os.windows.STD_OUTPUT_HANDLE) catch unreachable;
            return std.fs.File{ .handle = handle };
        } else {
            return std.fs.File{ .handle = std.posix.STDOUT_FILENO };
        }
    }

    /// Initialize the terminal
    pub fn init(config: TerminalConfig) !Terminal {
        var term = Terminal{
            .handle = platform.TerminalHandle.init(),
            .config = config,
            .stdout = getStdout(),
        };

        try term.setup();
        return term;
    }

    /// Set up the terminal for TUI mode
    fn setup(self: *Terminal) !void {
        // Enable raw mode
        try platform.enableRawMode(&self.handle);

        // Enter alternate screen
        if (self.config.alternate_screen) {
            _ = try self.stdout.writeAll(Escape.enter_alt_screen);
        }

        // Hide cursor
        if (self.config.hide_cursor) {
            _ = try self.stdout.writeAll(Escape.hide_cursor);
        }

        // Enable mouse
        if (self.config.enable_mouse) {
            _ = try self.stdout.writeAll(Escape.enable_mouse);
        }

        // Enable paste mode
        if (self.config.enable_paste) {
            _ = try self.stdout.writeAll(Escape.enable_paste);
        }

        // Enable focus events
        if (self.config.enable_focus) {
            _ = try self.stdout.writeAll(Escape.enable_focus);
        }

        // Clear screen and move to home
        _ = try self.stdout.writeAll(Escape.clear_screen);
        _ = try self.stdout.writeAll(Escape.home);

        self.is_initialized = true;
    }

    /// Restore the terminal to its original state
    pub fn deinit(self: *Terminal) void {
        if (!self.is_initialized) return;

        // Disable focus events
        if (self.config.enable_focus) {
            _ = self.stdout.writeAll(Escape.disable_focus) catch {};
        }

        // Disable paste mode
        if (self.config.enable_paste) {
            _ = self.stdout.writeAll(Escape.disable_paste) catch {};
        }

        // Disable mouse
        if (self.config.enable_mouse) {
            _ = self.stdout.writeAll(Escape.disable_mouse) catch {};
        }

        // Show cursor
        if (self.config.hide_cursor) {
            _ = self.stdout.writeAll(Escape.show_cursor) catch {};
        }

        // Reset styles
        _ = self.stdout.writeAll(Escape.reset) catch {};

        // Leave alternate screen
        if (self.config.alternate_screen) {
            _ = self.stdout.writeAll(Escape.exit_alt_screen) catch {};
        }

        // Restore raw mode
        platform.disableRawMode(&self.handle);

        self.is_initialized = false;
    }

    /// Get the terminal size
    pub fn getSize(self: *Terminal) !platform.TerminalSize {
        _ = self;
        return platform.getTerminalSize();
    }

    /// Write raw bytes to the terminal
    pub fn write(self: *Terminal, bytes: []const u8) !void {
        _ = try self.stdout.writeAll(bytes);
    }

    /// Write formatted output using a buffer
    pub fn print(self: *Terminal, comptime fmt: []const u8, args: anytype) !void {
        var buf: [256]u8 = undefined;
        const output = std.fmt.bufPrint(&buf, fmt, args) catch return;
        _ = try self.stdout.writeAll(output);
    }

    /// Move cursor to position
    pub fn moveCursor(self: *Terminal, x: u16, y: u16) !void {
        var buf: [32]u8 = undefined;
        const output = std.fmt.bufPrint(&buf, "\x1b[{d};{d}H", .{ y + 1, x + 1 }) catch return;
        _ = try self.stdout.writeAll(output);
    }

    /// Clear the screen
    pub fn clear(self: *Terminal) !void {
        _ = try self.stdout.writeAll(Escape.clear_screen);
        _ = try self.stdout.writeAll(Escape.home);
    }

    /// Set foreground color (24-bit)
    pub fn setFgRGB(self: *Terminal, r: u8, g: u8, b: u8) !void {
        var buf: [32]u8 = undefined;
        const output = std.fmt.bufPrint(&buf, "\x1b[38;2;{d};{d};{d}m", .{ r, g, b }) catch return;
        _ = try self.stdout.writeAll(output);
    }

    /// Set background color (24-bit)
    pub fn setBgRGB(self: *Terminal, r: u8, g: u8, b: u8) !void {
        var buf: [32]u8 = undefined;
        const output = std.fmt.bufPrint(&buf, "\x1b[48;2;{d};{d};{d}m", .{ r, g, b }) catch return;
        _ = try self.stdout.writeAll(output);
    }

    /// Reset all attributes
    pub fn reset(self: *Terminal) !void {
        _ = try self.stdout.writeAll(Escape.reset);
    }

    /// Show the cursor
    pub fn showCursor(self: *Terminal) !void {
        _ = try self.stdout.writeAll(Escape.show_cursor);
    }

    /// Hide the cursor
    pub fn hideCursor(self: *Terminal) !void {
        _ = try self.stdout.writeAll(Escape.hide_cursor);
    }

    /// Flush output
    pub fn flush(self: *Terminal) !void {
        // The file writer doesn't have a flush method for stdout,
        // but we can force sync if needed
        _ = self;
    }
};

/// Query terminal capabilities
pub const Capabilities = struct {
    /// Check if true color is supported
    pub fn hasTrueColor() bool {
        return platform.supportsTrueColor();
    }

    /// Check if 256 colors are supported
    pub fn has256Colors() bool {
        return platform.supports256Colors();
    }

    /// Check if running in a TTY
    pub fn isTTY() bool {
        return platform.isTerminal();
    }

    /// Get terminal emulator name if available
    pub fn getTerminalEmulator() ?[]const u8 {
        return std.process.getEnvVarOwned(std.heap.page_allocator, "TERM_PROGRAM") catch null;
    }
};

test "escape sequence generation" {
    const move_seq = Escape.moveTo(10, 5);
    // Check that it contains expected characters
    try std.testing.expect(move_seq[0] == 0x1b);
    try std.testing.expect(move_seq[1] == '[');
}

test "terminal capabilities" {
    // Just check these don't crash
    _ = Capabilities.isTTY();
    _ = Capabilities.hasTrueColor();
    _ = Capabilities.has256Colors();
}
