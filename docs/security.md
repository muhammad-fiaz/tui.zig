---
title: Security Policy
description: Responsible vulnerability disclosure policy and supported versions (0.1.0+ supported; below 0.1.0 unsupported/deprecated) for tui.zig.
keywords: tui.zig security, vulnerability disclosure, supported versions, deprecation policy
---

# Security Policy

## Supported Versions

Versions below `0.1.0` are **not supported** and are deprecated. Please upgrade to `0.1.0` or newer.

| Version | Status |
|---|---|
| `0.1.x` | Supported |
| `< 0.1.0` | Unsupported (deprecated) |

## Reporting a Vulnerability

If you discover a security vulnerability in **tui.zig**—such as escape-sequence injection hazards, buffer bounds bugs, raw-mode restoration issues, or VT parser memory errors—please **do not** disclose it in a public GitHub issue before coordinated review.

Report privately via GitHub Security Advisories:

- [Open a Private Security Advisory](https://github.com/muhammad-fiaz/tui.zig/security/advisories/new)

Please include affected module paths, OS/terminal backend details, `zig version` (`0.17.0+`), and minimal reproduction steps.
