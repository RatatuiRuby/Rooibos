<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Message Routing

After reading this guide, you will know:

- How to use the Router DSL (`include Rooibos::Router` then `route :prefix, to: Module`)
- How to delegate messages to child fragments cleanly
- How to handle cross-cutting concerns (logging, analytics) centrally
- How to debug message routing with logging

---

## Context

You've adopted [fractal architecture](./fractal_architecture.md). Your app has parent fragments containing child fragments. Now messages need to flow:

- **Down**: User input → parent → appropriate child
- **Up**: Child command → wrapped response → back to child

## Problem

Manual message dispatch is tedious and error-prone. Every parent duplicates the same pattern. Adding a child means touching every case branch. Forgetting to route a command response means lost messages.

## Solution

The **Router DSL** handles all message routing automatically:

```ruby
module FileBrowser
  include Rooibos::Router

  route :files, to: FileList
  route :preview, to: PreviewPane

  action move_down: FileList, keys: %i[down j]
  action move_up: FileList, keys: %i[up k]
  action scroll_preview: PreviewPane, keys: %i[ctrl_j ctrl_k]
  action -> { Command.exit }, key: :q

  Update = from_router
end
```

The Router:
1. Maps key presses to semantic actions
2. Dispatches actions to the correct child
3. Wraps outbound commands with route info
4. Unwraps inbound responses and dispatches to children

---

## Route Declarations

Declare which child fragments exist and where their models live:

```ruby
route :files, to: FileList
```

This tells the Router:
- The this (parent) fragment's model has a `:files` attribute
- That attribute holds the instantiated model data
- Messages for `FileList` should be dispatched to `FileList::Update` with the `model.files` data
- `FileList`'s `Update` receives and changes that data
- New models returned by `FileList::Update` should be sent to this (parent) fragment's model's `files=` method

---

## Action Declarations

Actions map user input to child fragments:

```ruby
# Semantic action routed to a child fragment
action move_down: FileList, keys: %i[down j]

# Anonymous action handled by the parent
action -> { Command.exit }, key: :q
```

When the user presses `j`:
1. Router finds the `move_down` action targets `FileList`
2. Router synthesizes `Message::Routed.new(envelope: :move_down, event: key_event)`
3. Router calls `FileList::Update.call(routed_message, model.files)`
4. Child pattern matches on `message.move_down?` or `{ type: :routed, envelope: :move_down }`

The child doesn't know which key was pressed — it just knows the semantic intent.

---

## Message Types

The Router sends two kinds of messages to child fragments' `Update` callables. For semantic actions you declare using the router, it sends `Message::Routed`. On the other hand, it sends any `RatatuiRuby::Event` that is not handled by the router directly.

### Semantic Actions: `Message::Routed`

When an action targets a child fragment:

```ruby
Message::Routed.new(
  envelope: :move_down,  # Semantic intent
  event: key_event       # Original event (for context)
)
```

Children pattern match on the envelope:

```ruby
case message
in { type: :routed, envelope: :move_down }
  model.with(index: model.index + 1)
end

# Or use predicates:
if message.move_down?
  model.with(index: model.index + 1)
end
```

### Raw Events: Pass-Through

For events that don't need semantic wrapping (like resize), the Router passes the raw event directly to children. The child sees `{ type: :resize, width: 80, height: 24 }` — no wrapping.

---

## Command Response Routing

When a child returns a command, the Router tags it with route information. When the response arrives, it carries a `route:` field:

```ruby
# Response arrives with routing info
{ type: :system, route: [:files], stdout: "...", status: 0 }
```

The Router:
1. Checks the `route:` field → `[:files]`
2. Peels the first element → dispatches to FileList
3. Passes the response (without the route layer) to the child
4. Merges the child's new model back into the parent

This happens automatically. Children return raw commands and receive raw responses.

---

## Nested Routing

Deep hierarchies work automatically:

```
Root (Router) → Tab (Router) → Panel (Router) → Leaf
```

When Leaf returns a command, each Router adds its prefix to the route path:
- Panel adds `:leaf` → `route: [:leaf]`
- Tab adds `:panel` → `route: [:panel, :leaf]`
- Root adds `:tab` → `route: [:tab, :panel, :leaf]`

When the response arrives, each Router peels its layer and dispatches down:
1. Root sees `route: [:tab, ...]` → dispatches to Tab
2. Tab sees `route: [:panel, ...]` → dispatches to Panel
3. Panel sees `route: [:leaf]` → dispatches to Leaf
4. Leaf receives the raw response

Each Router only knows its direct children. The `route:` array handles arbitrary depth.

---

## Delegation: Forward Unhandled Messages

Forward unhandled messages to an active child:

```ruby
module TabContainer
  include Rooibos::Router

  route :tab1, to: Tab1
  route :tab2, to: Tab2

  delegate_unhandled_to: -> (model) { model.active_tab }

  keymap do
    key :ctrl_1, action: :switch_tab1
    key :ctrl_2, action: :switch_tab2
  end
end
```

The Router checks its keymap first. If no match, it calls `delegate_unhandled_to`, gets the active child prefix, and forwards the raw message. The parent doesn't list every key the child handles.

---

## Broadcasting: Send to All Children

Send certain messages to all children:

```ruby
module Dashboard
  include Rooibos::Router

  route :panel1, to: Panel1
  route :panel2, to: Panel2
  route :panel3, to: Panel3

  broadcast :resize  # Send resize events to ALL children
end
```

When a resize event arrives, the Router:
1. Calls every child Update with the message
2. Collects new child models
3. Batches any returned commands
4. Returns the fully updated parent model

Use this for cross-cutting concerns like window resize, theme changes, or tick events.

---

## Cross-Cutting Concerns

The Router provides hooks for logging, analytics, and other concerns:

```ruby
module App
  include Rooibos::Router

  # Log all dispatched messages
  before_dispatch do |message, target|
    Logger.info "Dispatching #{message.class} to #{target}"
  end

  # Track analytics
  after_dispatch do |message, target, result|
    Analytics.track("message_handled", target: target)
  end
end
```

Handle concerns centrally instead of scattering them across child Updates.

---

## Hybrid Updates

Sometimes a fragment needs both Router dispatch and custom logic:

```ruby
module Tab
  include Rooibos::Router

  route :inner, to: InnerFragment

  Update = -> (message, model) do
    # Handle Tab-specific messages first
    case message
    in { type: :routed, envelope: :activate }
      return model.with(active: true)
    in { type: :routed, envelope: :deactivate }
      return model.with(active: false)
    end

    # Fall through to Router for child dispatch
    Tab.from_router.call(message, model)
  end
end
```

The custom Update handles specific cases, then delegates to the Router for everything else.

---

## Debugging

Enable Router logging to trace message flow:

```ruby
module App
  include Rooibos::Router

  router_options debug: true
end
```

This prints:
- Which keys matched which actions
- Which child received each message
- How commands were routed
- How responses were unwrapped

---

## Summary

The Router DSL handles message routing automatically:

- **`route :name, to: Fragment`** — Declare child fragment locations
- **`action name: Fragment, keys: [...]`** — Map keys to semantic actions
- **`Update = from_router`** — Generate dispatch logic
- **`Message::Routed`** — Semantic actions with envelope predicates
- **`route:` field** — Command responses find their way back
- **`delegate_unhandled_to`** — Forward to active child
- **`broadcast`** — Send to all children
- **`before_dispatch` / `after_dispatch`** — Cross-cutting concerns

Children stay independent. Parents stay simple. The Router handles the complexity.

---

Related: [Fractal Architecture](./fractal_architecture.md) | [Commands](../essentials/commands.md) | [Messages](../essentials/messages.md)

---

[**Previous:** Fractal Architecture](./fractal_architecture.md) | [**Next:** Reusable Fragments](./reusable_fragments.md)
