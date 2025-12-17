# Checkbox Widget

A toggleable checkbox.

## Import

```zig
const tui = @import("tui");
const Checkbox = tui.widgets.Checkbox;
```

## Usage

```zig
var check = Checkbox.init("Enable Logging");
```

## Initial State

```zig
check.setChecked(true);
```

## Checking State

```zig
if (check.isChecked()) {
    // ...
}
```

## Styling

You can customize the checked/unchecked symbols and styles.
