<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Filtering


By the end of this guide, you will:

- TODO: Write learning objectives

> ⚠️ **This page is a stub.** Help us write it! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).

## User Stories

## Story 10: Filter Files by Name

**As a** terminal user  
**I want to** filter the file list by typing a pattern  
**So that** I can quickly find specific files

### Acceptance Criteria
- `f` key opens filter input
- User types pattern (supports * and ? wildcards)
- File list updates to show only matching items
- Status bar shows filter pattern and match count
- Esc clears filter
- Filter is case-insensitive

### Notes
- Introduces text input mode
- Introduces filtering logic
- Introduces wildcard matching
- Introduces mode switching (normal vs input)

---



---

[**Previous:** Sorting](./13_sorting.md) | [**Next:** Toggle Hidden Files](./15_toggle_hidden.md)
