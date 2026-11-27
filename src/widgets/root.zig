//! Built-in reusable TUI widgets and widget state machines.

pub const clear = @import("clear.zig");
pub const block = @import("block.zig");
pub const paragraph = @import("paragraph.zig");
pub const gauge = @import("gauge.zig");
pub const scrollbar = @import("scrollbar.zig");
pub const button = @import("button.zig");
pub const checkbox = @import("checkbox.zig");
pub const radio = @import("radio.zig");
pub const text_input = @import("text_input.zig");
pub const text_area = @import("text_area.zig");
pub const list = @import("list.zig");
pub const table = @import("table.zig");
pub const tabs = @import("tabs.zig");
pub const select = @import("select.zig");
pub const tree = @import("tree.zig");
pub const sparkline = @import("sparkline.zig");
pub const barchart = @import("barchart.zig");
pub const canvas = @import("canvas.zig");
pub const chart = @import("chart.zig");
pub const popup = @import("popup.zig");
pub const chrome = @import("chrome.zig");
pub const calendar = @import("calendar.zig");
pub const controls = @import("controls.zig");
pub const effects = @import("effects.zig");
pub const pie_chart = @import("pie_chart.zig");
pub const heatmap = @import("heatmap.zig");
pub const log_viewer = @import("log_viewer.zig");
pub const diff_viewer = @import("diff_viewer.zig");
pub const stepper = @import("stepper.zig");
pub const pagination = @import("pagination.zig");
pub const key_value = @import("key_value.zig");
pub const terminal_view = @import("terminal_view.zig");
pub const misc = @import("misc.zig");

pub const Clear = clear.Clear;
pub const Fill = clear.Fill;
pub const Spacer = clear.Spacer;
pub const Divider = clear.Divider;

pub const TitlePosition = block.TitlePosition;
pub const Title = block.Title;
pub const Shadow = block.Shadow;
pub const Block = block.Block;

pub const ScrollOffset = paragraph.ScrollOffset;
pub const Paragraph = paragraph.Paragraph;

pub const Gauge = gauge.Gauge;
pub const LineGauge = gauge.LineGauge;
pub const ProgressBar = gauge.ProgressBar;
pub const Spinner = gauge.Spinner;

pub const ScrollbarOrientation = scrollbar.ScrollbarOrientation;
pub const ScrollbarState = scrollbar.ScrollbarState;
pub const Scrollbar = scrollbar.Scrollbar;

pub const ButtonVariant = button.ButtonVariant;
pub const Button = button.Button;

pub const CheckState = checkbox.CheckState;
pub const Checkbox = checkbox.Checkbox;

pub const RadioState = radio.RadioState;
pub const RadioGroup = radio.RadioGroup;

pub const ValidationStatus = text_input.ValidationStatus;
pub const ValidationResult = text_input.ValidationResult;
pub const InputAction = text_input.InputAction;
pub const TextInputState = text_input.TextInputState;
pub const TextInput = text_input.TextInput;

pub const CursorLineCol = text_area.CursorLineCol;
pub const TextAreaState = text_area.TextAreaState;
pub const TextArea = text_area.TextArea;

pub const HighlightSpacing = list.HighlightSpacing;
pub const ListDirection = list.ListDirection;
pub const ListItem = list.ListItem;
pub const ListState = list.ListState;
pub const List = list.List;

pub const TableCell = table.TableCell;
pub const TableRow = table.TableRow;
pub const TableState = table.TableState;
pub const Table = table.Table;

pub const Tabs = tabs.Tabs;

pub const SelectState = select.SelectState;
pub const Select = select.Select;

pub const TreeNode = tree.TreeNode;
pub const TreeState = tree.TreeState;
pub const Tree = tree.Tree;

pub const RenderDirection = sparkline.RenderDirection;
pub const Sparkline = sparkline.Sparkline;

pub const Bar = barchart.Bar;
pub const BarGroup = barchart.BarGroup;
pub const BarChart = barchart.BarChart;

pub const Bounds = canvas.Bounds;
pub const Point = canvas.Point;
pub const PixelGrid = canvas.PixelGrid;
pub const Painter = canvas.Painter;
pub const Shape = canvas.Shape;
pub const Canvas = canvas.Canvas;

pub const GraphType = chart.GraphType;
pub const Dataset = chart.Dataset;
pub const Axis = chart.Axis;
pub const LegendPosition = chart.LegendPosition;
pub const Chart = chart.Chart;

pub const OverlayAnchor = popup.OverlayAnchor;
pub const Popup = popup.Popup;
pub const ConfirmOutcome = popup.ConfirmOutcome;
pub const ConfirmState = popup.ConfirmState;
pub const ConfirmDialog = popup.ConfirmDialog;
pub const ToastLevel = popup.ToastLevel;
pub const Toast = popup.Toast;

pub const MenuItem = chrome.MenuItem;
pub const MenuGroup = chrome.MenuGroup;
pub const MenuOutcome = chrome.MenuOutcome;
pub const MenuState = chrome.MenuState;
pub const DropdownMenu = chrome.DropdownMenu;
pub const MenuBar = chrome.MenuBar;
pub const ContextMenuOutcome = chrome.ContextMenuOutcome;
pub const ContextMenu = chrome.ContextMenu;
pub const Breadcrumbs = chrome.Breadcrumbs;
pub const StatusSegment = chrome.StatusSegment;
pub const StatusBar = chrome.StatusBar;
pub const Header = chrome.Header;
pub const ScrollViewState = chrome.ScrollViewState;
pub const ScrollView = chrome.ScrollView;
pub const SplitPane = chrome.SplitPane;
pub const FocusGroup = chrome.FocusGroup;
pub const Navbar = chrome.Navbar;
pub const SidebarSide = chrome.SidebarSide;
pub const SidebarItem = chrome.SidebarItem;
pub const Sidebar = chrome.Sidebar;

pub const Weekday = calendar.Weekday;
pub const Month = calendar.Month;
pub const Date = calendar.Date;
pub const CalendarEvent = calendar.CalendarEvent;
pub const CalendarState = calendar.CalendarState;
pub const Calendar = calendar.Calendar;

pub const BadgeVariant = controls.BadgeVariant;
pub const Badge = controls.Badge;
pub const Switch = controls.Switch;
pub const SliderState = controls.SliderState;
pub const Slider = controls.Slider;
pub const Accordion = controls.Accordion;

pub const BigText = misc.BigText;
pub const Markdown = misc.Markdown;
pub const CommandEntry = misc.CommandEntry;
pub const CommandPaletteResult = misc.CommandPaletteResult;
pub const CommandPaletteState = misc.CommandPaletteState;
pub const CommandPalette = misc.CommandPalette;
pub const Tooltip = misc.Tooltip;

pub const Easing = effects.Easing;
pub const LoopMode = effects.LoopMode;
pub const Tween = effects.Tween;
pub const Spring = effects.Spring;
pub const RevealOrigin = effects.RevealOrigin;
pub const Transition = effects.Transition;
pub const ToastState = effects.ToastState;
pub const ToastManager = effects.ToastManager;
pub const Skeleton = effects.Skeleton;

pub const DropdownState = select.SelectState;
pub const Dropdown = select.Select;
pub const PieStyle = pie_chart.PieStyle;
pub const PieLegendPosition = pie_chart.PieLegendPosition;
pub const PieLegendLayout = pie_chart.PieLegendLayout;
pub const PieSlice = pie_chart.PieSlice;
pub const PieChart = pie_chart.PieChart;
pub const Heatmap = heatmap.Heatmap;
pub const LogLevel = log_viewer.LogLevel;
pub const LogEntry = log_viewer.LogEntry;
pub const SourceFilter = log_viewer.SourceFilter;
pub const LogViewerState = log_viewer.LogViewerState;
pub const LogViewer = log_viewer.LogViewer;
pub const DiffKind = diff_viewer.DiffKind;
pub const DiffLine = diff_viewer.DiffLine;
pub const DiffViewerState = diff_viewer.DiffViewerState;
pub const DiffViewer = diff_viewer.DiffViewer;
pub const StepStatus = stepper.StepStatus;
pub const StepItem = stepper.StepItem;
pub const Stepper = stepper.Stepper;
pub const Pagination = pagination.Pagination;
pub const KeyValueEntry = key_value.KeyValueEntry;
pub const KeyValueList = key_value.KeyValueList;
pub const VtCell = terminal_view.VtCell;
pub const VtScreen = terminal_view.VtScreen;
pub const TerminalView = terminal_view.TerminalView;

test {
    _ = clear;
    _ = block;
    _ = paragraph;
    _ = gauge;
    _ = scrollbar;
    _ = button;
    _ = checkbox;
    _ = radio;
    _ = text_input;
    _ = text_area;
    _ = list;
    _ = table;
    _ = tabs;
    _ = select;
    _ = tree;
    _ = sparkline;
    _ = barchart;
    _ = canvas;
    _ = chart;
    _ = popup;
    _ = chrome;
    _ = calendar;
    _ = controls;
    _ = effects;
    _ = pie_chart;
    _ = heatmap;
    _ = log_viewer;
    _ = diff_viewer;
    _ = stepper;
    _ = pagination;
    _ = key_value;
    _ = terminal_view;
    _ = misc;
}
