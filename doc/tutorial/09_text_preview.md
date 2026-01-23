<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Text Preview


By the end of this guide, you will:

- Build a third Fragment for the preview pane
- Read file contents using Ruby's File API
- Detect whether a file is text or binary

> ⚠️ **This page is a stub.** Help us write it! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).

## User Stories

## Story 6: Text File Preview

**As a** terminal user  
**I want to** see a preview of text files in the preview pane  
**So that** I can verify file contents before opening

### Acceptance Criteria
- When text file is selected, preview pane shows first ~20 lines
- Preview updates as selection changes
- Binary files show "Binary file" message
- Preview pane scrolls if content is long
- File type is detected (text vs binary)

### Notes
- Introduces file reading
- Introduces text detection
- Introduces preview scrolling
- Limit to first 1000 lines for performance

---



---

[**Previous:** File Metadata](./08_file_metadata.md) | [**Next:** Directory Tree](./10_directory_tree.md)
