//! Terminal capability model and environment-based capability detection.

const std = @import("std");
const builtin = @import("builtin");
const style_root = @import("../style/root.zig");
const testing = std.testing;

pub const Capability = style_root.Capability;

/// Graphics / pixel protocol supported by the terminal emulator.
pub const ImageProtocol = enum {
    /// Automatic cell or native selection matching detected terminal environment.
    auto,
    /// Universal UTF-8 half-block (`▀`) TrueColor cell renderer (Windows Terminal, macOS, Linux, SSH, Headless).
    half_block,
    /// Universal 2x2 Quadrant cell renderer.
    quadrant,
    /// Universal 2x4 Braille dot matrix renderer.
    braille,
    /// Luminance ASCII fallback renderer.
    ascii,
    /// Kitty graphics protocol (`APC G ...`).
    kitty,
    /// iTerm2 inline images (`OSC 1337 ; File=...`).
    iterm2,
    /// DEC Sixel graphics (`DCS P q ... ST`).
    sixel,
};

/// Detected or configured terminal capabilities.
pub const TerminalCapabilities = struct {
    /// Maximum supported color depth.
    color: Capability = .trueColor,
    /// True if output is attached to an interactive TTY / console.
    is_tty: bool = false,
    /// True if ANSI / VT escape sequences are interpreted by the output device.
    ansi_sequences: bool = true,
    /// True if UTF-8 Unicode box drawing and wide glyphs are supported.
    unicode: bool = true,
    /// True if alternate screen switching is supported.
    alternate_screen: bool = true,
    /// True if SGR mouse tracking is supported.
    mouse: bool = true,
    /// True if synchronized output (`CSI ? 2026 h/l`) is safe to emit.
    synchronized_output: bool = true,
    /// True if OSC 8 terminal hyperlinks are supported.
    hyperlinks: bool = true,
    /// True if terminal reports `TERM` / environment indicators for Kitty keyboard protocol.
    kitty_keyboard: bool = false,
    /// True if Kitty Graphics Protocol (`APC G`) is detected.
    kitty_graphics: bool = false,
    /// True if iTerm2 Inline Image protocol (`OSC 1337`) is detected.
    iterm2_graphics: bool = false,
    /// True if Sixel graphics (`DCS`) is detected.
    sixel_graphics: bool = false,
    /// Preferred image protocol for pixel media.
    image_protocol: ImageProtocol = .half_block,
    /// True if resize events can be observed.
    resize_events: bool = true,

    /// Minimal fallback capabilities for non-TTY or dumb terminals.
    pub const plain: TerminalCapabilities = .{
        .color = .none,
        .is_tty = false,
        .ansi_sequences = false,
        .unicode = true,
        .alternate_screen = false,
        .mouse = false,
        .synchronized_output = false,
        .hyperlinks = false,
        .kitty_keyboard = false,
        .kitty_graphics = false,
        .iterm2_graphics = false,
        .sixel_graphics = false,
        .image_protocol = .ascii,
        .resize_events = false,
    };
};

/// Queries an environment variable safely without allocating.
/// Returns a borrowed slice valid for the duration of `scratch` when copied on Windows.
fn getEnv(name: []const u8, scratch: *[256]u8) ?[]const u8 {
    if (builtin.os.tag == .windows) {
        var name_w: [128]u16 = undefined;
        if (name.len >= name_w.len) return null;
        for (name, 0..) |ch, i| name_w[i] = ch;
        name_w[name.len] = 0;

        var val_w: [256]u16 = undefined;
        const n = GetEnvironmentVariableW(@ptrCast(&name_w), &val_w, val_w.len);
        if (n == 0 or n >= val_w.len) return null;
        const len = std.unicode.utf16LeToUtf8(scratch, val_w[0..n]) catch return null;
        return scratch[0..len];
    }
    if (builtin.link_libc) {
        var name_z: [128]u8 = undefined;
        if (name.len >= name_z.len) return null;
        @memcpy(name_z[0..name.len], name);
        name_z[name.len] = 0;
        const ptr = std.c.getenv(@ptrCast(&name_z)) orelse return null;
        return std.mem.span(ptr);
    }
    if (builtin.os.tag == .linux) {
        const linux = std.os.linux;
        const fd_rc = linux.open("/proc/self/environ", .{ .ACCMODE = .RDONLY }, 0);
        const fd_signed: isize = @bitCast(fd_rc);
        if (fd_signed < 0) return null;
        const fd: linux.fd_t = @intCast(fd_signed);
        defer _ = linux.close(fd);

        var env_buf: [4096]u8 = undefined;
        var filled: usize = 0;
        while (filled < env_buf.len) {
            const r_rc = linux.read(fd, env_buf[filled..].ptr, env_buf.len - filled);
            const r_signed: isize = @bitCast(r_rc);
            if (r_signed <= 0) break;
            filled += @intCast(r_signed);
        }

        var iter = std.mem.splitScalar(u8, env_buf[0..filled], 0);
        while (iter.next()) |entry| {
            const eq = std.mem.indexOfScalar(u8, entry, '=') orelse continue;
            if (std.mem.eql(u8, entry[0..eq], name)) {
                const val = entry[eq + 1 ..];
                if (val.len > scratch.len) return null;
                @memcpy(scratch[0..val.len], val);
                return scratch[0..val.len];
            }
        }
    }
    return null;
}

extern "kernel32" fn GetEnvironmentVariableW(
    lpName: [*:0]const u16,
    lpBuffer: [*]u16,
    nSize: u32,
) callconv(.winapi) u32;

/// Detects terminal capabilities from TTY/ANSI flags and standard environment variables.
pub fn detect(is_tty: bool, ansi_supported: bool, override_color: ?Capability) TerminalCapabilities {
    var scratch: [256]u8 = undefined;

    const no_color = if (getEnv("NO_COLOR", &scratch)) |v| v.len > 0 else false;
    const force_color = if (getEnv("CLICOLOR_FORCE", &scratch)) |v| v.len > 0 and !std.mem.eql(u8, v, "0") else false;

    var term_buf: [256]u8 = undefined;
    const term = if (getEnv("TERM", &term_buf)) |v| v else "";

    var colorterm_buf: [256]u8 = undefined;
    const colorterm = if (getEnv("COLORTERM", &colorterm_buf)) |v| v else "";

    var wt_buf: [256]u8 = undefined;
    const has_wt = getEnv("WT_SESSION", &wt_buf) != null;

    var prog_buf: [256]u8 = undefined;
    const term_program = if (getEnv("TERM_PROGRAM", &prog_buf)) |v| v else "";

    var caps: TerminalCapabilities = .{
        .is_tty = is_tty,
        .ansi_sequences = ansi_supported,
        .alternate_screen = is_tty and ansi_supported,
        .mouse = is_tty and ansi_supported,
        .synchronized_output = is_tty and ansi_supported,
        .hyperlinks = is_tty and ansi_supported,
        .resize_events = is_tty,
    };

    if (std.mem.eql(u8, term, "dumb")) {
        caps.ansi_sequences = false;
        caps.alternate_screen = false;
        caps.mouse = false;
        caps.synchronized_output = false;
        caps.hyperlinks = false;
        caps.color = .none;
    } else if (no_color and !force_color) {
        caps.color = .none;
    } else if (!ansi_supported and !force_color) {
        caps.color = if (is_tty) .ansi16 else .none;
    } else if (std.ascii.eqlIgnoreCase(colorterm, "truecolor") or
        std.ascii.eqlIgnoreCase(colorterm, "24bit") or
        has_wt or
        std.mem.indexOf(u8, term, "direct") != null or
        std.mem.eql(u8, term_program, "WezTerm") or
        std.mem.eql(u8, term_program, "iTerm.app") or
        std.mem.eql(u8, term_program, "vscode") or
        std.mem.eql(u8, term_program, "ghostty") or
        std.mem.indexOf(u8, term, "kitty") != null)
    {
        caps.color = .trueColor;
    } else if (std.mem.indexOf(u8, term, "256color") != null or
        std.mem.eql(u8, term_program, "Apple_Terminal"))
    {
        caps.color = .ansi256;
    } else if (builtin.os.tag == .windows and ansi_supported) {
        // Windows 10/11 ConHost with VT processing supports 24-bit color.
        caps.color = .trueColor;
    } else if (is_tty or force_color) {
        caps.color = .ansi16;
    } else {
        caps.color = .none;
    }

    if (std.mem.indexOf(u8, term, "kitty") != null or
        std.mem.eql(u8, term_program, "WezTerm") or
        std.mem.eql(u8, term_program, "ghostty"))
    {
        caps.kitty_keyboard = true;
    }

    var kwin_buf: [256]u8 = undefined;
    const has_kitty_win = getEnv("KITTY_WINDOW_ID", &kwin_buf) != null;
    var gh_buf: [256]u8 = undefined;
    const has_ghostty = getEnv("GHOSTTY_RESOURCES_DIR", &gh_buf) != null;
    if (is_tty and ansi_supported) {
        if (has_kitty_win or has_ghostty or std.mem.indexOf(u8, term, "kitty") != null or std.mem.eql(u8, term_program, "WezTerm")) {
            caps.kitty_graphics = true;
        }
        if (std.mem.eql(u8, term_program, "iTerm.app") or std.mem.eql(u8, term_program, "WezTerm") or std.mem.eql(u8, term_program, "vscode")) {
            caps.iterm2_graphics = true;
        }
        if (has_wt or std.mem.indexOf(u8, term, "foot") != null or std.mem.indexOf(u8, term, "mlterm") != null or std.mem.eql(u8, term_program, "WezTerm")) {
            caps.sixel_graphics = true;
        }
    }
    caps.image_protocol = if (!is_tty or !ansi_supported or caps.color == .none)
        .ascii
    else if (caps.kitty_graphics)
        .kitty
    else if (caps.iterm2_graphics)
        .iterm2
    else
        .half_block;

    if (override_color) |ov| {
        caps.color = ov;
    }
    return caps;
}

test "capabilities override and plain preset behave consistently" {
    const caps = detect(false, false, .ansi256);
    try testing.expectEqual(Capability.ansi256, caps.color);
    try testing.expect(!caps.is_tty);
    try testing.expect(!TerminalCapabilities.plain.ansi_sequences);
}
