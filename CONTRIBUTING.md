# Contributing to TUI.zig

Thank you for your interest in contributing to TUI.zig! This document provides guidelines and information for contributors.

## Getting Started

### Prerequisites

- Zig 0.16.0 or later
- Git
- A terminal emulator for testing

### Setting Up the Development Environment

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/your-username/tui.zig.git
   cd tui.zig
   ```
3. Add the upstream remote:
   ```bash
   git remote add upstream https://github.com/muhammad-fiaz/tui.zig.git
   ```

### Building the Project

```bash
zig build
```

### Running Tests

```bash
zig build test
```

## Development Workflow

### Branch Naming

Use descriptive branch names:
- `feature/widget-name` - for new widgets
- `fix/issue-description` - for bug fixes
- `docs/section` - for documentation changes
- `refactor/component` - for code refactoring

### Commit Messages

Write clear, concise commit messages:
- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Fix bug" not "Fixes bug")
- Keep the first line under 72 characters
- Reference issues and pull requests when relevant

Example:
```
Add Tab widget component

- Implements basic Tab widget with keyboard navigation
- Supports tab switching with arrow keys
- Adds styling options for active/inactive tabs

Closes #42
```

### Code Style

Follow Zig coding conventions:
- Use `camelCase` for function and variable names
- Use `TitleCase` for type names
- Use `snake_case` for file names
- Keep functions focused and small
- Add doc comments for public APIs

### Testing

- Write tests for new functionality
- Ensure all existing tests pass
- Test on multiple platforms when possible (Linux, macOS, Windows)

## Types of Contributions

### Bug Reports

When reporting bugs, please include:
- Zig version and target platform
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- Code sample if applicable

### Feature Requests

For new features:
- Check existing issues for duplicates
- Describe the use case
- Provide examples of how it would be used
- Consider backwards compatibility

### Documentation

Documentation improvements are always welcome:
- Fix typos and grammatical errors
- Add examples for complex APIs
- Improve explanations
- Add tutorials or guides

### Widgets

When adding a new widget:
1. Create the widget implementation in `src/widgets/`
2. Add corresponding tests
3. Update the widget documentation in `docs/guide/widgets/`
4. Add the widget to the sidebar in `docs/.vitepress/config.mts`
5. Export the widget in `src/tui.zig`

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes
3. Run tests: `zig build test`
4. Update documentation if needed
5. Push your changes and create a pull request
6. Fill out the PR template
7. Wait for review and address feedback

### PR Requirements

- All tests must pass
- Code must follow the project's style guidelines
- Documentation must be updated for new features
- PR description should clearly explain the changes

## Architecture

### Source Code Structure

```
src/
  tui.zig          # Main module entry point
  app.zig          # Application lifecycle
  core/            # Core components
  widgets/         # Widget implementations
  event/           # Event handling
  style/           # Styling and themes
  layout/          # Layout system
  animation/       # Animation system
  unicode/         # Unicode handling
  platform/        # Platform-specific code
```

### Key Concepts

- **App**: The main application container that manages the event loop
- **Widget**: UI components that can be rendered and handle events
- **RenderContext**: Provides drawing primitives to widgets
- **Event**: User input events (keyboard, mouse, etc.)
- **Style**: Visual styling (colors, borders, etc.)

## Community

- [GitHub Issues](https://github.com/muhammad-fiaz/tui.zig/issues) - Bug reports and feature requests
- [GitHub Discussions](https://github.com/muhammad-fiaz/tui.zig/discussions) - General discussion

## License

By contributing to TUI.zig, you agree that your contributions will be licensed under the MIT License.

## Questions?

If you have questions about contributing, feel free to open an issue or start a discussion on GitHub.
