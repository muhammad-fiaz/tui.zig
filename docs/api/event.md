# Event

Event types and input parsing used by the framework. Events are produced by the platform/input layer and dispatched to widgets.

Key types:
- `Event` (union enum) - `.key`, `.mouse`, `.resize`, `.tick`, `.custom`, etc.
- `EventResult` - `.ignored`, `.consumed`, `.needs_redraw`, `.request_focus`, `.yield_focus`
- `InputReader` - Parse raw bytes into `Event`s

See `src/event/events.zig` and `src/event/input.zig` for details.