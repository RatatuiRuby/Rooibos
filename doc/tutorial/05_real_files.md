<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Real Files


By the end of this guide, you will:

- Load real files from your current directory instead of static examples
- See your tests fail and understand why
- Fix your tests by telling them what files to expect
- Understand why good tests don't depend on the filesystem
- Know when to use fake data in tests
- Have a file browser that works with your files

> ⚠️ **This page is a stub.** Help us write it! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).

## User Stories

## Story 0: Real Files

**As a** terminal user  
**I want to** see my actual files instead of example data  
**So that** the file browser is useful for real work

### Acceptance Criteria
- Application shows actual files from the current directory
- File list reflects real filesystem contents
- Can navigate through real files with arrow keys
- All previous keyboard shortcuts still work

### Notes
- **Critical transition** - from example data to real filesystem
- Transforms toy example into functional tool
- After this story, Story 1 is COMPLETE

---



---

[**Previous:** Arrow Navigation](./04_arrow_navigation.md) | [**Next:** Safe Refactoring](./06_safe_refactoring.md)
