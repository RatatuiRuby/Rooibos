<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# External Editor


By the end of this guide, you will:

- TODO: Write learning objectives

> ⚠️ **This page is a stub.** Help us write it! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).

## User Stories

## Story 17: Open in External Editor

**As a** terminal user  
**I want to** open the selected file in my $EDITOR  
**So that** I can edit files

### Acceptance Criteria
- `e` key opens file in $EDITOR
- File browser suspends while editor runs
- File browser resumes when editor closes
- File list refreshes to show any changes
- Error shown if $EDITOR not set or fails

### Notes
- Introduces external process spawning
- Introduces suspend/resume cycle
- Introduces environment variable reading
- Tests integration with external tools

---



---

[**Previous:** Atomic Operations](./20_atomic_operations.md) | [**Next:** Modal Overlays](./22_modal_overlays.md)
