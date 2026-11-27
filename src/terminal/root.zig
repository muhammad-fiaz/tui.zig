//! Centralized `App` runtime and double-buffered terminal session management.

const testing = @import("std").testing;

pub const app = @import("app.zig");

pub const App = app.App;

test {
    testing.refAllDecls(@This());
    testing.refAllDecls(app);
}
