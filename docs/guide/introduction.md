# Introduction

## What is TUI.zig?

**TUI.zig** is a modern, feature-rich Terminal User Interface (TUI) library for the Zig programming language. It provides everything you need to build beautiful, interactive terminal applications with a simple, intuitive API.

## Philosophy

TUI.zig is designed with these principles:

1. **Simple API** - As easy to use as Python, but with Zig's performance
2. **Zero Dependencies** - Pure Zig, no external C libraries
3. **Cross-Platform** - Works on Linux, Windows, macOS, and BSD
4. **High Performance** - Diff-based rendering, double buffering
5. **Feature Complete** - All the widgets and features you need built-in

## Features at a Glance

### 🎨 Rendering

- **True Color (24-bit RGB)** - Full color spectrum
- **256 Color Mode** - For older terminals
- **16 ANSI Colors** - Universal fallback
- **Double Buffering** - No flicker
- **Diff-Based Updates** - Only render what changed
- **Unicode Support** - Emoji, CJK, grapheme clusters

### 🧩 Widgets

TUI.zig includes 36+ built-in widgets:

| Widget       | Description                 |
| ------------ | --------------------------- |
| Text         | Styled text with alignment  |
| Button       | Clickable with hover states |
| Input Field  | Single-line text input      |
| Text Area    | Multi-line editor           |
| Checkbox     | Toggle checkboxes           |
| Radio Button | Single selection            |
| Progress Bar | Visual progress             |
| Spinner      | Loading animation           |
| List View    | Scrollable lists            |
| Table        | Data tables                 |
| Tabs         | Tabbed navigation           |
| Modal        | Dialog overlays             |
| Scroll View  | Scrollable containers       |
| Split View   | Resizable panes             |
| Badge        | Status indicators           |
| Card         | Content containers          |
| Accordion    | Collapsible sections        |
| Breadcrumb   | Navigation paths            |
| Grid         | Grid layouts                |
| Image        | Image display               |
| Menu         | Dropdown menus              |
| Navbar       | Top navigation bars         |
| Pagination   | Page navigation             |
| Sidebar      | Side navigation panels      |
| Skeleton     | Loading placeholders        |
| Slider       | Range input                 |
| Statusbar    | Status information          |
| Switch       | Toggle switches             |
| Toast        | Notifications               |
| Tooltip      | Hover information           |
| Tree         | Tree views                  |
| Alert        | Alert dialogs               |
| Border       | Border containers           |
| Separator    | Visual dividers             |
| more...      |                             |

### 🖱️ Input

- Full keyboard event handling
- Mouse clicks, drags, and scroll
- Focus management
- Bracketed paste mode

### 📐 Layout

- Flex containers (row/column)
- Box model with padding/margins
- Constraint-based sizing
- Alignment options

### 🎭 Styling

- Text attributes (bold, italic, underline, etc.)
- Built-in themes (Default, Dark, Light, Nord, Dracula, Gruvbox, High Contrast)
- Custom theme support
- Various border styles

### 🎬 Animation

- Easing functions (linear, ease-in/out, bounce, elastic, etc.)
- Value interpolation
- Timer system

## Getting Started

Ready to build your first TUI app? Head to the [Getting Started](/guide/getting-started) guide!
