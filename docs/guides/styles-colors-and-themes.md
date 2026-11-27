---
title: Styles, Colors & Themes
description: TrueColor RGB/HSL/HSV/Hex/OKLCH, OKLCH Color color palettes across 26 families, automatic ANSI downgrade, SGR modifiers, borders, and 17 built-in themes.
keywords: tui.zig themes, OKLCH Color colors, oklch terminal colors, truecolor zig, tui Style
---

# Styles, Colors & Themes

**tui.zig** pairs full 24-bit color precision, including native OKLCH support and official **OKLCH Color** palettes, with automatic perceptual downgrade on ANSI-256, ANSI-16, and monochrome terminals.

## Creating Colors

- **ANSI-16 & Aliases**: `.black`, `.red`, `.green`, `.yellow`, `.blue`, `.magenta`, `.cyan`, `.white`, `.bright_cyan`, `.gray`, `.dark_gray`
- **Extended Named Colors**: `.coral`, `.crimson`, `.gold`, `.indigo`, `.orange`, `.teal`, `.turquoise`, `.violet`, etc.
- **24-bit TrueColor & OKLCH**: `tui.Color.rgb(r, g, b)`, `tui.Color.hex(0x38bdf8)`, `tui.Color.hsl(h, s, l)`, `tui.Color.hsv(h, s, v)`, `tui.Color.oklch(0.68, 0.21, 150.0)`, or runtime parsing `tui.Color.parse("#f7a41d")`
- **256-Color Palette**: `tui.Color.indexed(214)`

## OKLCH Color Palettes (`tui.palette`)

All 26 OKLCH Color color families (`red`, `orange`, `amber`, `yellow`, `lime`, `green`, `emerald`, `teal`, `cyan`, `sky`, `blue`, `indigo`, `violet`, `purple`, `fuchsia`, `pink`, `rose`, `slate`, `gray`, `zinc`, `neutral`, `stone`, `mauve`, `olive`, `mist`, `taupe`) are computed at compile time from OKLCH Color's OKLCH definitions with stops `c50`..`c950` (plus `black` and `white`):

```zig
const accent_fg = tui.palette.sky.c400;
const panel_bg = tui.palette.slate.c900;
const ok_fg = tui.palette.emerald.c400;
```

## Composing `Style`s & `Modifiers`

`Style` structs default to inheriting unspecified properties (`.inherit` colors and unset modifier flags):

```zig
const highlight = tui.Style{
    .foreground = tui.palette.amber.c400,
    .background = tui.palette.slate.c900,
    .bold = true,
    .underline_style = .curly,
    .underline_color = tui.palette.sky.c400,
    .hyperlink = "https://muhammad-fiaz.github.io/tui.zig/",
};

// Patch an existing theme style cleanly:
const title_style = ui.theme.text.patch(highlight);
```

All underline styles (`.single`, `.double`, `.curly`, `.dotted`, `.dashed`), `.underline_color`, and `.reverse` highlights transition cleanly across ANSI SGR output as well as Windows legacy console fallback (`COMMON_LVB_UNDERSCORE`). Use `tui.symbols.icons` (`.unicode`, `.ascii`, `.nerd`) for portable status glyphs.

## 17 Built-in Theme Presets & Custom JSON Themes

Switch themes dynamically at runtime with `app.setTheme(tui.Theme.nord)` or parse custom themes from JSON via `try tui.core.config.parseThemeJson(allocator, json_bytes)`:

- `dark`, `light`, `dracula`, `nord`, `monokai`, `tokyo_night`, `gruvbox`, `solarized`, `rose_pine`, `catppuccin`, `github`, `one_dark`, `material`, `palenight`, `everforest`, `kanagawa`, `cyberdream`

Every `Theme` exposes semantic roles (`.surface`, `.text`, `.muted`, `.border`, `.border_focused`, `.title`, `.accent`, `.secondary`, `.selection`, `.button`, `.button_focused`, `.disabled`, `.input`, `.input_focused`, `.success`, `.warning`, `.err`, `.info`) respected across all built-in widgets.
