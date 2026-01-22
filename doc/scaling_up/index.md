<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Scaling Up

Advanced patterns for building larger Rooibos applications.

---

## Custom Async Work

- [**Custom Commands**](./custom_commands.md) — Write your own async commands with `out` and `token`
- [**Command Composition**](./command_composition.md) — Chain and parallelize with `out.source`, `out.standing`

## Application Architecture

- [**Fractal Architecture**](./fractal_architecture.md) — Nested fragments with `Cmd.map`
- [**Message Routing**](./message_routing.md) — The Router DSL for complex apps

## Production Concerns

- [**Ractor Safety**](./ractor_safety.md) — Future-proof your app for Ruby 4
- [**Async Patterns**](./async_patterns.md) — Streaming, polling, websockets
- [**Testing**](./testing.md) — Comprehensive testing strategies

---

**Looking for recipes?** Check out [Best Practices](../best_practices/modal_dialogs.md).
