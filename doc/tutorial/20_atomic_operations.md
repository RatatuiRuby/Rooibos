<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Atomic Operations


By the end of this guide, you will:

- TODO: Write learning objectives

> ⚠️ **This page is a stub.** Help us write it! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).

## User Stories

## Story 16: Move Files and Directories

**As a** terminal user  
**I want to** move files to another location  
**So that** I can reorganize my filesystem

### Acceptance Criteria
- `m` key prompts for destination path
- User types destination and presses Enter
- File/directory moved to destination
- File list refreshes to remove moved item
- Error shown if move fails
- Handles cross-filesystem moves

### Notes
- Similar to copy but removes source
- May need to fall back to copy+delete for cross-filesystem
- Introduces atomic operation handling

---



---

[**Previous:** Progress Indicators](./19_progress_indicators.md) | [**Next:** External Editor](./21_external_editor.md)
