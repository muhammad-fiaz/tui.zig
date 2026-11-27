//! Localization utilities for `tui.zig` widgets.
//!
//! `Locale` is a pure client-owned data struct with zero built-in language data.
//! All language content — month names, weekday headers, translation catalogs, decimal
//! separators, and script directions — is defined explicitly by the calling application.
//!
//! Zero heap allocations: all fields are slices into caller-owned, comptime, or static memory.

const std = @import("std");
const grapheme = @import("grapheme.zig");
const testing = std.testing;

pub const TextDirection = grapheme.TextDirection;

/// Key/value translation entry for client-supplied language catalogs.
pub const LocaleEntry = struct {
    key: []const u8,
    value: []const u8,
};

/// Client-configurable language and region settings for `tui.zig` widgets.
///
/// No built-in locale presets exist. Applications define all `Locale` instances
/// explicitly, including any English defaults they want:
///
/// ```zig
/// const loc = tui.Locale{
///     .code = "en",
///     .direction = .ltr,
///     .months = .{ "January", "February", "March", "April",
///                  "May", "June", "July", "August",
///                  "September", "October", "November", "December" },
///     .weekdays = .{ "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" },
///     .entries = &.{
///         .{ .key = "confirm", .value = "Confirm" },
///         .{ .key = "cancel",  .value = "Cancel" },
///     },
/// };
/// ```
pub const Locale = struct {
    /// BCP-47 language code (e.g. `"en"`, `"es"`, `"ar"`).
    code: []const u8 = "en",
    /// Script layout direction (`.ltr`, `.rtl`, or `.auto`).
    direction: TextDirection = .ltr,
    /// Translation pairs searched in order by `tr`. Empty slice disables translation lookup.
    entries: []const LocaleEntry = &.{},
    /// Optional 12 localized month names (`January`..`December` order).
    months: ?[12][]const u8 = null,
    /// Optional 7 localized short weekday headers (`Sunday`..`Saturday` order).
    weekdays: ?[7][]const u8 = null,
    /// Decimal separator character (`'.'` or `','`).
    decimal_separator: u8 = '.',

    /// Looks up `key` inside `self.entries`, returning `null` if absent.
    pub fn tr(self: Locale, key: []const u8) ?[]const u8 {
        for (self.entries) |entry| {
            if (std.mem.eql(u8, entry.key, key)) return entry.value;
        }
        return null;
    }

    /// Looks up `key` inside `self.entries`, falling back to `fallback`.
    pub fn trOr(self: Locale, key: []const u8, fallback: []const u8) []const u8 {
        return self.tr(key) orelse fallback;
    }

    /// Resolves effective direction for `sample` (respects `.auto` detection or explicit locale direction).
    pub fn resolveDirection(self: Locale, sample: []const u8) TextDirection {
        if (self.direction != .auto) return self.direction;
        return grapheme.detectDirection(sample);
    }

    /// Formats a decimal number using `self.decimal_separator` into `out_buf`.
    pub fn formatDecimal(self: Locale, val: f64, comptime fmt_spec: []const u8, out_buf: []u8) []const u8 {
        const s = std.fmt.bufPrint(out_buf, fmt_spec, .{val}) catch return "";
        if (self.decimal_separator != '.') {
            for (out_buf[0..s.len]) |*b| {
                if (b.* == '.') b.* = self.decimal_separator;
            }
        }
        return out_buf[0..s.len];
    }
};

test "Locale is a plain client-owned struct with no built-in presets" {
    // All locale data is defined explicitly by the caller.
    const loc_en = Locale{
        .code = "en",
        .direction = .ltr,
        .months = .{
            "January",   "February", "March",    "April",
            "May",       "June",     "July",     "August",
            "September", "October",  "November", "December",
        },
        .weekdays = .{ "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" },
        .entries = &.{
            .{ .key = "confirm", .value = "Confirm" },
        },
    };
    try testing.expectEqualStrings("en", loc_en.code);
    try testing.expectEqualStrings("January", loc_en.months.?[0]);
    try testing.expectEqualStrings("Confirm", loc_en.trOr("confirm", "OK"));

    const loc_es = Locale{
        .code = "es",
        .direction = .ltr,
        .decimal_separator = ',',
        .entries = &.{
            .{ .key = "confirm", .value = "Confirmar" },
            .{ .key = "cancel", .value = "Cancelar" },
        },
    };
    try testing.expectEqualStrings("Confirmar", loc_es.trOr("confirm", "Confirm"));
    try testing.expectEqualStrings("Missing", loc_es.trOr("unknown", "Missing"));

    var num_buf: [32]u8 = undefined;
    try testing.expectEqualStrings("12,50", loc_es.formatDecimal(12.5, "{d:.2}", &num_buf));

    const auto_loc = Locale{ .code = "auto", .direction = .auto };
    try testing.expectEqual(TextDirection.rtl, auto_loc.resolveDirection("مرحبا"));
    try testing.expectEqual(TextDirection.ltr, auto_loc.resolveDirection("Hello"));
}
