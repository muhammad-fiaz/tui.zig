# Widget

Widget conventions and helper utilities.

Widgets follow the simple duck-typed API:
- `pub fn render(self: *T, ctx: *tui.RenderContext) void`
- `pub fn handleEvent(self: *T, event: tui.Event) tui.EventResult`
- `pub fn sizeHint(self: *T) tui.SizeHint`

`StatefulWidget` provides a small base for stateful widgets (focus, hovered, disabled, dirty).

See `src/widgets/widget.zig` for full details.