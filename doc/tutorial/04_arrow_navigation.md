<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Arrow Navigation


By the end of this guide, you will:

- Add a `selected` field to your Model to track which file is highlighted
- Use `model.with(...)` to create updated state immutably
- Use pattern matching (`case message`) to handle multiple keys
- Combine pattern matching with predicate guards (`in _ if message.up?`)
- Handle arrow keys (up/down) and vim keys (j/k) in one UPDATE
- Scroll through the file list when it's longer than the screen
- Return an updated model from UPDATE to change state
- Write tests that verify state transitions (selected: 0 → selected: 1)
- Understand when to use pattern matching vs simple if/else

> ⚠️ **This page is a stub.** Help us write it! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).

## User Stories

## Story -1: Arrow Key Navigation

**As a** terminal user  
**I want to** navigate through the file list with arrow keys  
**So that** I can select different files

### Acceptance Criteria
- Up/Down arrow keys change which file is highlighted
- 'j'/'k' vim keys also work for navigation
- Selection wraps at top/bottom of list
- Visual highlight follows selection

### Notes
- Still using hardcoded file list
- Adds interactive navigation

---



---

[**Previous:** Static File List](./03_static_file_list.md) | [**Next:** Real Files](./05_real_files.md)
