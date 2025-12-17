//! # TUI.zig
//!
//! A high-performance, Unicode-correct, cross-platform Terminal UI framework
//! written purely in Zig.
//!
//! ## Features
//!
//! - **Zero runtime dependencies** - Pure Zig implementation
//! - **Unicode-correct rendering** - Full grapheme cluster support
//! - **Composable widget system** - Build complex UIs from simple parts
//! - **Retained-mode UI** - Efficient diff-based rendering
//! - **Event-driven architecture** - Non-blocking input handling
//! - **Cross-platform** - Linux, macOS, Windows (ConPTY)
//!
//! ## Quick Start
//!
//! ```zig
//! const tui = @import("tui");
//!
//! pub fn main() !void {
//!     var app = try tui.App.init(.{});
//!     defer app.deinit();
//!
//!     try app.setRoot(
//!         tui.FlexColumn(.{
//!             tui.Text("Hello TUI.zig"),
//!             tui.Button("Click Me", onClick),
//!         })
//!     );
//!
//!     try app.run();
//! }
//! ```

const std = @import("std");

// ============================================
// Core Modules
// ============================================

/// Terminal handling and raw mode
pub const terminal = @import("core/terminal.zig");

/// Screen buffer and cell management
pub const screen = @import("core/screen.zig");

/// Cell representation with styling
pub const cell = @import("core/cell.zig");

/// Diff-based renderer
pub const renderer = @import("core/renderer.zig");

// ============================================
// Event System
// ============================================

/// Event types and handling
pub const events = @import("event/events.zig");

/// Input handling (keyboard, mouse)
pub const input = @import("event/input.zig");

// ============================================
// Layout Engine
// ============================================

/// Layout system and constraints
pub const layout = @import("layout/layout.zig");

/// Box model and sizing
pub const box = @import("layout/box.zig");

/// Flex layout (row/column)
pub const flex = @import("layout/flex.zig");

// ============================================
// Widget System
// ============================================

/// Base widget trait and utilities
pub const widget = @import("widgets/widget.zig");

/// Text widget
pub const text = @import("widgets/text.zig");

/// Button widget
pub const button = @import("widgets/button.zig");

/// Input field widget
pub const input_field = @import("widgets/input_field.zig");

/// Checkbox widget
pub const checkbox = @import("widgets/checkbox.zig");

/// Progress bar widget
pub const progress = @import("widgets/progress.zig");

/// Spinner widget
pub const spinner = @import("widgets/spinner.zig");

/// List view widget
pub const list_view = @import("widgets/list_view.zig");

/// Table widget
pub const table = @import("widgets/table.zig");

/// Scroll view widget
pub const scroll_view = @import("widgets/scroll_view.zig");

/// Modal/overlay widget
pub const modal = @import("widgets/modal.zig");

/// Tabs widget
pub const tabs = @import("widgets/tabs.zig");

/// Split view widget
pub const split_view = @import("widgets/split_view.zig");

/// Text area widget
pub const text_area = @import("widgets/text_area.zig");

/// Radio button widget
pub const radio = @import("widgets/radio.zig");

/// Menu widget
pub const menu = @import("widgets/menu.zig");

/// Tree view widget
pub const tree = @import("widgets/tree.zig");

/// Border styles
pub const border = @import("widgets/border.zig");

/// Accordion widget
pub const accordion = @import("widgets/accordion.zig");

/// Alert widgets
pub const alert = @import("widgets/alert.zig");

/// Badge widget
pub const badge = @import("widgets/badge.zig");

/// Card widget
pub const card = @import("widgets/card.zig");

/// Slider widget
pub const slider = @import("widgets/slider.zig");

/// Switch widget
pub const switch_widget = @import("widgets/switch.zig");

/// Tooltip widget
pub const tooltip = @import("widgets/tooltip.zig");

/// Toast notification
pub const toast = @import("widgets/toast.zig");

/// Skeleton loader
pub const skeleton = @import("widgets/skeleton.zig");

/// Separator widget
pub const separator = @import("widgets/separator.zig");

/// Breadcrumb navigation
pub const breadcrumb = @import("widgets/breadcrumb.zig");

/// Pagination widget
pub const pagination = @import("widgets/pagination.zig");

/// Navbar widget
pub const navbar = @import("widgets/navbar.zig");

/// Sidebar widget
pub const sidebar = @import("widgets/sidebar.zig");

/// Statusbar widget
pub const statusbar = @import("widgets/statusbar.zig");

/// Grid layout
pub const grid = @import("widgets/grid.zig");

/// Image display
pub const image = @import("widgets/image.zig");

// ============================================
// Styling
// ============================================

/// Colors and color utilities
pub const color = @import("style/color.zig");

/// Style definitions
pub const style = @import("style/style.zig");

/// Theme system
pub const theme = @import("style/theme.zig");

// ============================================
// Unicode Support
// ============================================

/// Unicode utilities and grapheme handling
pub const unicode = @import("unicode/unicode.zig");

/// Display width calculation
pub const width = @import("unicode/width.zig");

// ============================================
// Platform Abstraction
// ============================================

/// Platform-specific implementations
pub const platform = @import("platform/platform.zig");

// ============================================
// Animation System
// ============================================

/// Animation and tweening
pub const animation = @import("animation/animation.zig");

// ============================================
// Application Core
// ============================================

/// Main application struct
pub const App = @import("app.zig").App;

/// Application configuration
pub const AppConfig = @import("app.zig").AppConfig;

// ============================================
// Convenience Re-exports
// ============================================

/// Create a text widget
pub const Text = text.Text;

/// Create a button widget
pub const Button = button.Button;

/// Create an input field
pub const InputField = input_field.InputField;

/// Create a checkbox
pub const Checkbox = checkbox.Checkbox;

/// Create a progress bar
pub const ProgressBar = progress.ProgressBar;

/// Create a spinner
pub const Spinner = spinner.Spinner;

/// Create a list view
pub const ListView = list_view.ListView;

/// Create a table
pub const Table = table.Table;

/// Create a scroll view
pub const ScrollView = scroll_view.ScrollView;

/// Create a modal overlay
pub const Modal = modal.Modal;

/// Create tabs
pub const Tabs = tabs.Tabs;

/// Create a split view
pub const SplitView = split_view.SplitView;

/// Create a text area
pub const TextArea = text_area.TextArea;

/// Create a radio group
pub const RadioGroup = radio.RadioGroup;

/// Create a menu
pub const Menu = menu.Menu;

/// Create a tree view
pub const TreeView = tree.TreeView;

/// Border style type
pub const BorderStyle = border.BorderStyle;

/// Border chars
pub const BorderChars = border.BorderChars;

/// Border configuration
pub const Border = border.Border;

/// Create an accordion
pub const Accordion = accordion.Accordion;

/// Create an alert
pub const Alert = alert.Alert;

/// Create an alert dialog
pub const AlertDialog = alert.AlertDialog;

/// Create a badge
pub const Badge = badge.Badge;

/// Create a card
pub const Card = card.Card;

/// Create a slider
pub const Slider = slider.Slider;

/// Create a switch
pub const Switch = switch_widget.Switch;

/// Create a tooltip
pub const Tooltip = tooltip.Tooltip;

/// Create a toast
pub const Toast = toast.Toast;

/// Toast manager
pub const ToastManager = toast.ToastManager;

/// Create a skeleton loader
pub const Skeleton = skeleton.Skeleton;

/// Create a separator
pub const Separator = separator.Separator;

/// Create breadcrumb navigation
pub const Breadcrumb = breadcrumb.Breadcrumb;

/// Create pagination
pub const Pagination = pagination.Pagination;

/// Create navbar
pub const Navbar = navbar.Navbar;

/// Create sidebar
pub const Sidebar = sidebar.Sidebar;

/// Create statusbar
pub const Statusbar = statusbar.Statusbar;

/// Create grid layout
pub const Grid = grid.Grid;

/// Create image display
pub const Image = image.Image;

/// Flex column layout
pub const FlexColumn = flex.FlexColumn;

/// Flex row layout
pub const FlexRow = flex.FlexRow;

/// Padding layout
pub const Padding = layout.Padding;

/// Center layout
pub const Center = layout.Center;

/// Sized box layout
pub const SizedBox = layout.SizedBox;

/// Margin layout
pub const Margin = layout.Margin;

/// Rect type
pub const Rect = layout.Rect;

/// Color type
pub const Color = color.Color;

/// Style type
pub const Style = style.Style;

/// Theme type
pub const Theme = theme.Theme;

/// Event type
pub const Event = events.Event;

/// Key type
pub const Key = input.Key;

/// Mouse event type
pub const Mouse = events.MouseEvent;

/// Render context for widgets
pub const RenderContext = widget.RenderContext;

/// Result of event handling
pub const EventResult = widget.EventResult;

// ============================================
// Version Information
// ============================================

pub const version = std.SemanticVersion{
    .major = 0,
    .minor = 1,
    .patch = 0,
};

pub const version_string = "0.1.0";

// ============================================
// Tests
// ============================================

test {
    // Run all module tests
    std.testing.refAllDecls(@This());
}
