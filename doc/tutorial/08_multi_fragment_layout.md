<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Multi-Fragment Layout


By the end of this guide, you will:

- Compose five Fragments (TitleBar, DirectoryTree, FileList, Preview, StatusBar) within a nested layout
- Use selective borders to avoid visual duplication between adjacent panes
- Use `tui.block` as a container widget, nesting layouts inside blocks for inline titles and padding
- Size panes proportionally with percentage-based constraints (25% / 40% / 35%) so the layout scales to any terminal width
- Understand when to split UI into separate Fragments

> [!NOTE]
> The 25/40/35 split works at any terminal width, but on narrow terminals the side panes become
> unusably small. In [Step 26: Resize Events](./26_resize_events.md), you'll use `tui.terminal_area`
> to conditionally hide panes below width cutoffs (Preview at < 120 columns, Tree at < 80).

> ⚠️ **This page is a stub.** Help us write it! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).

---

[**Previous:** Red-First TDD](./07_red_first_tdd.md) | [**Next:** File Metadata](./09_file_metadata.md)
