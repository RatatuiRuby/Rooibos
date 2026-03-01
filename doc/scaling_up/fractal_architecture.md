<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Fractal Architecture

After reading this guide, you will know:

- How to compose child fragments using the Router DSL
- How to route parent messages to the correct child
- How to pass pre-rendered widgets into a child's View (widget slots)
- How to use the Router DSL to simplify complex routing
- When fractal architecture is worth the complexity

---

## Context

Your app starts simple. One Model, one Update, one View. A file browser fits in a single module.

Then features grow. The file browser gains a preview pane. A status bar. Multiple tabs. A command palette.

## Problem

Big apps become unmanageable. A single Update function handles dozens of message types. The Model grows to twenty fields. Testing requires mocking the entire world.

Worse: you can't reuse code. The preview pane logic is tangled with the tab logic. Extracting it would mean untangling a web of dependencies.

## Solution

Rooibos supports **fractal architecture**. Each piece of your UI can be its own fragment with:

- Its own **Init** — setting up its initial model
- Its own **Update** — handling only its own messages
- Its own **View** — returning only its own widget subtree

The parent composes these together. It's turtles all the way down — or all the way up.

---

## A Fragment Is Just a Module

A fragment is any module with `Model`, `Init`, `Update`, and `View`:

```ruby
module PreviewPane
  PaneContent = Data.define(:content, :scroll_position)

  Init = -> {
    PaneContent.new(content: "", scroll_position: 0)
  }

  Update = -> (message, model) {
    case message
    in { type: :routed, envelope: :scroll_down }
      model.with(scroll_position: model.scroll_position + 1)
    in { type: :routed, envelope: :scroll_up }
      model.with(scroll_position: [0, model.scroll_position - 1].max)
    else
      model
    end
  }

  View = -> (model, tui) {
    tui.paragraph(text: model.content)
  }
end
```

This fragment knows nothing about its parent. It receives messages, updates its model, renders its view. That's it.

---

## Model Composition

The parent's Model holds child models as fields:

```ruby
module FileBrowser
  # Parent model contains child models
  Model = Data.define(:files, :preview, :status_bar)

  Init = -> {
    files = FileList::Init.()
    preview = PreviewPane::Init.()
    status = StatusBar::Init.()

    Model.new(files:, preview:, status_bar: status)
  }
end
```

Each child model is independent. The parent just holds references.

---

## The Router Handles Dispatch

Instead of writing dispatch logic manually, use the Router DSL:

```ruby
module FileBrowser
  include Rooibos::Router

  Model = Data.define(:files, :preview, :status_bar)

  route :files, to: FileList
  route :preview, to: PreviewPane
  route :status_bar, to: StatusBar

  action move_down: FileList, keys: %i[down j]
  action move_up: FileList, keys: %i[up k]
  action scroll_down: PreviewPane, key: :ctrl_j
  action scroll_up: PreviewPane, key: :ctrl_k
  action -> { Command.exit }, key: :q

  Update = from_router

  Init = -> {
    Model.new(
      files: FileList::Init.(),
      preview: PreviewPane::Init.(),
      status_bar: StatusBar::Init.()
    )
  }

  View = -> (model, tui) {
    tui.layout(direction: :horizontal, children: [
      FileList::View.call(model.files, tui),
      PreviewPane::View.call(model.preview, tui),
    ])
  }
end
```

The Router:
1. Maps keys to semantic actions
2. Dispatches actions to the correct child fragment
3. Routes command responses back to originating children
4. Merges child models back into the parent

See [Message Routing](./message_routing.md) for details.

---

## Widget Slots

Sometimes an outer fragment needs to inject its own widgets *between* parts of an inner fragment's view. A panel layout renders the file list and preview side by side, but the outer fragment wants a path bar above them.

In this case, the outer fragment pre-renders a widget and passes it as an argument to the inner fragment's View:

```ruby
module FileBrowser
  View = -> (model, tui) {
    # FileBrowser renders the path bar
    path_bar = PathBar::View[model.path_bar, tui]

    # FileBrowser passes it to PanelLayout as a slot
    panels = PanelLayout::View[model.panels, tui, path_bar]

    tui.layout(
      direction: :vertical,
      constraints: [tui.constraint_fill(1), tui.constraint_length(1)],
      children: [panels, StatusBar::View[model.status_bar, tui]]
    )
  }
end
```

The inner fragment receives the pre-rendered widget and places it within its own layout:

```ruby
module PanelLayout
  View = -> (model, tui, header_slot) {
    files = FileList::View[model.files, tui]
    preview = PreviewPane::View[model.preview, tui]
    panes = tui.layout(
      direction: :horizontal,
      constraints: [tui.constraint_percentage(40), tui.constraint_fill(1)],
      children: [files, preview]
    )
    tui.layout(
      direction: :vertical,
      constraints: [tui.constraint_length(1), tui.constraint_fill(1)],
      children: [header_slot, panes]
    )
  }
end
```

PanelLayout doesn't know what `header_slot` is. It could be a path bar, a breadcrumb trail, or an empty widget. The outer fragment decides; the inner fragment just places it.

If you know Ember, this is `{{yield}}`. If you know React, it's the `children` prop. If you know Rails, it's `content_for`/`yield :section` in layouts. In BubbleTea, the outer model's `View()` always controls composition — there's no slot mechanism, so this pattern gives Rooibos more flexibility. The outer fragment owns the data and rendering; the inner fragment owns the layout position.

> **Tip**: Use widget slots when an inner fragment controls the layout but a sibling fragment's view belongs inside it. Keep the slot count small (one or two at most).

---

## Manual Dispatch (Without Router)

For full control, write the dispatch logic yourself:

```ruby
Update = -> (message, model) {
  case message
  # Dispatch to file list
  in { type: :routed, envelope: :move_down | :move_up }
    new_files, cmd = FileList::Update.call(message, model.files)
    [model.with(files: new_files), cmd]

  # Dispatch to preview
  in { type: :routed, envelope: :scroll_down | :scroll_up }
    new_preview, cmd = PreviewPane::Update.call(message, model.preview)
    [model.with(preview: new_preview), cmd]

  # Handle parent-level messages
  in { type: :key } if message.q?
    Command.exit

  else
    model
  end
}
```

Each child Update receives only its model slice. The parent merges the new child model back using `model.with(...)`.

> **Tip**: Start with the Router. Only drop to manual dispatch if you need control the Router doesn't provide.

---

## When to Extract a Fragment

Extract a fragment when:

- **Reuse** — The same UI appears in multiple places
- **Testing** — You want to test one piece in isolation
- **Complexity** — The Update function is getting hard to follow
- **Ownership** — Different team members own different pieces

Keep things inline when:

- The component is simple (< 50 lines total)
- It's only used in one place
- Extraction would add more boilerplate than it saves

> **Tip**: Start inline, extract when you feel pain. Don't over-engineer upfront.

---

## Summary

Fractal architecture means:

- **Fragments are independent** — Each has its own Model, Update, View, Init
- **Parents compose children** — Parent model holds child models as fields
- **Router handles dispatch** — Use `from_router` to automate message routing
- **Models merge up** — Child returns new model, parent merges with `with(...)`
- **Commands route back** — Responses find their way to the originating child

This scales to any depth. Root → Tabs → Panels → Panes → Widgets. Each level only knows about its direct children.

---

Related: [Message Routing](./message_routing.md) | [Command Composition](./command_composition.md) | [The Elm Architecture](../essentials/the_elm_architecture.md)

---

[**Previous:** Command Composition](./command_composition.md) | [**Next:** Message Routing](./message_routing.md)
