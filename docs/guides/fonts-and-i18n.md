---
title: Custom Fonts, Symbols & Internationalization (i18n)
description: Render custom client BitmapFont glyphs, Unicode/Nerd/ASCII icon presets, multi-script UTF-8, RTL visual ordering, Locale translations, decimal formatting, and localized Calendar widgets.
keywords: tui.zig custom font, BitmapFont, FontRenderMode, zig i18n, RTL terminal zig, Locale calendar, symbols icons
---

# Custom Fonts, Symbols & Internationalization

**tui.zig** gives client applications full ownership of custom bitmap fonts, symbol sets, right-to-left (`RTL`) script reordering, localization catalogs (`Locale` — a pure client-owned struct with zero built-in language presets), and localized calendar labels.

## Custom Client Fonts (`BitmapFont`, `BitmapGlyph`, `BigText`)

`BigText` ships with two built-in monospace bitmap fonts (`BitmapFont.block_3x5` for full printable ASCII and `BitmapFont.sans_5x7`) and renders across four `FontRenderMode` presets: `.full_block`, `.half_block`, `.quadrant`, and `.braille`.

Client applications can supply bespoke Unicode glyphs (`BitmapGlyph`) or dynamic glyph lookup callbacks (`lookup_fn`) and chain to a `.fallback` font (`BitmapFont.measurePixels` tracks the tallest resolved glyph height across fallback fonts, and `sans_5x7` folds common accented Latin characters automatically):

```zig
const custom_glyphs = [_]tui.BitmapGlyph{
    .{
        .codepoint = '★',
        .width = 5,
        .height = 7,
        .rows = &.{ 0b00100, 0b00100, 0b11111, 0b01110, 0b01110, 0b11011, 0b10001 },
    },
};

const client_font = tui.BitmapFont{
    .name = "brand",
    .default_width = 5,
    .height = 7,
    .glyphs = &custom_glyphs,
    .fallback = &tui.BitmapFont.sans_5x7,
};

try ui.bigText(.{
    .text = "★ ZIG",
    .font = &client_font,
    .mode = .half_block,
    .direction = .ltr,
    .alignment = .center,
}, banner_area);
```

## Icon Presets (`tui.symbols.icons`)

Switch cleanly between Unicode, ASCII-only, and Nerd Font glyphs using `tui.symbols.IconSet`:

- `tui.symbols.icons.unicode` (`✓`, `✗`, `★`, `▶`, `▾`, `⚠`, `ℹ`, etc.)
- `tui.symbols.icons.ascii` (`[+]`, `[x]`, `*`, `>`, `v`, `!`, `i`, etc.)
- `tui.symbols.icons.nerd` (Nerd Font PUA codepoints for file/branch/terminal badges)

## Multi-Script Text, `Locale` & RTL Ordering

Combining marks across Latin, Arabic, Devanagari, Thai, Cyrillic, Greek, CJK, and emoji sequences measure zero width while wide ideographs and emoji occupy 2 columns cleanly.

For single-language or multilingual apps, clients define explicit `tui.Locale` tables for every language they support to translate strings, format regional decimals, customize calendar month/weekday headers, and align or reverse `RTL` runs cleanly into stack buffers:

```zig
const loc_ar = tui.Locale{
    .code = "ar",
    .direction = .rtl,
    .months = .{
        "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
        "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
    },
    .weekdays = .{ "أح", "إث", "ثل", "أر", "خم", "جم", "سب" },
    .entries = &.{
        .{ .key = "greeting", .value = "مرحبا بكم في مكتبة زيج" },
    },
};

var rtl_buf: [128]u8 = undefined;
const raw = loc_ar.trOr("greeting", "Welcome");
const visual = tui.text.visualOrderInto(raw, loc_ar.direction, &rtl_buf);
const alignment: tui.Alignment = if (loc_ar.resolveDirection(raw) == .rtl) .right else .left;
try ui.text(visual, .{ .alignment = alignment }, null);
```

Number formatting and localized `Calendar` grids share the same locale definition (with `.direction = .rtl` reversing weekday columns right-to-left for both rendering and `handleEventAt` click coordinates):

```zig
var dec_buf: [32]u8 = undefined;
const formatted = loc.formatDecimal(98.45, "{d:.2}", &dec_buf); // "98,45" when decimal_separator = ','

try ui.calendar(.{
    .month_names = loc.months,
    .weekday_names = loc.weekdays,
    .direction = loc.direction,
    .block = .{ .title = "Schedule" },
}, &state.cal, cal_area);
```

Run `zig build run-custom-fonts-i18n` to explore runtime language switching (`l`) and font raster modes (`m`).
