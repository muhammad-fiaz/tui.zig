//! Core rendering primitives: geometry, constraints, layout, cells, buffers, and config.

const testing = @import("std").testing;

pub const geometry = @import("geometry.zig");
pub const constraint = @import("constraint.zig");
pub const layout = @import("layout.zig");
pub const cell = @import("cell.zig");
pub const buffer = @import("buffer.zig");
pub const config = @import("config.zig");
pub const frame = @import("frame.zig");

pub const Position = geometry.Position;
pub const Size = geometry.Size;
pub const Offset = geometry.Offset;
pub const Rect = geometry.Rect;
pub const Margin = geometry.Margin;
pub const Padding = geometry.Padding;
pub const Alignment = geometry.Alignment;
pub const VerticalAlignment = geometry.VerticalAlignment;

pub const Direction = constraint.Direction;
pub const Flex = constraint.Flex;
pub const Spacing = constraint.Spacing;
pub const Constraint = constraint.Constraint;

pub const Layout = layout.Layout;
pub const LayoutOptions = layout.LayoutOptions;

pub const Cell = cell.Cell;
pub const CellDiffOption = cell.CellDiffOption;
pub const Buffer = buffer.Buffer;
pub const BufferDiff = buffer.BufferDiff;
pub const DiffEntry = buffer.DiffEntry;

pub const Viewport = config.Viewport;
pub const AppInfo = config.AppInfo;
pub const CursorShape = config.CursorShape;
pub const BackendMode = config.BackendMode;
pub const EnterOptionsSchema = config.EnterOptionsSchema;
pub const EnterOptions = config.EnterOptions;
pub const AppSettingsSchema = config.AppSettingsSchema;
pub const AppSettings = config.AppSettings;
pub const AppOptions = config.AppOptions;
pub const ThemeSpecSchema = config.ThemeSpecSchema;
pub const ThemeSpec = config.ThemeSpec;
pub const Ui = frame.Ui;
pub const Frame = frame.Frame;

test {
    testing.refAllDecls(@This());
    testing.refAllDecls(geometry);
    testing.refAllDecls(constraint);
    testing.refAllDecls(layout);
    testing.refAllDecls(cell);
    testing.refAllDecls(buffer);
    testing.refAllDecls(config);
    testing.refAllDecls(frame);
}
