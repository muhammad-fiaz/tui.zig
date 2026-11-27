---
title: Unicode & Text Wrapping
description: Grapheme cluster segmentation, wide CJK/emoji widths, rich Span/Line composition, OSC 8 links, word/char wrapping, and truncation.
keywords: zig unicode width, grapheme cluster tui, word wrapping, Span Line Text, Masked password
---

# Unicode & Text Wrapping

Terminal cells do not map 1:1 with UTF-8 bytes or Unicode codepoints. Combining accents occupy **0 columns**, ASCII occupies **1 column**, and CJK ideographs and emoji occupy **2 columns**.

## Measuring & Truncating Text Safely

- `tui.text.displayWidth(slice)` — computes exact terminal column width across grapheme clusters.
- `tui.text.GraphemeIterator` — walks cluster-by-cluster yielding `(slice, width)`.
- `tui.text.truncateInto(slice, max_width, mode, out_buf)` — truncates cleanly to `.end` (`"text…"`), `.start` (`"…text"`), `.middle` (`"te…xt"`), or `.clip` with zero heap allocations.
- `tui.Masked.init(secret)` — renders masked secret previews (`••••`) without allocating raw copies.

## Rich Styled Lines (`Span`, `Line`, `Text`)

Build colored inline text and clickable OSC 8 hyperlinks pointing into static or stack buffers:

```zig
const spans = [_]tui.Span{
    tui.Span.styled("Docs: ", ui.theme.muted),
    tui.Span.link("tui.zig", "https://muhammad-fiaz.github.io/tui.zig/"),
};
const lines = [_]tui.Line{
    tui.Line.fromSpans(&spans).aligned(.center),
};
try ui.paragraph(.{
    .text = tui.Text.fromLines(&lines),
    .wrap = .word,
}, area);
```

## Word & Character Wrapping

`Paragraph` supports `.wrap = .none`, `.word`, or `.char`, preserving per-span foreground, background, underline, hyperlink, and modifier attributes across wrapped rows.

## Multi-Script, RTL Ordering & Custom Fonts

- Combining marks across Arabic, Devanagari, Thai, Latin, and emoji clusters measure 0 columns cleanly.
- Use `tui.text.TextDirection`, `tui.text.detectDirection`, and `tui.text.visualOrderInto` alongside `tui.Locale` and client `tui.BitmapFont` banners—see [Custom Fonts, Symbols & Internationalization](/guides/fonts-and-i18n).
