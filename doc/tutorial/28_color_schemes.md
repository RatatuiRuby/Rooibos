<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Color Schemes


By the end of this guide, you will:

- TODO: Write learning objectives

> ⚠️ **This page is a stub.** Help us write it! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).

## User Stories

## Story 26: Configurable Color Schemes

**As a** user with color blindness  
**I want to** configure the color scheme  
**So that** I can distinguish different file types

### Acceptance Criteria
- Configuration file for color preferences (~/.config/file_browser/colors.yml)
- Multiple built-in themes:
  - Default (current colors)
  - High contrast (black/white with bold)
  - Colorblind-friendly (uses patterns + colors)
  - Monochrome (no colors, uses bold/dim/underline)
- Colors can be customized per file type
- Theme selection persists between sessions
- Theme can be changed via command-line flag
- Preview of theme before applying

### Notes
- Addresses specification section 2.3 (Accessibility)
- Introduces configuration file system
- May be deferred to 1.1 release
- Should validate color values

---



---

[**Previous:** Performance](./27_performance.md) | [**Next:** Configuration](./29_configuration.md)
