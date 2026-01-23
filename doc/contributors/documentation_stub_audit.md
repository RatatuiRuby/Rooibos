<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Documentation Stub Audit

Audit of learning objectives against the actual Rooibos codebase.

**Legend:**
- ⚠️ Minor issue or suggestion
- ❌ Major issue, needs revision

---

## Essentials

## Scaling Up

## Best Practices

### `forms_and_validation.md`

**Audit:**
- ❌ **MAJOR:** Need `examples/app_form/` — multi-field form with validation
- ❌ **MAJOR:** Need validation error display example in the form app

---

### `lists_and_tables.md`

**Audit:**
- ❌ **MAJOR:** Need `examples/app_master_detail/` — list sidebar + table top-right + detail pane bottom-right (list chooses table, table chooses detail)

---

### `http_workflows.md`

**Audit:**
- ❌ **MAJOR:** Need `examples/app_web_api/` — retry logic with exponential backoff
- ❌ **MAJOR:** Need caching example in the HTTP app

---

### `streaming_data.md`

**Audit:**
- ❌ **MAJOR:** Need `examples/app_websocket/` — simplified version of official third-party WebSocket gem to teach SSE/websocket patterns

---

### `orchestration.md`

**Audit:**
- ❌ **MAJOR:** Need `examples/app_command_orchestration/` — partial failure handling and multi-step pipeline patterns

---

## Troubleshooting

## Tutorial

### `index.md`

**Audit:**
- ❌ **MAJOR:** Need `examples/app_file_browser/` — complete example that tutorial chapters will walk through building

---

### `04_handling_input.md`

**Audit:**
- ℹ️ **Objective 5:** References the file browser from `examples/app_file_browser/` — tutorial walks through building it

---

### `08_the_preview_pane.md`

**Audit:**
- ℹ️ **Objective 1:** References the file browser from `examples/app_file_browser/` — tutorial walks through building it

---

### `11_polish_and_refine.md`

**Audit:**
- ℹ️ **Objective 1:** Edge case handling is application logic — teach patterns, not framework features
- ℹ️ **Objective 2:** Help overlay is application-level UI — teach implementation patterns

---

### `12_going_further.md`

**Audit:**
- ℹ️ All objectives are purely meta/navigational — appropriate for "Going Further" chapter

---

## Getting Started

### `for_go_developers.md`

**Audit:**
- ℹ️ **Objective 3:** Rooibos Cmd pattern differs — uses `Command::Custom` protocol vs BubbleTea's `tea.Cmd` function (teach the difference)
- ❌ **MAJOR:** Need `examples/app_bubbletea_counter/` — side-by-side comparison with equivalent BubbleTea code

---

### `ruby_primer.md`

**Audit:**
- ℹ️ All objectives are Ruby language education — appropriate for onboarding non-Rubyists
