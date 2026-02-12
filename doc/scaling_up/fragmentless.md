<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Simple Apps Don't Need Fragments

After reading this guide, you will know:

- How to build a complete Rooibos app without fragments or routers
- When simple architecture is the right choice
- Why the other composition guides exist

---

## Context

You want to build a TUI app. You've read about Rooibos's fractal architecture, its Router DSL, its composition patterns. The documentation seems to assume you'll decompose your app into reusable fragments with explicit data flow.

But your app isn't complex. It's a utility. A dashboard. A small tool.

## Problem

Architectural patterns solve architectural problems. Using them on simple apps creates unnecessary ceremony. You end up with five files where one would do. You write routers for apps that have three keybindings.

Composition patterns exist for apps that need composition. Most apps don't.

## Solution

Write simple apps simply. One module. One model. One update. One view.

This guide shows the same 7-counter example used in [Router-Based Composition](message_routing.md) and [Routerless Composition](routerless.md). Those guides decompose it into fragments to demonstrate patterns. This guide shows how you'd actually write it.

---

## The Example

Seven counters. Keyboard controls. Two thresholds:
- **Count hits 5:** Track a milestone at Root
- **Count hits 10:** Reset the counter and track the reset at the parent

```
Root
├── Left Panel
│   ├── Left Top
│   └── Left Bottom
└── Right Panel
    ├── Right Top
    └── Right Bottom
```

**Keyboard mapping:**
- `Enter` → Root's counter
- `a`, `b` → Panel counters
- `1`, `2`, `3`, `4` → Leaf counters (Left Top, Left Bottom, Right Top, Right Bottom)

---

## The Code

```ruby
module SevenCounters
  Model = Data.define(
    :root_count, :milestones,
    :left_panel_count, :left_panel_resets,
    :right_panel_count, :right_panel_resets,
    :left_top, :left_bottom, :right_top, :right_bottom
  )

  Init = -> {
    Model.new(
      root_count: 0, milestones: 0,
      left_panel_count: 0, left_panel_resets: 0,
      right_panel_count: 0, right_panel_resets: 0,
      left_top: 0, left_bottom: 0, right_top: 0, right_bottom: 0
    )
  }

  Update = -> (message, model) {
    return Rooibos::Command.exit if message.ctrl_c?

    case message
    in { type: :key } if message.enter?
      increment_root(model)

    in { type: :key } if message.a?
      increment(model, :left_panel_count, :left_panel_resets)

    in { type: :key } if message.b?
      increment(model, :right_panel_count, :right_panel_resets)

    in { type: :key } if message.one?
      increment(model, :left_top, :left_panel_resets)

    in { type: :key } if message.two?
      increment(model, :left_bottom, :left_panel_resets)

    in { type: :key } if message.three?
      increment(model, :right_top, :right_panel_resets)

    in { type: :key } if message.four?
      increment(model, :right_bottom, :right_panel_resets)

    else
      model
    end
  }

  def self.increment(model, counter, resets)
    new_count = model.public_send(counter) + 1
    case new_count
    when 5
      model.with(counter => new_count, milestones: model.milestones + 1)
    when 10
      model.with(counter => 0, resets => model.public_send(resets) + 1)
    else
      model.with(counter => new_count)
    end
  end

  def self.increment_root(model)
    new_count = model.root_count + 1
    case new_count
    when 5
      model.with(root_count: new_count, milestones: model.milestones + 1)
    when 10
      model.with(root_count: 0)  # Root has no parent, just reset
    else
      model.with(root_count: new_count)
    end
  end

  View = -> (model, tui) {
    tui.block(
      title: "Root [#{model.root_count}] (milestones: #{model.milestones})",
      borders: [:all],
      children: [
        tui.layout(
          direction: :horizontal,
          constraints: [tui.constraint_percentage(50), tui.constraint_percentage(50)],
          children: [
            panel_view(tui, "Left Panel", model.left_panel_count, model.left_panel_resets,
                       model.left_top, model.left_bottom, "Left Top", "Left Bottom"),
            panel_view(tui, "Right Panel", model.right_panel_count, model.right_panel_resets,
                       model.right_top, model.right_bottom, "Right Top", "Right Bottom")
          ]
        )
      ]
    )
  }

  def self.panel_view(tui, name, count, resets, top_leaf, bottom_leaf, top_name, bottom_name)
    tui.block(
      title: "#{name} [#{count}] (resets: #{resets})",
      borders: [:all],
      children: [
        tui.layout(
          direction: :vertical,
          constraints: [tui.constraint_percentage(50), tui.constraint_percentage(50)],
          children: [
            tui.block(title: "#{top_name} [#{top_leaf}]", borders: [:all]),
            tui.block(title: "#{bottom_name} [#{bottom_leaf}]", borders: [:all])
          ]
        )
      ]
    )
  end
end

Rooibos.run(SevenCounters)
```

~90 lines. One module. Everything in one place.

---

## When This Works

Simple apps have simple needs:

- **State fits in one model.** You can see all the fields at once.
- **Update is readable.** One case statement handles everything.
- **View is straightforward.** Helper methods compose widgets without ceremony.
- **No reuse.** This code exists for this app only.

The 7-counter example meets all these criteria. It doesn't need fragments.

---

## When to Graduate

Consider fragments when you have:

- **Reusable UI.** A text editor, a data grid, or other user interfaces used in multiple places.
- **Independent lifecycles.** A chat panel that fetches messages while the main app does other work.
- **Team boundaries.** Different people own different parts of the app.
- **Update beyond ~100 lines.** Time to decompose.
- **Nested state machines.** State that's hard to reason about in one place.

---

## About the Other Guides

[Router-Based Composition](message_routing.md) and [Routerless Composition](routerless.md) use this same 7-counter example. They decompose it into fragments to demonstrate architectural patterns.

Those guides are **constrained examples**. They show how to compose, not whether you should. The patterns exist for apps that need them.

If your app is simple, stay here. Write it like this. Read the composition guides when your app grows complex enough to need them.

---

## See Also

- [Router-Based Composition](message_routing.md) — Declarative patterns with the Router DSL
- [Routerless Composition](routerless.md) — Explicit patterns without the Router
- [Fractal Architecture](fractal_architecture.md) — When and why to decompose
