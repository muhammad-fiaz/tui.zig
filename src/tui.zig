//! tui.zig: A native, production-grade terminal user interface library for Zig.

const std = @import("std");
const testing = std.testing;

pub const version = "0.1.0";
pub const minimum_zig_version = "0.17.0";

pub const style = @import("style/root.zig");
pub const core = @import("core/root.zig");
pub const text = @import("text/root.zig");
pub const event = @import("event/root.zig");
pub const backend = @import("backend/root.zig");
pub const terminal = @import("terminal/root.zig");
pub const widgets = @import("widgets/root.zig");
pub const schema = @import("zigantic");

pub const Color = style.Color;
pub const Style = style.Style;
pub const Modifiers = style.Modifiers;
pub const UnderlineStyle = style.UnderlineStyle;
pub const BorderSides = style.BorderSides;
pub const BorderSet = style.BorderSet;
pub const BorderType = style.BorderType;
pub const MergeStrategy = style.MergeStrategy;
pub const Theme = style.Theme;
pub const Capability = style.Capability;
pub const IconSet = style.IconSet;
pub const Marker = style.Marker;
pub const palette = style.palette;
pub const symbols = style.symbols;

pub const Position = core.Position;
pub const Size = core.Size;
pub const Offset = core.Offset;
pub const Rect = core.Rect;
pub const Margin = core.Margin;
pub const Padding = core.Padding;
pub const Alignment = core.Alignment;
pub const VerticalAlignment = core.VerticalAlignment;
pub const Direction = core.Direction;
pub const Flex = core.Flex;
pub const Spacing = core.Spacing;
pub const Constraint = core.Constraint;
pub const Layout = core.Layout;
pub const LayoutOptions = core.LayoutOptions;
pub const Cell = core.Cell;
pub const CellDiffOption = core.CellDiffOption;
pub const Buffer = core.Buffer;
pub const BufferDiff = core.BufferDiff;
pub const Viewport = core.Viewport;
pub const AppInfo = core.AppInfo;
pub const CursorShape = core.CursorShape;
pub const BackendMode = core.BackendMode;
pub const EnterOptionsSchema = core.EnterOptionsSchema;
pub const EnterOptions = core.EnterOptions;
pub const AppSettingsSchema = core.AppSettingsSchema;
pub const AppSettings = core.AppSettings;
pub const AppOptions = core.AppOptions;
pub const ThemeSpecSchema = core.ThemeSpecSchema;
pub const ThemeSpec = core.ThemeSpec;
pub const Ui = core.Ui;
pub const Frame = core.Frame;

pub const Backend = backend.Backend;
pub const TerminalCapabilities = backend.TerminalCapabilities;
pub const ClearType = backend.ClearType;
pub const App = terminal.App;

/// Primary centralized initialization entry point for `tui.zig`.
///
/// Requires an explicit `allocator` and accepts `.{}` defaults or overrides via `AppOptions`.
/// Call `defer app.deinit();` to ensure terminal restoration and resource cleanup.
pub fn init(allocator: std.mem.Allocator, options: AppOptions) !App {
    return App.init(allocator, options);
}

/// Returns `true` when `flag` is present in `args` (cross-platform across Windows, POSIX, and WASI).
pub fn hasArg(args: std.process.Args, allocator: std.mem.Allocator, flag: []const u8) bool {
    var it = args.iterateAllocator(allocator) catch return false;
    defer it.deinit();
    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, flag)) return true;
    }
    return false;
}

pub const Span = text.Span;
pub const Line = text.Line;
pub const Text = text.Text;
pub const Masked = text.Masked;
pub const WrapMode = text.WrapMode;
pub const Truncation = text.Truncation;
pub const TextDirection = text.TextDirection;
pub const LocaleEntry = text.LocaleEntry;
pub const Locale = text.Locale;
pub const BitmapGlyph = text.BitmapGlyph;
pub const FontRenderMode = text.FontRenderMode;
pub const BitmapFont = text.BitmapFont;

pub const Event = event.Event;
pub const KeyEvent = event.KeyEvent;
pub const KeyCode = event.KeyCode;
pub const KeyModifiers = event.KeyModifiers;
pub const KeyEventKind = event.KeyEventKind;
pub const MouseEvent = event.MouseEvent;
pub const MouseButton = event.MouseButton;
pub const MouseEventKind = event.MouseEventKind;
pub const EventParser = event.EventParser;

pub const Clear = widgets.Clear;
pub const Fill = widgets.Fill;
pub const Spacer = widgets.Spacer;
pub const Divider = widgets.Divider;
pub const TitlePosition = widgets.TitlePosition;
pub const Title = widgets.Title;
pub const Shadow = widgets.Shadow;
pub const Block = widgets.Block;
pub const ScrollOffset = widgets.ScrollOffset;
pub const Paragraph = widgets.Paragraph;
pub const Gauge = widgets.Gauge;
pub const LineGauge = widgets.LineGauge;
pub const ProgressBar = widgets.ProgressBar;
pub const Spinner = widgets.Spinner;
pub const ScrollbarOrientation = widgets.ScrollbarOrientation;
pub const ScrollbarState = widgets.ScrollbarState;
pub const Scrollbar = widgets.Scrollbar;
pub const ButtonVariant = widgets.ButtonVariant;
pub const Button = widgets.Button;
pub const CheckState = widgets.CheckState;
pub const Checkbox = widgets.Checkbox;
pub const RadioState = widgets.RadioState;
pub const RadioGroup = widgets.RadioGroup;
pub const ValidationStatus = widgets.ValidationStatus;
pub const ValidationResult = widgets.ValidationResult;
pub const InputAction = widgets.InputAction;
pub const TextInputState = widgets.TextInputState;
pub const TextInput = widgets.TextInput;
pub const CursorLineCol = widgets.CursorLineCol;
pub const TextAreaState = widgets.TextAreaState;
pub const TextArea = widgets.TextArea;
pub const HighlightSpacing = widgets.HighlightSpacing;
pub const ListDirection = widgets.ListDirection;
pub const ListItem = widgets.ListItem;
pub const ListState = widgets.ListState;
pub const List = widgets.List;
pub const TableCell = widgets.TableCell;
pub const TableRow = widgets.TableRow;
pub const TableState = widgets.TableState;
pub const Table = widgets.Table;
pub const Tabs = widgets.Tabs;
pub const SelectState = widgets.SelectState;
pub const Select = widgets.Select;
pub const TreeNode = widgets.TreeNode;
pub const TreeState = widgets.TreeState;
pub const Tree = widgets.Tree;
pub const RenderDirection = widgets.RenderDirection;
pub const Sparkline = widgets.Sparkline;
pub const Bar = widgets.Bar;
pub const BarGroup = widgets.BarGroup;
pub const BarChart = widgets.BarChart;
pub const Bounds = widgets.Bounds;
pub const Point = widgets.Point;
pub const PixelGrid = widgets.PixelGrid;
pub const Painter = widgets.Painter;
pub const Shape = widgets.Shape;
pub const Canvas = widgets.Canvas;
pub const GraphType = widgets.GraphType;
pub const Dataset = widgets.Dataset;
pub const Axis = widgets.Axis;
pub const LegendPosition = widgets.LegendPosition;
pub const Chart = widgets.Chart;
pub const OverlayAnchor = widgets.OverlayAnchor;
pub const Popup = widgets.Popup;
pub const ConfirmOutcome = widgets.ConfirmOutcome;
pub const ConfirmState = widgets.ConfirmState;
pub const ConfirmDialog = widgets.ConfirmDialog;
pub const ToastLevel = widgets.ToastLevel;
pub const Toast = widgets.Toast;
pub const MenuItem = widgets.MenuItem;
pub const MenuGroup = widgets.MenuGroup;
pub const MenuOutcome = widgets.MenuOutcome;
pub const MenuState = widgets.MenuState;
pub const DropdownMenu = widgets.DropdownMenu;
pub const MenuBar = widgets.MenuBar;
pub const ContextMenuOutcome = widgets.ContextMenuOutcome;
pub const ContextMenu = widgets.ContextMenu;
pub const Breadcrumbs = widgets.Breadcrumbs;
pub const StatusSegment = widgets.StatusSegment;
pub const StatusBar = widgets.StatusBar;
pub const Header = widgets.Header;
pub const ScrollViewState = widgets.ScrollViewState;
pub const ScrollView = widgets.ScrollView;
pub const SplitPane = widgets.SplitPane;
pub const FocusGroup = widgets.FocusGroup;
pub const Navbar = widgets.Navbar;
pub const SidebarSide = widgets.SidebarSide;
pub const SidebarItem = widgets.SidebarItem;
pub const Sidebar = widgets.Sidebar;
pub const Weekday = widgets.Weekday;
pub const Month = widgets.Month;
pub const Date = widgets.Date;
pub const CalendarEvent = widgets.CalendarEvent;
pub const CalendarState = widgets.CalendarState;
pub const Calendar = widgets.Calendar;
pub const BadgeVariant = widgets.BadgeVariant;
pub const Badge = widgets.Badge;
pub const Switch = widgets.Switch;
pub const SliderState = widgets.SliderState;
pub const Slider = widgets.Slider;
pub const Accordion = widgets.Accordion;
pub const effects = widgets.effects;
pub const fx = widgets.effects;
pub const Easing = widgets.Easing;
pub const LoopMode = widgets.LoopMode;
pub const Tween = widgets.Tween;
pub const Spring = widgets.Spring;
pub const RevealOrigin = widgets.RevealOrigin;
pub const Transition = widgets.Transition;
pub const ToastState = widgets.ToastState;
pub const ToastManager = widgets.ToastManager;
pub const Skeleton = widgets.Skeleton;
pub const DropdownState = widgets.DropdownState;
pub const Dropdown = widgets.Dropdown;
pub const PieStyle = widgets.PieStyle;
pub const PieLegendPosition = widgets.PieLegendPosition;
pub const PieLegendLayout = widgets.PieLegendLayout;
pub const PieSlice = widgets.PieSlice;
pub const PieChart = widgets.PieChart;
pub const Heatmap = widgets.Heatmap;
pub const LogLevel = widgets.LogLevel;
pub const LogEntry = widgets.LogEntry;
pub const SourceFilter = widgets.SourceFilter;
pub const LogViewerState = widgets.LogViewerState;
pub const LogViewer = widgets.LogViewer;
pub const DiffKind = widgets.DiffKind;
pub const DiffLine = widgets.DiffLine;
pub const DiffViewerState = widgets.DiffViewerState;
pub const DiffViewer = widgets.DiffViewer;
pub const StepStatus = widgets.StepStatus;
pub const StepItem = widgets.StepItem;
pub const Stepper = widgets.Stepper;
pub const Pagination = widgets.Pagination;
pub const KeyValueEntry = widgets.KeyValueEntry;
pub const KeyValueList = widgets.KeyValueList;
pub const VtCell = widgets.VtCell;
pub const VtScreen = widgets.VtScreen;
pub const TerminalView = widgets.TerminalView;
pub const BigText = widgets.BigText;
pub const Markdown = widgets.Markdown;
pub const CommandEntry = widgets.CommandEntry;
pub const CommandPaletteResult = widgets.CommandPaletteResult;
pub const CommandPaletteState = widgets.CommandPaletteState;
pub const CommandPalette = widgets.CommandPalette;
pub const Tooltip = widgets.Tooltip;

test {
    testing.refAllDecls(@This());
    testing.refAllDecls(style);
    testing.refAllDecls(core);
    testing.refAllDecls(text);
    testing.refAllDecls(event);
    testing.refAllDecls(backend);
    testing.refAllDecls(terminal);
    testing.refAllDecls(widgets);
}
