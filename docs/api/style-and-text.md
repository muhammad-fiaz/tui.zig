---
title: Style, Colors, Palettes, Themes & Text API
description: Reference for Color, OKLCH, OKLCH Color Palettes, Style, OSC 8 hyperlinks, Borders, Theme, Span, Line, Text, Masked, WrapIterator, and GraphemeIterator.
keywords: tui.Color, OKLCH Color, oklch, tui.Style, OSC 8 hyperlinks, tui.Theme, tui.BorderType, tui.Span
---

# Style, Colors, Palettes, Themes & Text

## `Color`, `palette` & `Style`

- **Constructors**: `.inherit`, `.reset`, `.black`..`.bright_white`, `.gray`, `.dark_gray`, CSS named colors, `Color.rgb(r, g, b)`, `Color.hex(u24)`, `Color.hsl(h, s, l)`, `Color.hsv(h, s, v)`, `Color.oklch(l, c, h)`, `Color.indexed(u8)`, `Color.parse([]const u8)`
- **OKLCH Color Scales** (`tui.palette`): `.red`, `.orange`, `.amber`, `.yellow`, `.lime`, `.green`, `.emerald`, `.teal`, `.cyan`, `.sky`, `.blue`, `.indigo`, `.violet`, `.purple`, `.fuchsia`, `.pink`, `.rose`, `.slate`, `.gray`, `.zinc`, `.neutral`, `.stone`, `.mauve`, `.olive`, `.mist`, `.taupe` (`c50`..`c950`, plus `.black` and `.white`)
- **Gradients**: `tui.palette.gradientColors(out, &stops)` interpolates multi-stop TrueColor ramps
- **Operations**: `.isInherit()`, `.downgrade(Capability)`, `.luminance()`, `.contrastRatio(other)`
- **`Style`**: `.foreground`, `.background`, `.underline_color`, `.bold`, `.dim`, `.italic`, `.underline`, `.blink`, `.rapid_blink`, `.reverse`, `.hidden`, `.strikethrough`, `.overline`, `.underline_style: UnderlineStyle`, `.hyperlink: ?[]const u8`, `.remove: Modifiers`
  - `style.patch(other)` and `style.withLink(url)` merge colors, modifiers, and hyperlinks cleanly

## Borders & Symbols

- `BorderSides`: `.none`, `.all`, `.horizontal`, `.vertical`, or individual `.top`, `.right`, `.bottom`, `.left`
- `BorderType`: `.plain`, `.rounded`, `.double`, `.thick`, `.ascii`, `.light_double_dashed`, `.heavy_double_dashed`, `.light_triple_dashed`, `.heavy_triple_dashed`, `.light_quadruple_dashed`, `.heavy_quadruple_dashed`, `.quadrant_outside`, `.quadrant_inside`, `.one_eighth_wide`, `.one_eighth_tall`, `.full`, `.empty`
- `MergeStrategy`: `.replace`, `.exact`, `.fuzzy`
- `symbols`: `.line`, `.block`, `.bar`, `.scrollbar`, `.checkbox`, `.radio`, `.tree`, `.spinner`, `.quadrants`, `.braille_dot_bits`, `.encodeBrailleMask`, `.icons` (`IconSet`: `.unicode`, `.ascii`, `.nerd`)

## Text, Custom Fonts & Internationalization (`i18n`)

- `Span.raw(text)` / `Span.styled(text, style)` / `Span.link(label, url)` / `.withLink(url)`
- `Line.fromSpans(spans)` / `Line.fromSingle(slot, content, style)` / `.aligned(align)` / `.patchStyle(s)`
- `Text.fromLines(lines)` / `.width()` / `.height()`
- `Masked.init(secret)` (`formatInto`, `toSpan`, `graphemeCount`)
- `WrapMode`: `.none`, `.word`, `.char`
- `Truncation`: `.clip`, `.end`, `.start`, `.middle`
- `tui.text.displayWidth(slice)`, `tui.text.GraphemeIterator`, `tui.text.WrapIterator`, `tui.text.truncateInto`
- `BitmapGlyph`, `FontRenderMode` (`.full_block`, `.half_block`, `.quadrant`, `.braille`), `BitmapFont` (`.block_3x5`, `.sans_5x7`, `.glyphs`, `.lookup_fn`, `.fallback`, `measurePixels`)
- `Locale`, `LocaleEntry` (pure client-owned `.code`, `.direction`, `.entries`, `.months`, `.weekdays`, `.decimal_separator`, `.tr`, `.trOr`, `.resolveDirection`, `.formatDecimal` with zero built-in presets)
- `TextDirection` (`.ltr`, `.rtl`, `.auto`), `tui.text.isRtlCodepoint`, `tui.text.detectDirection`, `tui.text.visualOrderInto`
