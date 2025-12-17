const std = @import("std");
const tui = @import("tui");

const Row = struct { id: u32, name: []const u8, value: u32 };

fn render_cell(row: Row, col: usize, buf: []u8) []const u8 {
    const written = switch (col) {
        0 => std.fmt.bufPrint(buf, "{d}", .{row.id}) catch 0,
        1 => std.fmt.bufPrint(buf, "{s}", .{row.name}) catch 0,
        2 => std.fmt.bufPrint(buf, "{d}", .{row.value}) catch 0,
        else => 0,
    };
    return buf[0..written];
}

pub const TableApp = struct {
    tbl: tui.Table(Row) = undefined,

    pub fn init() TableApp {
        const cols = &.{
            tui.Column{ .header = "ID" },
            tui.Column{ .header = "Name" },
            tui.Column{ .header = "Value" },
        };

        const rows = &.{
            Row{ .id = 1, .name = "Alice", .value = 10 },
            Row{ .id = 2, .name = "Bob", .value = 20 },
            Row{ .id = 3, .name = "Carol", .value = 30 },
        };

        return TableApp{ .tbl = tui.Table(Row).init(cols, rows, &render_cell) };
    }

    pub fn render(self: *TableApp, ctx: *tui.RenderContext) void {
        // Ensure bounds are set for the table
        self.tbl.base.bounds = ctx.bounds;
        self.tbl.render(ctx);
    }

    pub fn handleEvent(self: *TableApp, event: tui.Event) tui.EventResult {
        if (event == .key) {
            const k = event.key;
            if (k.key == .up) {
                if (self.tbl.selected_row > 0) self.tbl.selectRow(self.tbl.selected_row - 1);
                return .needs_redraw;
            } else if (k.key == .down) {
                if (self.tbl.selected_row + 1 < self.tbl.rows.len) self.tbl.selectRow(self.tbl.selected_row + 1);
                return .needs_redraw;
            }
        }
        return .ignored;
    }
};

pub fn main() !void {
    var app = try tui.App.init(.{});
    defer app.deinit();

    var root = TableApp.init();
    try app.setRoot(&root);
    try app.run();
}
