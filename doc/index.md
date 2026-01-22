<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Rooibos Documentation

Build terminal user interfaces with Ruby using The Elm Architecture.

---

## Getting Started

New to Rooibos? Start here.

- [**Why Rooibos?**](./getting_started/why_rooibos.md) — What is a TUI? Why functional state management?
- [**Installation**](./getting_started/install.md) — Set up Ruby and add Rooibos to your project
- [**Quickstart**](./getting_started/quickstart.md) — Build your first app in 5 minutes

### Coming from another ecosystem?

- [For React Developers](./getting_started/for_react_developers.md) — Redux → Rooibos mental model
- [For Go Developers](./getting_started/for_go_developers.md) — BubbleTea → Rooibos translation
- [For Python Developers](./getting_started/for_python_developers.md) — Textual → Rooibos translation
- [Ruby Primer](./getting_started/ruby_primer.md) — Ruby basics for polyglots

---

## Tutorial

Learn by building a complete **File Browser** application.

→ [**Start the Tutorial**](./tutorial/index.md)

---

## Essentials

Deep-dive into core concepts.

- [The Elm Architecture](./essentials/the_elm_architecture.md) — Model-View-Update explained
- [Models](./essentials/models.md) — Designing state with `Data.define`
- [Messages](./essentials/messages.md) — Events and pattern matching
- [Update Functions](./essentials/update_functions.md) — Pure state transitions
- [Views](./essentials/views.md) — Rendering with RatatuiRuby
- [Commands](./essentials/commands.md) — Async operations and side effects
- [The Runtime](./essentials/the_runtime.md) — How Rooibos runs your app
- [Shortcuts](./essentials/shortcuts.md) — `Cmd` and `Msg` aliases

---

## Scaling Up

Advanced patterns for larger applications.

- [Custom Commands](./scaling_up/custom_commands.md) — Write your own async commands
- [Command Composition](./scaling_up/command_composition.md) — Chain and parallelize work
- [Fractal Architecture](./scaling_up/fractal_architecture.md) — Nested fragments with `Cmd.map`
- [Message Routing](./scaling_up/message_routing.md) — The Router DSL
- [Ractor Safety](./scaling_up/ractor_safety.md) — Future-proof your app
- [Async Patterns](./scaling_up/async_patterns.md) — Streaming, polling, websockets
- [Testing](./scaling_up/testing.md) — Comprehensive testing strategies

---

## Best Practices

Common UI patterns and recipes.

- [Modal Dialogs](./best_practices/modal_dialogs.md)
- [Forms and Validation](./best_practices/forms_and_validation.md)
- [Lists and Tables](./best_practices/lists_and_tables.md)
- [HTTP Workflows](./best_practices/http_workflows.md)
- [Streaming Data](./best_practices/streaming_data.md)
- [Orchestration](./best_practices/orchestration.md)

---

## Troubleshooting

When things go wrong.

- [Common Errors](./troubleshooting/common_errors.md) — Error messages and fixes
- [Debugging](./troubleshooting/debugging.md) — Tracing and inspection
- [Performance](./troubleshooting/performance.md) — Optimization tips

---

## For Contributors

- [Documentation Plan](./contributors/documentation_plan.md) — The roadmap for these docs
- [Documentation Style Guide](./contributors/documentation_style.md) — How to write docs
- [Design Documents](./contributors/design/) — Architecture decisions
