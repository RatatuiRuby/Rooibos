<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Resize Events


By the end of this guide, you will:

- TODO: Write learning objectives

> ⚠️ **This page is a stub.** Help us write it! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).

## User Stories

## Story 21: Terminal Resize Handling

**As a** terminal user  
**I want to** resize my terminal window  
**So that** the application adapts to the new size

### Acceptance Criteria
- Application detects terminal resize events
- Layout adjusts proportionally to new size
- Content reflows to fit new dimensions
- Selection and scroll position preserved
- No flickering during resize
- Graceful degradation at small sizes (hide panes)

### Notes
- Introduces resize event handling
- Introduces responsive layout logic
- Introduces graceful degradation
- Performance critical - must be smooth

---



---

[**Previous:** Mouse Events](./25_mouse_events.md) | [**Next:** Loading States](./27_loading_states.md)
