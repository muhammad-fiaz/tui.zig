const std = @import("std");
const tui = @import("tui");

const EmailSchema = tui.schema.email(.{});

const State = struct {
    email: tui.TextInputState,
    notes: tui.TextAreaState,
    focus: tui.FocusGroup = .{ .count = 2 },
    submitted_count: usize = 0,
    email_rect: tui.Rect = tui.Rect.zero,
    notes_rect: tui.Rect = tui.Rect.zero,

    fn deinit(self: *State) void {
        self.email.deinit();
        self.notes.deinit();
    }
};

fn onEvent(state: *State, event: tui.Event, app: *tui.App) !bool {
    if (event.isEscape() or event.isCtrlC()) {
        app.quit();
        return false;
    }
    if (state.focus.handleEvent(event)) return true;

    if (event == .mouse and event.mouse.kind == .down and event.mouse.button == .left) {
        if (event.mouse.isInside(state.email_rect)) state.focus.active = 0;
        if (event.mouse.isInside(state.notes_rect)) state.focus.active = 1;
        return true;
    }

    if (state.focus.isFocused(0)) {
        const act = try state.email.handleEvent(event, true);
        if (act == .submitted) state.submitted_count += 1;
    } else {
        _ = try state.notes.handleEvent(event, true);
    }
    return true;
}

fn render(state: *State, ui: *tui.Ui) !void {
    ui.fillThemeSurface();
    const layout = ui.rows(3, .{ .{ .length = 1 }, .{ .fill = 1 }, .{ .length = 1 } }, .{});

    var hdr = layout[0];
    hdr.header(.{ .title = "Text Input & Editor", .right = "Tab / Click Switch  Esc Quit" }, hdr.area);

    const body_margin = if (layout[1].isCompact(52) or layout[1].area.height < 10) tui.Margin.zero else tui.Margin.uniform(1);
    var body = layout[1].margin(body_margin);
    var msg_buf: [128]u8 = undefined;
    const val_res = state.email.validateWithSchema(EmailSchema, &msg_buf);
    const val_status: tui.ValidationStatus = if (state.email.text().len == 0)
        .none
    else if (val_res.valid)
        .valid
    else
        .invalid;

    state.email_rect = body.allocateRows(3);
    try body.textInput(.{
        .label = "Email (live validation)",
        .placeholder = "you@example.com",
        .focused = state.focus.isFocused(0),
        .validation = val_status,
        .error_message = val_res.message,
    }, &state.email, state.email_rect);
    body.space(1);

    state.notes_rect = body.available();
    try body.textArea(.{
        .block = .{ .title = "Multi-line Notes", .border_type = .rounded },
        .placeholder = "Write notes here...",
        .focused = state.focus.isFocused(1),
        .line_numbers = true,
    }, &state.notes, state.notes_rect);

    var ft = layout[2];
    ft.statusBar(.{
        .left = &.{
            .{ .text = if (val_status == .valid) "VALID" else "EDIT", .badge = true },
            .{ .text = if (state.focus.isFocused(0)) "Focus: Email" else "Focus: Notes" },
        },
        .right = &.{.{ .text = "Tab Focus  Ctrl+Arrows Word  Shift+Sel  Esc Quit" }},
    }, ft.area);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const headless = tui.hasArg(init.minimal.args, alloc, "--headless");

    var app = try tui.init(alloc, .{
        .app = .{ .name = "Text Input & Editor", .version = tui.version },
        .io = init.io,
        .backend = if (headless) .{ .memory = .{ .width = 80, .height = 24 } } else .auto,
        .cursor_shape = .blinking_bar,
        .settings = .{ .mouse = true },
    });
    defer app.deinit();

    var state = State{
        .email = try app.textInputWith("dev@tui.zig"),
        .notes = try app.textAreaWith("Line 1: Native Zig\nLine 2: Zero C deps"),
    };
    defer state.deinit();

    if (headless) {
        try app.enter();
        try app.draw(&state, render);
        const snap = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap, "dev@tui.zig") != null);
        std.debug.assert(std.mem.indexOf(u8, snap, "Native Zig") != null);
        // Hardware cursor should be requested inside email box when focused.
        std.debug.assert(app.cursorPos() != null);

        // Verify responsive compact size still renders both input and textarea cleanly
        try app.resizeTest(.{ .width = 44, .height = 10 });
        try app.draw(&state, render);
        const snap_compact = try app.snapshot();
        std.debug.assert(std.mem.indexOf(u8, snap_compact, "dev@tui.zig") != null);
        return;
    }

    try app.enter();
    try app.run(&state, .{ .onEvent = onEvent, .render = render });
}
