# Table Widget

Displays data in rows and columns.

## Import

```zig
const tui = @import("tui");
// Define your row type
const Row = struct { id: []const u8, name: []const u8 };
// Instantiate the generic type
const Table = tui.Table(Row);
```

## Usage

```zig
// Data
const rows = &[_]Row{
    .{ .id = "1", .name = "Alice" },
    .{ .id = "2", .name = "Bob" },
};

const cols = &[_]tui.table.Column{
    .{ .header = "ID", .width = .{ .fixed = 5 } },
    .{ .header = "Name", .width = .{ .fixed = 20 } },
};

// Renderer function
fn renderCell(row: Row, col: usize, buf: []u8) []const u8 {
    return switch (col) {
        0 => row.id,
        1 => row.name,
        else => "",
    };
}

// Initialize
var table = Table.init(cols, rows, renderCell);
```

## Features

- Column headers
- Row selection
- External data source (slices)
