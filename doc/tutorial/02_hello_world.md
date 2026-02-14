<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Hello World


By the end of this guide, you will:

- Write your first View callable that renders text to the terminal
- Write your first Update callable that handles keyboard events
- Use pattern matching (`case message in type: :key, code:`) to check which key was pressed
- Return `Command.exit` from Update to quit the application
- Understand what `Rooibos.run` does to start your app
- Understand what a View returns (RatatuiRuby widgets like `paragraph`)
- Understand what an Update returns (model or command)
- Run your app and see it respond to keyboard input

> ⚠️ **This page is a stub.** Help us write it! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).

## User Stories

## Story -3: Hello World + Quit

**As a** terminal user  
**I want to** launch a minimal TUI application that I can quit  
**So that** I can verify the application runs

### Acceptance Criteria
- Application displays "Hello, File Browser!" text
- Application displays "Press 'q' to quit" instruction
- Pressing 'q' or Ctrl+C exits the application cleanly

### Notes
- First runnable TUI application
- Demonstrates basic rendering and quit functionality

---



---

[**Previous:** Project Setup](./01_project_setup.md) | [**Next:** Static File List](./03_static_file_list.md)
