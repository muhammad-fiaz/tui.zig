# Security Policy

## Supported Versions

Versions below `0.1.0` are **not supported** and are deprecated. Please upgrade to `0.1.0` or newer.

| Version | Supported |
|---|---|
| `0.1.x` | Supported |
| `< 0.1.0` | Unsupported (deprecated) |

## Reporting a Vulnerability

If you discover a security vulnerability in **tui.zig**—for example escape-sequence injection hazards, integer overflows in terminal buffer indexing, raw-mode restoration bugs, or out-of-bounds memory access in ANSI/VT input parsing—please report it responsibly.

**Do not open a public GitHub issue for undisclosed security vulnerabilities.**

Instead, please report security issues privately using GitHub Security Advisories at:

- https://github.com/muhammad-fiaz/tui.zig/security/advisories/new

Include in your report:

1. A concise description of the issue and potential impact.
2. Affected module paths, OS/terminal backend, and Zig version (`zig version`).
3. Minimal reproduction steps or failing test case if available.

We aim to acknowledge reports within 48 hours and work promptly toward a verified patch and coordinated release note.
