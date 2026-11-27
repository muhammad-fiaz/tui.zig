//! Native Windows Console backend using Win32 Console API and VT sequences.
//!
//! Saves and restores original console input/output modes, console UTF-8 code
//! pages, and cursor/screen state. Supports both modern Windows Terminal /
//! Windows 10+ VT mode AND legacy Win32 console attribute fallback when VT
//! output is unavailable. Uses `ReadConsoleInputW` for rich keyboard
//! (press/repeat/release + Unicode surrogate pairs), mouse, focus, and resize
//! events, with transparent VT pipe fallback for ConPTY/MinTTY/Cygwin.

const std = @import("std");
const builtin = @import("builtin");
const core_root = @import("../core/root.zig");
const event_root = @import("../event/root.zig");
const caps_mod = @import("capabilities.zig");
const ansi_mod = @import("ansi.zig");
const testing = std.testing;

pub const is_windows = builtin.os.tag == .windows;

pub const Size = core_root.Size;
pub const Position = core_root.Position;
pub const BufferDiff = core_root.BufferDiff;
pub const Event = event_root.Event;
pub const EventParser = event_root.EventParser;
pub const KeyCode = event_root.KeyCode;
pub const KeyModifiers = event_root.KeyModifiers;
pub const KeyEventKind = event_root.KeyEventKind;
pub const MouseButton = event_root.MouseButton;
pub const MouseEventKind = event_root.MouseEventKind;
pub const EnterOptions = core_root.EnterOptions;
pub const TerminalCapabilities = caps_mod.TerminalCapabilities;

pub const WindowsBackend = if (!is_windows) struct {
    pub fn isSupported() bool {
        return false;
    }
} else struct {
    const win = std.os.windows;
    const HANDLE = win.HANDLE;
    const DWORD = win.DWORD;
    const WORD = win.WORD;
    const BOOL = win.BOOL;
    const WCHAR = win.WCHAR;

    const ENABLE_PROCESSED_INPUT: DWORD = 0x0001;
    const ENABLE_LINE_INPUT: DWORD = 0x0002;
    const ENABLE_ECHO_INPUT: DWORD = 0x0004;
    const ENABLE_WINDOW_INPUT: DWORD = 0x0008;
    const ENABLE_MOUSE_INPUT: DWORD = 0x0010;
    const ENABLE_QUICK_EDIT_MODE: DWORD = 0x0040;
    const ENABLE_EXTENDED_FLAGS: DWORD = 0x0080;
    const ENABLE_VIRTUAL_TERMINAL_INPUT: DWORD = 0x0200;

    const ENABLE_PROCESSED_OUTPUT: DWORD = 0x0001;
    const ENABLE_VIRTUAL_TERMINAL_PROCESSING: DWORD = 0x0004;

    const WAIT_OBJECT_0: DWORD = 0x00000000;
    const INFINITE: DWORD = 0xFFFFFFFF;

    const KEY_EVENT: WORD = 0x0001;
    const MOUSE_EVENT: WORD = 0x0002;
    const WINDOW_BUFFER_SIZE_EVENT: WORD = 0x0004;
    const FOCUS_EVENT: WORD = 0x0010;

    const COORD = extern struct { X: i16, Y: i16 };
    const SMALL_RECT = extern struct { Left: i16, Top: i16, Right: i16, Bottom: i16 };

    const CONSOLE_SCREEN_BUFFER_INFO = extern struct {
        dwSize: COORD,
        dwCursorPosition: COORD,
        wAttributes: WORD,
        srWindow: SMALL_RECT,
        dwMaximumWindowSize: COORD,
    };

    const KEY_EVENT_RECORD = extern struct {
        bKeyDown: BOOL,
        wRepeatCount: WORD,
        wVirtualKeyCode: WORD,
        wVirtualScanCode: WORD,
        uChar: extern union {
            UnicodeChar: WCHAR,
            AsciiChar: u8,
        },
        dwControlKeyState: DWORD,
    };

    const MOUSE_EVENT_RECORD = extern struct {
        dwMousePosition: COORD,
        dwButtonState: DWORD,
        dwControlKeyState: DWORD,
        dwEventFlags: DWORD,
    };

    const WINDOW_BUFFER_SIZE_RECORD = extern struct {
        dwSize: COORD,
    };

    const FOCUS_EVENT_RECORD = extern struct {
        bSetFocus: BOOL,
    };

    const INPUT_RECORD = extern struct {
        EventType: WORD,
        Event: extern union {
            KeyEvent: KEY_EVENT_RECORD,
            MouseEvent: MOUSE_EVENT_RECORD,
            WindowBufferSizeEvent: WINDOW_BUFFER_SIZE_RECORD,
            MenuEvent: extern struct { dwCommandId: u32 },
            FocusEvent: FOCUS_EVENT_RECORD,
        },
    };

    extern "kernel32" fn GetConsoleMode(hConsoleHandle: HANDLE, lpMode: *DWORD) callconv(.winapi) BOOL;
    extern "kernel32" fn SetConsoleMode(hConsoleHandle: HANDLE, dwMode: DWORD) callconv(.winapi) BOOL;
    extern "kernel32" fn GetConsoleScreenBufferInfo(
        hConsoleOutput: HANDLE,
        lpConsoleScreenBufferInfo: *CONSOLE_SCREEN_BUFFER_INFO,
    ) callconv(.winapi) BOOL;
    extern "kernel32" fn GetNumberOfConsoleInputEvents(hConsoleInput: HANDLE, lpcNumberOfEvents: *DWORD) callconv(.winapi) BOOL;
    extern "kernel32" fn ReadConsoleInputW(
        hConsoleInput: HANDLE,
        lpBuffer: [*]INPUT_RECORD,
        nLength: DWORD,
        lpNumberOfEventsRead: *DWORD,
    ) callconv(.winapi) BOOL;
    extern "kernel32" fn WaitForSingleObject(hHandle: HANDLE, dwMilliseconds: DWORD) callconv(.winapi) DWORD;
    extern "kernel32" fn GetConsoleCP() callconv(.winapi) u32;
    extern "kernel32" fn SetConsoleCP(wCodePageID: u32) callconv(.winapi) BOOL;
    extern "kernel32" fn GetConsoleOutputCP() callconv(.winapi) u32;
    extern "kernel32" fn SetConsoleOutputCP(wCodePageID: u32) callconv(.winapi) BOOL;
    extern "kernel32" fn SetConsoleCursorPosition(hConsoleOutput: HANDLE, dwCursorPosition: COORD) callconv(.winapi) BOOL;
    extern "kernel32" fn SetConsoleTextAttribute(hConsoleOutput: HANDLE, wAttributes: WORD) callconv(.winapi) BOOL;
    extern "kernel32" fn WriteConsoleW(
        hConsoleOutput: HANDLE,
        lpBuffer: [*]const WCHAR,
        nNumberOfCharsToWrite: DWORD,
        lpNumberOfCharsWritten: ?*DWORD,
        lpReserved: ?*anyopaque,
    ) callconv(.winapi) BOOL;
    extern "kernel32" fn FillConsoleOutputCharacterW(
        hConsoleOutput: HANDLE,
        cCharacter: WCHAR,
        nLength: DWORD,
        dwWriteCoord: COORD,
        lpNumberOfCharsWritten: *DWORD,
    ) callconv(.winapi) BOOL;
    extern "kernel32" fn FillConsoleOutputAttribute(
        hConsoleOutput: HANDLE,
        wAttribute: WORD,
        nLength: DWORD,
        dwWriteCoord: COORD,
        lpNumberOfAttrsWritten: *DWORD,
    ) callconv(.winapi) BOOL;
    extern "kernel32" fn GetConsoleTitleW(lpConsoleTitle: [*]WCHAR, nSize: DWORD) callconv(.winapi) DWORD;
    extern "kernel32" fn SetConsoleTitleW(lpConsoleTitle: [*]const WCHAR) callconv(.winapi) BOOL;

    allocator: std.mem.Allocator,
    io: std.Io,
    in_file: std.Io.File,
    out_file: std.Io.File,
    caps: TerminalCapabilities,
    orig_in_mode: ?DWORD = null,
    orig_out_mode: ?DWORD = null,
    orig_in_cp: ?u32 = null,
    orig_out_cp: ?u32 = null,
    orig_attrs: WORD = 0x07,
    orig_title_utf16: [256]WCHAR = @splat(0),
    orig_title_len: usize = 0,
    is_console_in: bool = false,
    is_console_out: bool = false,
    raw_active: bool = false,
    session: ansi_mod.SessionState = .{},
    pending_surrogate: ?u16 = null,
    last_mouse_buttons: DWORD = 0,
    out_buf: std.ArrayList(u8) = .empty,

    pub fn isSupported() bool {
        return true;
    }

    pub fn init(allocator: std.mem.Allocator, io: std.Io, color_override: ?caps_mod.Capability) WindowsBackend {
        const in_file = std.Io.File.stdin();
        const out_file = std.Io.File.stdout();

        var in_mode: DWORD = 0;
        const console_in = GetConsoleMode(in_file.handle, &in_mode).toBool();

        var out_mode: DWORD = 0;
        const console_out = GetConsoleMode(out_file.handle, &out_mode).toBool();

        const is_tty = (out_file.isTty(io) catch false) or console_out;
        var ansi_ok = (out_file.supportsAnsiEscapeCodes(io) catch false);
        if (!ansi_ok and console_out) {
            if (SetConsoleMode(out_file.handle, out_mode | ENABLE_PROCESSED_OUTPUT | ENABLE_VIRTUAL_TERMINAL_PROCESSING).toBool()) {
                ansi_ok = true;
                _ = SetConsoleMode(out_file.handle, out_mode);
            }
        }

        var orig_attrs: WORD = 0x07;
        if (console_out) {
            var csbi: CONSOLE_SCREEN_BUFFER_INFO = undefined;
            if (GetConsoleScreenBufferInfo(out_file.handle, &csbi).toBool()) {
                orig_attrs = csbi.wAttributes;
            }
        }

        return .{
            .allocator = allocator,
            .io = io,
            .in_file = in_file,
            .out_file = out_file,
            .caps = caps_mod.detect(is_tty, ansi_ok, color_override),
            .orig_in_mode = if (console_in) in_mode else null,
            .orig_out_mode = if (console_out) out_mode else null,
            .orig_attrs = orig_attrs,
            .is_console_in = console_in,
            .is_console_out = console_out,
        };
    }

    pub fn deinit(self: *WindowsBackend) void {
        self.restore();
        self.out_buf.deinit(self.allocator);
    }

    pub fn enter(self: *WindowsBackend, opts: EnterOptions) !void {
        if (self.is_console_out) {
            if (self.orig_title_len == 0) {
                const tlen = GetConsoleTitleW(&self.orig_title_utf16, self.orig_title_utf16.len - 1);
                if (tlen > 0 and tlen < self.orig_title_utf16.len) {
                    self.orig_title_utf16[tlen] = 0;
                    self.orig_title_len = tlen;
                }
            }
            if (self.orig_out_cp == null) self.orig_out_cp = GetConsoleOutputCP();
            _ = SetConsoleOutputCP(65001);
            if (self.orig_out_mode) |om| {
                if (self.caps.ansi_sequences) {
                    _ = SetConsoleMode(self.out_file.handle, om | ENABLE_PROCESSED_OUTPUT | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
                }
            }
        }
        if (opts.title) |t| {
            self.setTitle(t) catch {};
        }

        if (self.is_console_in and opts.raw_mode and !self.raw_active) {
            if (self.orig_in_cp == null) self.orig_in_cp = GetConsoleCP();
            _ = SetConsoleCP(65001);

            const base = self.orig_in_mode orelse 0;
            var new_mode: DWORD = (base & ~(ENABLE_ECHO_INPUT | ENABLE_LINE_INPUT | ENABLE_PROCESSED_INPUT | ENABLE_QUICK_EDIT_MODE | ENABLE_VIRTUAL_TERMINAL_INPUT)) |
                ENABLE_WINDOW_INPUT | ENABLE_EXTENDED_FLAGS;
            if (opts.mouse) {
                new_mode |= ENABLE_MOUSE_INPUT;
            }
            _ = SetConsoleMode(self.in_file.handle, new_mode);
            self.raw_active = true;
            self.session.mouse_active = opts.mouse;
        }

        if (self.caps.ansi_sequences) {
            self.out_buf.clearRetainingCapacity();
            var aw = std.Io.Writer.Allocating.fromArrayList(self.allocator, &self.out_buf);
            defer self.out_buf = aw.toArrayList();

            try ansi_mod.writeEnterSession(&aw.writer, &self.session, opts, self.caps);
            if (aw.writer.buffered().len > 0) {
                try self.writeAll(aw.writer.buffered());
            }
        }
    }

    pub fn restore(self: *WindowsBackend) void {
        if (self.caps.ansi_sequences) {
            self.out_buf.clearRetainingCapacity();
            var aw = std.Io.Writer.Allocating.fromArrayList(self.allocator, &self.out_buf);
            defer self.out_buf = aw.toArrayList();

            ansi_mod.writeLeaveSession(&aw.writer, &self.session) catch {};
            if (aw.writer.buffered().len > 0) {
                self.writeAll(aw.writer.buffered()) catch {};
            }
        }

        if (self.is_console_in) {
            if (self.orig_in_mode) |im| _ = SetConsoleMode(self.in_file.handle, im);
            if (self.orig_in_cp) |icp| _ = SetConsoleCP(icp);
            self.raw_active = false;
        }
        if (self.is_console_out) {
            if (self.orig_title_len > 0) {
                _ = SetConsoleTitleW(&self.orig_title_utf16);
                self.orig_title_len = 0;
            }
            _ = SetConsoleTextAttribute(self.out_file.handle, self.orig_attrs);
            if (self.orig_out_mode) |om| _ = SetConsoleMode(self.out_file.handle, om);
            if (self.orig_out_cp) |ocp| _ = SetConsoleOutputCP(ocp);
        }
    }

    pub fn setTitle(self: *WindowsBackend, title: []const u8) !void {
        if (self.is_console_out) {
            var wbuf: [256]WCHAR = undefined;
            const utf8_slice = title[0..@min(title.len, 255)];
            const wlen = std.unicode.utf8ToUtf16Le(&wbuf, utf8_slice) catch 0;
            if (wlen < wbuf.len) {
                wbuf[wlen] = 0;
                _ = SetConsoleTitleW(&wbuf);
            }
        }
        if (self.caps.ansi_sequences) {
            var tbuf: [300]u8 = undefined;
            var w = std.Io.Writer.fixed(&tbuf);
            ansi_mod.writeTitle(&w, title[0..@min(title.len, 256)]) catch return;
            try self.writeAll(w.buffered());
        }
    }

    pub fn size(self: *const WindowsBackend) Size {
        if (self.is_console_out) {
            var csbi: CONSOLE_SCREEN_BUFFER_INFO = undefined;
            if (GetConsoleScreenBufferInfo(self.out_file.handle, &csbi).toBool()) {
                const w: i32 = csbi.srWindow.Right - csbi.srWindow.Left + 1;
                const h: i32 = csbi.srWindow.Bottom - csbi.srWindow.Top + 1;
                if (w > 0 and h > 0) {
                    return .{ .width = @intCast(w), .height = @intCast(h) };
                }
            }
        }
        return .{ .width = 80, .height = 24 };
    }

    pub fn writeAll(self: *WindowsBackend, bytes: []const u8) !void {
        if (bytes.len == 0) return;
        try self.out_file.writeStreamingAll(self.io, bytes);
    }

    /// Fallback Win32 Console renderer when VT escape codes are unavailable (legacy cmd.exe).
    pub fn drawDiffWin32Fallback(self: *WindowsBackend, diff_iter: *BufferDiff) void {
        if (!self.is_console_out) return;
        var wbuf: [32]WCHAR = undefined;
        while (diff_iter.nextEntry()) |entry| {
            _ = SetConsoleCursorPosition(self.out_file.handle, .{
                .X = @intCast(entry.x),
                .Y = @intCast(entry.y),
            });
            const attr = styleToWin32Attrs(entry.cell.style(), self.orig_attrs);
            _ = SetConsoleTextAttribute(self.out_file.handle, attr);
            const sym = entry.cell.symbol();
            const n = std.unicode.utf8ToUtf16Le(&wbuf, sym) catch 0;
            if (n > 0) {
                _ = WriteConsoleW(self.out_file.handle, &wbuf, @intCast(n), null, null);
            }
        }
        _ = SetConsoleTextAttribute(self.out_file.handle, self.orig_attrs);
    }

    pub fn clearWin32Fallback(self: *WindowsBackend) void {
        if (!self.is_console_out) return;
        var csbi: CONSOLE_SCREEN_BUFFER_INFO = undefined;
        if (!GetConsoleScreenBufferInfo(self.out_file.handle, &csbi).toBool()) return;
        const cells: DWORD = @intCast(@as(i32, csbi.dwSize.X) * @as(i32, csbi.dwSize.Y));
        var written: DWORD = 0;
        _ = FillConsoleOutputCharacterW(self.out_file.handle, ' ', cells, .{ .X = 0, .Y = 0 }, &written);
        _ = FillConsoleOutputAttribute(self.out_file.handle, self.orig_attrs, cells, .{ .X = 0, .Y = 0 }, &written);
        _ = SetConsoleCursorPosition(self.out_file.handle, .{ .X = 0, .Y = 0 });
    }

    pub fn pollEvent(self: *WindowsBackend, parser: *EventParser, timeout_ms: i32) !Event {
        if (!self.is_console_in) {
            if (try parser.nextEvent(false)) |ev| return ev;
            var tmp: [256]u8 = undefined;
            const n = self.in_file.readStreaming(self.io, &.{&tmp}) catch |err| switch (err) {
                error.EndOfStream, error.WouldBlock => 0,
                else => return err,
            };
            if (n > 0) {
                _ = parser.feed(tmp[0..n]);
                if (try parser.nextEvent(false)) |ev| return ev;
            }
            if (parser.hasPending()) {
                if (try parser.nextEvent(true)) |ev| return ev;
            }
            return .none;
        }

        const wait_ms: DWORD = if (timeout_ms < 0) INFINITE else @intCast(timeout_ms);
        const start_ts = std.Io.Clock.Timestamp.now(self.io, .awake);

        while (true) {
            var count: DWORD = 0;
            if (!GetNumberOfConsoleInputEvents(self.in_file.handle, &count).toBool() or count == 0) {
                if (wait_ms == 0) return .none;
                const rem: DWORD = if (wait_ms == INFINITE) INFINITE else blk: {
                    const elapsed_ms: i64 = @intCast(@max(@as(i96, 0), start_ts.untilNow(self.io).raw.toMilliseconds()));
                    if (elapsed_ms >= wait_ms) return .none;
                    break :blk @intCast(wait_ms - elapsed_ms);
                };
                const wr = WaitForSingleObject(self.in_file.handle, rem);
                if (wr != WAIT_OBJECT_0) return .none;
                continue;
            }
            var rec: [1]INPUT_RECORD = undefined;
            var read_count: DWORD = 0;
            if (!ReadConsoleInputW(self.in_file.handle, &rec, 1, &read_count).toBool() or read_count == 0) {
                return .none;
            }
            if (self.translateInputRecord(rec[0])) |ev| {
                return ev;
            }
        }
    }

    fn translateInputRecord(self: *WindowsBackend, rec: INPUT_RECORD) ?Event {
        switch (rec.EventType) {
            KEY_EVENT => {
                const ke = rec.Event.KeyEvent;
                const mods = decodeWinModifiers(ke.dwControlKeyState);
                const kind: KeyEventKind = if (!ke.bKeyDown.toBool())
                    .release
                else if (ke.wRepeatCount > 1)
                    .repeat
                else
                    .press;

                const wchar = ke.uChar.UnicodeChar;
                if (wchar >= 0xD800 and wchar <= 0xDBFF) {
                    self.pending_surrogate = wchar;
                    return null;
                }
                if (wchar >= 0xDC00 and wchar <= 0xDFFF) {
                    if (self.pending_surrogate) |hi| {
                        self.pending_surrogate = null;
                        const cp: u21 = 0x10000 + ((@as(u21, hi - 0xD800) << 10) | @as(u21, wchar - 0xDC00));
                        return .{ .key = .{ .code = .{ .char = cp }, .modifiers = mods, .kind = kind } };
                    }
                    return null;
                }
                self.pending_surrogate = null;

                if (vkToKeyCode(ke.wVirtualKeyCode, mods.shift)) |special| {
                    return .{ .key = .{ .code = special, .modifiers = mods, .kind = kind } };
                }

                if (wchar != 0) {
                    const ch: u21 = if (mods.ctrl and wchar >= 1 and wchar <= 26)
                        'a' + (wchar - 1)
                    else
                        wchar;
                    return .{ .key = .{ .code = .{ .char = ch }, .modifiers = mods, .kind = kind } };
                }
                return null;
            },
            MOUSE_EVENT => {
                const me = rec.Event.MouseEvent;
                const mods = decodeWinModifiers(me.dwControlKeyState);
                const x: u16 = @intCast(@max(0, me.dwMousePosition.X));
                const y: u16 = @intCast(@max(0, me.dwMousePosition.Y));

                const MOUSE_MOVED: DWORD = 0x0001;
                const MOUSE_WHEELED: DWORD = 0x0004;
                const MOUSE_HWHEELED: DWORD = 0x0008;

                if ((me.dwEventFlags & MOUSE_WHEELED) != 0) {
                    const delta: i16 = @bitCast(@as(u16, @truncate(me.dwButtonState >> 16)));
                    return .{ .mouse = .{
                        .kind = if (delta > 0) .scroll_up else .scroll_down,
                        .x = x,
                        .y = y,
                        .modifiers = mods,
                    } };
                }
                if ((me.dwEventFlags & MOUSE_HWHEELED) != 0) {
                    const delta: i16 = @bitCast(@as(u16, @truncate(me.dwButtonState >> 16)));
                    return .{ .mouse = .{
                        .kind = if (delta > 0) .scroll_right else .scroll_left,
                        .x = x,
                        .y = y,
                        .modifiers = mods,
                    } };
                }

                const prev = self.last_mouse_buttons;
                const curr = me.dwButtonState;
                self.last_mouse_buttons = curr;

                const btn = buttonFromState(curr ^ prev);
                if ((me.dwEventFlags & MOUSE_MOVED) != 0) {
                    const active = buttonFromState(curr);
                    return .{ .mouse = .{
                        .kind = if (active == .none) .moved else .drag,
                        .button = active,
                        .x = x,
                        .y = y,
                        .modifiers = mods,
                    } };
                }

                if (curr > prev) {
                    return .{ .mouse = .{ .kind = .down, .button = btn, .x = x, .y = y, .modifiers = mods } };
                }
                if (curr < prev) {
                    return .{ .mouse = .{ .kind = .up, .button = btn, .x = x, .y = y, .modifiers = mods } };
                }
                return null;
            },
            WINDOW_BUFFER_SIZE_EVENT => {
                const sz = self.size();
                return .{ .resize = sz };
            },
            FOCUS_EVENT => {
                return if (rec.Event.FocusEvent.bSetFocus.toBool()) .focus_gained else .focus_lost;
            },
            else => return null,
        }
    }

    fn decodeWinModifiers(state: DWORD) KeyModifiers {
        const RIGHT_ALT_PRESSED: DWORD = 0x0001;
        const LEFT_ALT_PRESSED: DWORD = 0x0002;
        const RIGHT_CTRL_PRESSED: DWORD = 0x0004;
        const LEFT_CTRL_PRESSED: DWORD = 0x0008;
        const SHIFT_PRESSED: DWORD = 0x0010;
        return .{
            .shift = (state & SHIFT_PRESSED) != 0,
            .ctrl = (state & (LEFT_CTRL_PRESSED | RIGHT_CTRL_PRESSED)) != 0,
            .alt = (state & (LEFT_ALT_PRESSED | RIGHT_ALT_PRESSED)) != 0,
        };
    }

    fn buttonFromState(mask: DWORD) MouseButton {
        if ((mask & 0x0001) != 0) return .left;
        if ((mask & 0x0002) != 0) return .right;
        if ((mask & 0x0004) != 0) return .middle;
        if ((mask & 0x0008) != 0) return .extra1;
        if ((mask & 0x0010) != 0) return .extra2;
        return .none;
    }

    fn vkToKeyCode(vk: WORD, shift: bool) ?KeyCode {
        return switch (vk) {
            0x08 => .backspace,
            0x09 => if (shift) .back_tab else .tab,
            0x0D => .enter,
            0x1B => .escape,
            0x21 => .page_up,
            0x22 => .page_down,
            0x23 => .end,
            0x24 => .home,
            0x25 => .left,
            0x26 => .up,
            0x27 => .right,
            0x28 => .down,
            0x2D => .insert,
            0x2E => .delete,
            0x70...0x87 => .{ .f = @intCast(vk - 0x70 + 1) },
            else => null,
        };
    }

    fn styleToWin32Attrs(s: @import("../style/root.zig").Style, fallback: WORD) WORD {
        var attr: WORD = fallback;
        const fg_downgraded = s.foreground.downgrade(.ansi16);
        if (fg_downgraded.toTint()) |tc| {
            if (tc == .ansi4 and tc.ansi4 != .default) {
                attr = (attr & 0xFFF0) | ansi4ToWinFg(tc.ansi4);
            }
        }
        const bg_downgraded = s.background.downgrade(.ansi16);
        if (bg_downgraded.toTint()) |tc| {
            if (tc == .ansi4 and tc.ansi4 != .default) {
                attr = (attr & 0xFF0F) | (ansi4ToWinFg(tc.ansi4) << 4);
            }
        }
        if (s.reverse) {
            const fg_bits = attr & 0x0F;
            const bg_bits = (attr >> 4) & 0x0F;
            attr = (attr & 0xFF00) | (fg_bits << 4) | bg_bits;
        }
        if (s.effectiveUnderline() != .none) {
            // COMMON_LVB_UNDERSCORE on legacy non-VT Win32 Console attributes.
            attr |= 0x8000;
        }
        return attr;
    }

    fn ansi4ToWinFg(a: @import("../style/root.zig").Ansi4) WORD {
        return switch (a) {
            .black => 0,
            .red => win.FOREGROUND_RED,
            .green => win.FOREGROUND_GREEN,
            .yellow => win.FOREGROUND_RED | win.FOREGROUND_GREEN,
            .blue => win.FOREGROUND_BLUE,
            .magenta => win.FOREGROUND_RED | win.FOREGROUND_BLUE,
            .cyan => win.FOREGROUND_GREEN | win.FOREGROUND_BLUE,
            .white => win.FOREGROUND_RED | win.FOREGROUND_GREEN | win.FOREGROUND_BLUE,
            .brightBlack => win.FOREGROUND_INTENSITY,
            .brightRed => win.FOREGROUND_RED | win.FOREGROUND_INTENSITY,
            .brightGreen => win.FOREGROUND_GREEN | win.FOREGROUND_INTENSITY,
            .brightYellow => win.FOREGROUND_RED | win.FOREGROUND_GREEN | win.FOREGROUND_INTENSITY,
            .brightBlue => win.FOREGROUND_BLUE | win.FOREGROUND_INTENSITY,
            .brightMagenta => win.FOREGROUND_RED | win.FOREGROUND_BLUE | win.FOREGROUND_INTENSITY,
            .brightCyan => win.FOREGROUND_GREEN | win.FOREGROUND_BLUE | win.FOREGROUND_INTENSITY,
            .brightWhite => win.FOREGROUND_RED | win.FOREGROUND_GREEN | win.FOREGROUND_BLUE | win.FOREGROUND_INTENSITY,
            .default => 0x07,
        };
    }
};

test "windows backend availability compiles cleanly" {
    try testing.expectEqual(is_windows, WindowsBackend.isSupported());
}
