<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Resize Events


By the end of this guide, you will:

- Handle `Event::Resize` to store terminal dimensions in the model
- Use `tui.terminal_area` in the View to adapt layout to current terminal width
- Implement responsive pane cutoffs: hide Preview at < 120 columns, hide Tree at < 80
- Understand why immediate-mode rendering makes responsive layouts natural

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
- Builds on the proportional layout from [Step 08: Multi-Fragment Layout](./08_multi_fragment_layout.md)
- The View already re-renders every frame. Checking `tui.terminal_area.width` is all you need for cutoffs
- `Event::Resize` is useful for storing dimensions in the model (e.g., for scroll position adjustment)

---



---

[**Previous:** Mouse Events](./25_mouse_events.md) | [**Next:** Loading States](./27_loading_states.md)
