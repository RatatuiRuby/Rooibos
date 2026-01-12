<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Feature Priorities

This document outlines the remaining work before `ratatui_ruby-tea` reaches v1.0.0.

## 1. Built-In Commands

Six primitives remain unimplemented. See [Command Composition Design](./design/command_composition.md) for full specifications.

| Command / Method | Purpose | Complexity |
|------------------|---------|------------|
| `Command.wait(seconds, tag)` | One-shot timer | Low |
| `Command.tick(interval, tag)` | Recurring timer (subscriptions) | Low |
| `Command.batch([...])` | Parallel execution (fire-and-forget) | Medium |
| `Command.all([...])` | Parallel execution (aggregating) | Medium |
| `Command.http(method, url, tag)` | HTTP requests via stdlib | Medium |
| `Outlet#source(command, token)` | Command composition | Low |

Implementation order follows increasing complexity. Each can be tested independently.

> [!NOTE]
> `Command.sequence` was considered but rejected. See [Rejected Alternatives](./design/command_composition.md#rejected-alternatives) for rationale.

## 2. Documentation

The README warns: "Because this gem is in pre-release, it lacks documentation."

Before v1.0.0:

- [ ] Document all public `Command.*` factories with RDoc examples
- [ ] Write Quickstart guide
- [ ] Write Fractal Architecture guide
- [ ] Write Custom Commands guide (including `out.source` composition)
- [ ] Ensure all examples are copy-pasteable and tested
