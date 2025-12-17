# Modal Widget

A pop-up dialog that overlays other content.

## Import

```zig
const tui = @import("tui");
const Modal = tui.widgets.Modal;
```

## Usage

```zig
var modal = Modal.init(allocator)
    .withTitle("Confirmation")
    .withContent(&message_widget) // Center content
    .withButtons(.{ "Yes", "No" }); // Action buttons
```

## Displaying

Call `modal.show()` to make it visible. The widget handles drawing the overlay (dimmed background) and the dialog box centered on screen.

## Handling Actions

Check `modal.getResult()` or handle button clicks in your event loop.
