<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Tabbed Fragments

Demonstrates **every documented Router API** in a multi-level fragment
hierarchy with tabbed navigation, outward communication, and theme cycling.

## Architecture

```
App (root)
├── TabBar           → bubble TabSelected on [/] or click
├── CounterTab       → 7 counters across 4 levels
│   ├── Left Panel
│   │   ├── LT Leaf
│   │   └── LB Leaf
│   └── Right Panel
│       ├── RT Leaf
│       └── RB Leaf
├── ColorTab         → scrollable color picker
└── Controls         → stateless hotkey display
```

## Hotkeys

| Key       | Action                          |
|-----------|---------------------------------|
| `[` / `]` | Switch tabs                     |
| Click     | Select tab in TabBar            |
| `t`       | Cycle theme (cyan → green → magenta → yellow) |
| `q`       | Quit                            |
| `Ctrl+C`  | Force quit                      |

**Counter Tab:**

| Key     | Action            |
|---------|-------------------|
| `1`–`4` | Increment leaves (LT, LB, RT, RB) |
| `a` / `b` | Increment panels (Left, Right) |
| `Enter` | Increment root counter |

**Color Tab:**

| Key           | Action        |
|---------------|---------------|
| `1`–`6`       | Select color  |
| `Enter`       | Random color  |

## Router API Coverage

Every Router API is exercised somewhere in the hierarchy:

| API | Fragment | Purpose |
|-----|----------|---------|
| `route` | App, CounterTab, Panel | Declare child fragment routes |
| `action` | App | Named `:quit` handler |
| `forward_events` with `as:` | App | Semantic envelope routing (keys → `Message::Routed`) |
| `forward_routed` with `as:` | CounterTab, Panel | Envelope transformation between layers |
| `forward_instances_of` with `broadcast:` | App | Resize to all routes |
| `receive_events` | TabBar | `[`/`]` navigation |
| `receive_routed` | CounterTab, Panel, Leaf | Handle semantic envelopes |
| `intercept_events` | App | `q`, `Ctrl+C` |
| `intercept_all` with `unless:` | CounterTab, ColorTab | Disable input when inactive |
| `intercept_instances_of` | Panel | Transform `LeafReset` → `PanelChildReset` |
| `observe_all` | App | Count all messages |
| `observe_instances_of` | App, CounterTab | Track resets, milestones, tab/color/theme changes |
| `only`/`skip` guards | App | Conditional routing by active tab |
| `route_to` blocks | App, CounterTab | Scoped destination for multiple forwards |
| `otherwise` | App | Fallback routing to TabBar |
| `from_router` | All | Generate Update from declarations |
| `Command.bubble` | Leaf, Panel, ColorTab, TabBar | Outward communication through hierarchy |
| `Command.deliver` | Leaf, Panel | Fire-and-forget milestones to Root |
| `Message::Predicates` | All messages | Type predicates (e.g., `message.milestone?`) |

## Key Concepts

1. **Semantic envelope transformation.** Each layer speaks its child's API, not
   raw key names. App sends `:counter_1`; CounterTab transforms to `:leaf_1`;
   Panel transforms to `:increment`. Change keybindings at Root without
   touching inner fragments.

2. **Outward communication.** Leaves `bubble` resets through the hierarchy.
   Panels intercept, add context, and re-bubble as `PanelChildReset`. Leaves
   also `deliver` milestones directly to Root, bypassing intermediate fragments.

3. **Guard-based routing.** `only when: COUNTER_ACTIVE` scopes an entire block
   of `forward_events` declarations to the active tab. Inactive tabs use
   `intercept_all` with `unless:` to silently swallow input.

4. **Observe without blocking.** `observe_all` counts every message without
   preventing other handlers from running. `observe_instances_of` tracks
   resets and milestones as side effects.

5. **Mouse support.** TabBar handles `mouse_left_down` events for click-to-
   select tabs, demonstrating mouse event routing alongside keyboard input.

## Usage

```bash
ruby examples/app_tabbed_fragments/app.rb
```

## See Also

- [Fractal Dashboard](../app_fractal_dashboard/README.md) — Simpler Router
  example with async commands and a modal overlay
- [Router-Based Composition Patterns](../../doc/scaling_up/message_routing.md)
  — Full guide to the Router DSL
