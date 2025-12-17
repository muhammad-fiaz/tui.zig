# Style

`Style` describes text attributes (fg/bg color, bold, underline, etc.).

Use `Style` to build consistent styling and merge with theme values.

```zig
const s = tui.Style.default
    .setFg(tui.Color.cyan)
    .bold();
```

See `src/style/style.zig` for full API.