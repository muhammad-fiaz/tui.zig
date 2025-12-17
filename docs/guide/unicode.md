# Unicode Support

TUI.zig is built with full Unicode support in mind.

## Grapheme Clusters

The library correctly handles grapheme clusters, meaning complex characters (like emojis with modifiers or combined accents) are treated as single visual units.

- "e" + "´" = "é" (1 grapheme)
- "👨" + "‍" + "👩" + "‍" + "👧" = Family emoji (1 grapheme)

## Display Width

We use the standard `wcwidth` logic to determine how many terminal cells a character occupies:

- Standard Latin: 1 cell
- CJK Characters: 2 cells
- Emojis: 2 cells
- Combining marks: 0 cells (rendered atop previous)

## API

The `unicode` module provides utilities:

```zig
const width = tui.unicode.stringWidth("Hello 🌍");
// width = 6 (Hello) + 1 (space) + 2 (🌍) = 9
```

## Fonts

Note that correct rendering ultimately depends on the user's terminal emulator and font support.
