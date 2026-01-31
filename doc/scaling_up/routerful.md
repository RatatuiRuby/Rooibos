<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Router-Based Composition Patterns

After reading this guide, you will know:

- How to use the Router DSL to coordinate messages between fragments
- When to use `Rooibos::Command.bubble` vs `Rooibos::Command.deliver` for outward communication
- How `keymap`, `forward`, and `route` work together
- When plain Update lambdas suffice and when you need Router

---

## Context

You've followed [Simple Apps Don't Need Fragments](fragmentless.md). One module. One Model, one Update, one View. That worked while your app was small.

This guide uses a 7-fragment dashboard:

```
Root
├── Left Panel
│   ├── Left Top
│   └── Left Bottom
└── Right Panel
    ├── Right Top
    └── Right Bottom
```

## Problem

Your app has grown. Your Update function handles too many cases. Your Model has dozens of fields. Your View is hundreds of lines. One module is no longer enough.

## Solution

Decompose into fragments. A fragment is a module with its own Init, Update, and View. Your application is already one fragment, but it can be decomposed into nested fragments. Outer fragments' models contain their nested fragments' models. The root's model includes the panel's models. The panel's models contain the leaf's models.

Messages flow in two directions. 

Inward
: Keyboard events arrive at Root and need to reach the right nested fragment. 

Outward
: Nested fragments signal completion, errors, or state changes to their outer fragments or to Root.

The Router DSL coordinates this flow declaratively. Include `Rooibos::Router` in your fragment and use these constructs:

### Routes

**`route`** declares nested fragments. An optional first argument is a symbol naming the model attribute:

```ruby
route :sidebar, to: Sidebar
route :file_list, to: FileList
```

For custom extraction logic (e.g., deeply nested paths), use `read:` and `write:` keywords:

```ruby
# Custom accessor for nested path
route read: ->(model) { model.panels[:sidebar] },
      write: ->(current_model, value) { current_model.with(panels: current_model.panels.merge(sidebar: value)) },
      to: Sidebar

# Deeply nested extraction
route read: ->(model) { model.tabs[model.active_tab] },
      write: ->(current_model, value) { current_model.with(tabs: current_model.tabs.merge(current_model.active_tab => value)) },
      to: TabContent
```

The generated Update routes messages to nested fragments automatically.

### Actions

**`action`** defines reusable handlers. Actions can be lambdas or routed to fragments:

```ruby
# Lambda action
action :quit, -> { Rooibos::Command.exit }
action scroll_up: -> { [:scroll, -1] }

# Routed action — dispatches Message::Routed to fragment
action go_back: HistoryPanel
action :show_details, InfoPanel
```

You can bind keys or mouse events inline when defining an action. Without bindings, the action is named for later use in `keymap` or `mousemap` blocks:

```ruby
action scroll_up: -> { [:scroll, -1] }, keymap: %i[up k]
action quit: -> { Rooibos::Command.exit }, key: :q
action scroll_handler: -> { ... }, mousemap: [:scroll_up]

# Anonymous action — inline handler with binding, no name needed
action -> { Rooibos::Command.exit }, key: :ctrl_c
```


### Keymap

**`keymap`** maps RatatuiRuby::Event::Key messages to commands or actions.

```ruby
keymap do |map|
  # Handler or action name
  map.key :q, -> { Rooibos::Command.exit }
  map.key :up, :scroll_up

  # Multiple keys to one action
  map.keys :down, :j, action: :move_down

  # Hash syntax for metaprogramming
  exit_bindings = { q: :quit, ctrl_c: :quit }
  map.key(exit_bindings)

  # Guards control when handlers run
  map.key "x", -> { ... }, when: -> (model) { model.editable? }
  map.key "d", -> { ... }, unless: -> (model) { model.locked? }

  # Scoped guard blocks reduce repetition
  map.only when: -> (model) { model.focused? } do
    map.key "j", :move_down
    map.key "k", :move_up
  end
  map.skip if: -> (model) { model.modal_open? } do
    map.key "q", :quit
  end
end
```

Choose a guard alias to match your semantics: `when:`, `if:`, `only:`, `guard:` (positive); `unless:`, `except:`, `skip:` (negative).

### Mousemap

**`mousemap`** maps `RatatuiRuby::Event::Mouse` messages to commands or actions. Like `keymap`, it supports action references, guards, and scoped guard blocks:

```ruby
mousemap do |map|
  map.scroll :up, :scroll_up_action
  map.scroll :down, -> { [:scroll, 1] }
  map.click -> (x, y) { [:clicked, x, y] }
end
```

### Forward

**`forward`** routes incoming messages by type. It complements `keymap` (keyboard events) and `mousemap` (mouse events):

```ruby
forward do |messages|
  # Broadcast resize events to specific nested fragments
  messages.with_type :resize, broadcast_to: [:file_list, :sidebar]

  # Or broadcast to all declared routes
  messages.with_type :theme_changed, broadcast: true

  # Route by message type to an action
  messages.with_type :leaf_reset, action: :increment_resets

  # Route by envelope to a specific fragment
  messages.with_envelope :file_list, route_to: FileList
end
```

### Local Message Handling

**`observe`** and **`intercept`** handle messages before they reach `keymap`, `forward`, or `otherwise`. Both take a predicate and a handler callable.

**`observe`** processes a message, updates model, emits commands, then lets the message continue:

```ruby
observe ->(message) { message.logging_target? },
        ->(message, model) { [model.with(logged: model.logged + 1), Rooibos::Command.custom(Logger.new(...))] }
```

The runtime runs the handler, applies the model update, collects the command, then continues processing. All matching `observe` handlers run in declaration order, each receiving the model updated by previous handlers.

**`intercept`** handles a message and stops processing — the message never reaches later handlers:

```ruby
intercept ->(message) { message.fatal_error? },
          ->(message, model) { [model.with(error: message), Rooibos::Command.exit] }
```

Keyword arguments are supported for fluent code.

```ruby
# if: and when: can be used instead of two positional arguments
observe ->(message, model) { Rooibos::Command.custom(Logger.new(...)) }, if: ->(message) { message.logging_target? }
intercept ->(message, model) { [model.with(error: message), Rooibos::Command.exit] }, when: ->(message) { message.fatal_error? }

# unless: and except: will invert your predicate
observe ->(message, model) { something_happened(message, model) }, unless: ->(message) { message.nil? or message.none? }
intercept ->(message, model) { nil }, except: ->(message) { message.rooibos_command? }

# then: can be combined with predicate keyword arguments instead of any positional arguments
observe if: ->(message) { message.key? },
        then: ->(message, model) { model.with(keypresses: model.keypresses + 1) }
intercept if: ->(message) { message.mouse? },
          then: ->(message, model) { model.with(mouse_events_blocked: model.mouse_events_blocked + 1) }
```

Use `observe_all` and `intercept_all` (arity 1) to match all messages:

```ruby
# Log every message
observe_all ->(message, model) { [model.with(seen: model.seen + 1), nil] }

# Catch-all intercept (stops all processing)
intercept_all ->(message, model) { [model, nil] }
```

### Otherwise

**`otherwise`** is a router-level fallback. It catches any message not handled by `keymap`, `mousemap`, `forward`, or `action`.

This is useful when an outer fragment doesn't need to know everything its nested fragments handle. A tab container, for example, might only care which tab is active — not what each tab does with keyboard events. The active tab handles its own messages; the container just routes them.

```ruby
keymap do |map|
  map.key :tab, :next_tab
  map.only when: -> (model) { model.focused? } do
    map.key :k, :move_up
  end
end

forward do |messages|
  messages.with_type :resize, broadcast: true
end

# Everything not handled above goes to the active tab
otherwise route_to: :active_tab

Update = from_router
```

The semantics are precise:

- `:tab` is handled by keymap. Never falls through.
- `:k` when `model.focused?` is true → handled by keymap.
- `:k` when `model.focused?` is false → guard fails, falls through to `otherwise`.
- `:resize` is handled by forward. Never falls through.
- Any other message → `otherwise` routes it to `:active_tab`.

This keeps the outer fragment's router minimal. It declares what it handles; everything else flows to the nested fragment.

#### Deep Hierarchies

For deeply nested fragments, use `otherwise` at each level. Messages flow inward until something handles them:

```ruby
# Root
keymap do |map|
  map.key :tab, :switch_tab
end
otherwise route_to: :active_tab
```

```ruby
# Tab fragment
keymap do |map|
  map.key :enter, :submit_form
end
otherwise route_to: :active_panel
```

```ruby
# Panel fragment
keymap do |map|
  map.key :space, :toggle
end
otherwise route_to: :active_field
```

```ruby
# Field fragment — handles everything that made it this far
keymap do |map|
  map.key :backspace, :delete_char
end

# Catch-all for character insertion
observe ->(msg) { msg.key? }, ->(msg, model) { insert_char(msg, model) }
# No otherwise — this is the leaf
```

Each level declares one line: `otherwise route_to: :child`. For 15 levels, that's 15 one-liners across the whole app — not 15 levels of explicit per-message routing.

This is declarative message drilling. The Router automates the forwarding you'd otherwise write manually. You don't need event buses, and there are no hidden dependencies. Fragments declare "I don't handle this, pass it down," and the Router does so.

### Message Processing Order

Handlers run in declaration order:

1. All matching `observe` handlers run first (model and commands accumulate)
2. First matching `intercept` stops processing; later intercepts don't run
3. If no intercept matched: `keymap` → `mousemap` → `forward` → `otherwise`

### Generating Update

**`from_router`** generates the Update lambda:

```ruby
Update = from_router
```

The generated Update:
1. Routes prefixed messages to nested fragments
2. Handles keyboard events via keymap
3. Handles mouse events via mousemap
4. Returns model unchanged for unhandled messages

### Outward Communication

Nested fragments send data outward using commands:

**`Rooibos::Command.bubble(message)`** sends a message outward through the fragment hierarchy. Each outer fragment gets a chance to handle it — update their state, modify it, or let it continue. Use bubble when intermediate fragments need to react.

**`Rooibos::Command.deliver(message)`** sends a message directly to Root. Intermediate fragments never see it. Use deliver for fire-and-forget signals.

Define outward message types with `Rooibos::Message::Predicates` and an `envelope` attribute.

```ruby
class LeafReset < Data.define(:envelope, :count)
  include Rooibos::Message::Predicates
end

class PanelReset < Data.define(:envelope, :count)
  include Rooibos::Message::Predicates
end
```

Custom messages enable type checks like `message.leaf_reset?`. Use them in `forward` blocks or manual Update functions:

```ruby
# In a nested fragment's Update
if new_count >= 10
  message = LeafReset.new(envelope: model.name.to_sym, count: new_count)
  [model.with(count: 0), Rooibos::Command.deliver(message)]
else
  model.with(count: new_count)
end
```

```ruby
# In an outer fragment's forward block
forward do |messages|
  messages.with_type :leaf_reset do |model, message|
    model.with(resets: model.resets + 1)
  end
end
```

#### Semantic Transformation (Intercept + Re-bubble)

When a bubbled message needs transformation before continuing, intercept it and re-bubble a new message:

```ruby
# Panel intercepts LeafReset, transforms to PanelChildReset, and re-bubbles
intercept ->(msg) { msg.leaf_reset? },
          ->(msg, model) {
            transformed = PanelChildReset.new(envelope: model.name, leaf: msg.envelope, count: msg.count)
            [model.with(nested_resets: model.nested_resets + 1), Rooibos::Command.bubble(transformed)]
          }
```

This pattern lets intermediate fragments add context or aggregate information while preserving the outward flow.

#### Bubble with Commands

Sometimes a fragment signals outward AND starts async work. Use `Command.batch` to do both:

```ruby
# User clicks "Download"
if message.download?
  [model.with(downloading: true),
   Rooibos::Command.batch(
     Rooibos::Command.bubble(DownloadStarted.new(filename: model.selected_file)),
     Rooibos::Command.http(download_url, :get)
   )]
end
```

Two things happen:

1. **The bubble** propagates outward. Each outer fragment in the hierarchy gets a chance to `observe` or `intercept` it — from the immediate outer fragment all the way to Root.
2. **The HTTP result** arrives at Root as a message. Use `forward` to route it inward to the fragment that needs it, or handle it directly at Root.

An outer fragment (perhaps several levels up) can observe the bubble:

```ruby
observe -> (msg) { msg.download_started? },
        -> (msg, model) { model.with(status: "Downloading #{msg.filename}...") }
```

---

## Complete Example: Seven Counters

This example demonstrates all Router features with a 7-fragment dashboard:

```
Root
├── Left Panel
│   ├── Left Top
│   └── Left Bottom
└── Right Panel
    ├── Right Top
    └── Right Bottom
```

Each fragment has a counter. Leaves signal outward at two thresholds:
- **Count hits 5:** Deliver `Milestone` to Root (Panel doesn't see it)
- **Count hits 10:** Bubble `LeafReset` (Panel observes, then Root intercepts)

### Message Types

```ruby
class Milestone < Data.define(:envelope, :count)
  include Rooibos::Message::Predicates
end

class LeafReset < Data.define(:envelope, :count)
  include Rooibos::Message::Predicates
end

class PanelReset < Data.define(:envelope, :count)
  include Rooibos::Message::Predicates
end
```

### Leaf Fragment

Leaves have no nested fragments. Plain Update lambda, no Router needed:

```ruby
module Leaf
  Model = Data.define(:name, :count)

  Init = ->(name:) {
    Ractor.make_shareable Model.new(name:, count: 0)
  }

  View = ->(model, tui) {
    tui.block(title: "#{model.name} [#{model.count}]", borders: [:all])
  }

  Update = ->(message, model) {
    return unless message.routed?

    count = model.count + 1
    case count
    when 5
      # Deliver milestone directly to Root (Panel doesn't see it)
      [model.with(count:), Rooibos::Command.deliver(Milestone.new(envelope: model.name, count:))]
    when 10
      # Bubble reset through Panel (Panel observes, Root intercepts)
      [model.with(count: 0), Rooibos::Command.bubble(LeafReset.new(envelope: model.name, count:))]
    else
      model.with(count:)
    end
  }
end
```

### Panel Fragment (with Router)

Panel routes to its leaves, intercepts increment for self, observes bubbled resets:

```ruby
module Panel
  include Rooibos::Router

  Model = Data.define(:top_leaf, :bottom_leaf, :name, :count, :nested_resets)

  Init = ->(name:, top_leaf_name:, bottom_leaf_name:) {
    Ractor.make_shareable Model.new(
      top_leaf: Leaf::Init[name: top_leaf_name],
      bottom_leaf: Leaf::Init[name: bottom_leaf_name],
      name:, count: 0, nested_resets: 0
    )
  }

  View = ->(model, tui) {
    tui.block(
      title: "#{model.name} [#{model.count}] (nested: #{model.nested_resets})",
      borders: [:all],
      children: [
        tui.layout(
          direction: :vertical,
          constraints: [tui.constraint_percentage(50), tui.constraint_percentage(50)],
          children: [Leaf::View[model.top_leaf, tui], Leaf::View[model.bottom_leaf, tui]]
        )
      ]
    )
  }

  route :top_leaf, to: Leaf
  route :bottom_leaf, to: Leaf

  # Increment self when routed message targets us
  intercept ->(message) { message.panel? },
            ->(_, model) {
              count = model.count + 1
              case count
              when 5
                [model.with(count:), Rooibos::Command.deliver(Milestone.new(envelope: model.name, count:))]
              when 10
                [model.with(count: 0), Rooibos::Command.bubble(PanelReset.new(envelope: model.name, count:))]
              else
                model.with(count:)
              end
            }

  # Observe bubbled resets from leaves
  observe ->(message) { message.leaf_reset? },
          ->(_, model) { model.with(nested_resets: model.nested_resets + 1) }

  # Route by envelope to the correct leaf
  forward do |messages|
    messages.with_envelope :top_leaf, route_to: :top_leaf
    messages.with_envelope :bottom_leaf, route_to: :bottom_leaf
  end

  Update = from_router
end
```

### Root Fragment (with Router)

Root intercepts its own increment, routes to panels and leaves:

```ruby
module Root
  include Rooibos::Router

  Model = Data.define(:left_panel, :right_panel, :count, :total_resets, :milestones)

  Init = -> {
    Ractor.make_shareable Model.new(
      left_panel: Panel::Init[name: "Left Panel", top_leaf_name: "Left Top", bottom_leaf_name: "Left Bottom"],
      right_panel: Panel::Init[name: "Right Panel", top_leaf_name: "Right Top", bottom_leaf_name: "Right Bottom"],
      count: 0, total_resets: 0, milestones: 0
    )
  }

  View = ->(model, tui) {
    tui.block(
      title: "Root [#{model.count}] (resets: #{model.total_resets}, milestones: #{model.milestones})",
      borders: [:all],
      children: [
        tui.layout(
          direction: :horizontal,
          constraints: [tui.constraint_percentage(50), tui.constraint_percentage(50)],
          children: [Panel::View[model.left_panel, tui], Panel::View[model.right_panel, tui]]
        )
      ]
    )
  }

  route :left_panel, to: Panel
  route :right_panel, to: Panel

  keymap do |map|
    map.key :ctrl_c, -> { Rooibos::Command.exit }
    map.key "a", :panel, route: :left_panel
    map.key "b", :panel, route: :right_panel
    map.key "1", :top_leaf, route: :left_panel
    map.key "2", :bottom_leaf, route: :left_panel
    map.key "3", :top_leaf, route: :right_panel
    map.key "4", :bottom_leaf, route: :right_panel
  end

  # Root increments itself
  intercept ->(message) { message.enter? },
            ->(_, model) {
              count = model.count + 1
              case count
              when 5
                model.with(count:, milestones: model.milestones + 1)
              when 10
                model.with(count: 0, total_resets: model.total_resets + 1)
              else
                model.with(count:)
              end
            }

  # Track resets bubbled from leaves and panels
  observe ->(message) { message.leaf_reset? || message.panel_reset? },
          ->(_, model) { model.with(total_resets: model.total_resets + 1) }

  # Track milestones delivered from leaves and panels
  observe ->(message) { message.milestone? },
          ->(_, model) { model.with(milestones: model.milestones + 1) }

  Update = from_router
end
```

### How It Works

**Inward routing of messages:**
- `Enter` → Root's intercept matches `message.enter?` → handles directly (Root's own counter)
- `a` → Root routes `:panel` to `:left_panel` → Panel's intercept handles it (Panel's own counter)
- `1` → Root routes `:top_leaf` to `:left_panel` → Panel's forward matches `with_envelope :top_leaf` → Leaf handles it

**Outward messaging (bubble):**
- Leaf reaches 10 → `Rooibos::Command.bubble(LeafReset)` → Router propagates outward → Panel's `observe` sees it (increments `nested_resets`), Router continues → Root's `observe` sees it (increments `total_resets`)

**Outward messaging (deliver):**
- Leaf reaches 5 → `Rooibos::Command.deliver(Milestone)` → goes directly to Root (Panel never sees it) → Root's `observe` handles it (increments `milestones`)

**The difference:** Bubble flows through each fragment. Deliver skips straight to Root.

**observe vs intercept:**
- `observe` = take action, and:
  - if bubbling, Router continues propogating outward
  - otherwise, your keymaps, actions, and other config may exist to continue propagating inward
- `intercept` = handle and stop, Router does NOT continue

Panel uses `observe` for bubbled messages so they continue to Root. Panel uses `intercept` for `:panel` so the message stops there.
---

## See Also

- [Simple Apps Don't Need Fragments](fragmentless.md) — Start here for simple apps
- [Routerless Composition](routerless.md) — Manual composition without Router
- [Fractal Architecture](fractal_architecture.md) — When and why to decompose
