<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Routerless Composition Patterns

After reading this guide, you will know:

- Five different patterns for communication between nested and outer fragments
- How to choose the pattern that fits your brain
- How each pattern handles data flow in both directions
- Trade-offs between simplicity, coupling, and ceremony

---

## Philosophy

> "Pick the paradigm that fits your brain. You can't choose wrong."

The Router DSL is optional. Rooibos's core is just `(message, model) -> { [model, command] }`. Everything else is layered on top. If you prefer explicit control, these patterns give you full power over fragment composition.

Each pattern below uses the **same example app** — a dashboard with 7 fragments:

```
Root
├── PanelA
│   ├── Leaf1
│   └── Leaf2
└── PanelB
    ├── Leaf3
    └── Leaf4
```

We'll show **data flowing both directions**:
- **Inward**: Outer fragment passes messages/data to nested fragments
- **Outward**: Nested fragments communicate events back to outer fragments

---

## The Example App: Seven Counters

Each of the 7 fragments has its own counter. Keyboard events arrive at Root's Update, which dispatches them inward to the appropriate fragment. When any nested counter reaches 10, the outer fragment reacts by resetting it and incrementing its own reset tracker.

**Keyboard mapping:**
- `Enter` → Root's counter
- `a` → PanelA's counter
- `b` → PanelB's counter
- `1` → Leaf1's counter (under PanelA)
- `2` → Leaf2's counter (under PanelA)
- `3` → Leaf3's counter (under PanelB)
- `4` → Leaf4's counter (under PanelB)

```ruby
# Shared structures (used by all patterns)
module Leaf
  Model = Data.define(:name, :count)
  Init = -> (name:) { Model.new(name:, count: 0) }

  View = -> (model, _tui) {
    RatatuiRuby::Widgets::Block.new(
      title: "#{model.name} [#{model.count}]",
      borders: [:all]
    )
  }
end

module Panel
  Model = Data.define(:leaf1, :leaf2, :name, :count, :nested_resets)
  Init = -> (name:, leaf1_name:, leaf2_name:) {
    Model.new(
      leaf1: Leaf::Init.(name: leaf1_name),
      leaf2: Leaf::Init.(name: leaf2_name),
      name: name,
      count: 0,
      nested_resets: 0
    )
  }

  View = -> (model, tui) {
    RatatuiRuby::Widgets::Block.new(
      title: "#{model.name} [#{model.count}] (resets: #{model.nested_resets})",
      borders: [:all],
      children: [
        RatatuiRuby::Layout::Layout.new(
          direction: :horizontal,
          constraints: [
            RatatuiRuby::Layout::Constraint.percentage(50),
            RatatuiRuby::Layout::Constraint.percentage(50)
          ],
          children: [
            Leaf::View.(model.leaf1, tui),
            Leaf::View.(model.leaf2, tui)
          ]
        )
      ]
    )
  }
end

module Root
  Model = Data.define(:panel_a, :panel_b, :count, :total_resets)
  Init = -> {
    Model.new(
      panel_a: Panel::Init.(name: "Panel A", leaf1_name: "Leaf 1", leaf2_name: "Leaf 2"),
      panel_b: Panel::Init.(name: "Panel B", leaf1_name: "Leaf 3", leaf2_name: "Leaf 4"),
      count: 0,
      total_resets: 0
    )
  }

  View = -> (model, tui) {
    RatatuiRuby::Widgets::Block.new(
      title: "Root [#{model.count}] (total resets: #{model.total_resets})",
      borders: [:all],
      children: [
        RatatuiRuby::Layout::Layout.new(
          direction: :horizontal,
          constraints: [
            RatatuiRuby::Layout::Constraint.percentage(50),
            RatatuiRuby::Layout::Constraint.percentage(50)
          ],
          children: [
            Panel::View.(model.panel_a, tui),
            Panel::View.(model.panel_b, tui)
          ]
        )
      ]
    )
  }
end
```

**The key insight**: All keyboard events arrive at `Root::Update`. Root decides where to dispatch them:
- `Enter` → Root handles directly
- `a`, `1`, `2` → Root wraps and dispatches to PanelA
- `b`, `3`, `4` → Root wraps and dispatches to PanelB
- PanelA/B then dispatch `1`/`2` or `3`/`4` to their nested Leafs


---

## Pattern 1: Extended Tuple Return (OutwardMessage)

Nested Update returns a 3-tuple: `[model, command, outward_message]`. Outer fragment destructures and handles the third element.

**Inspiration**: Elm, Elmish (F#)

### Leaf

```ruby
module Leaf
  Model = Data.define(:count)

  module OutwardMessage
    Reached10 = Data.define
    None = Data.define
  end

  # Leaf receives :increment from outer fragment, not raw keyboard events
  Update = -> (message, model) {
    if message == :increment
      new_count = model.count + 1
      if new_count >= 10
        [Model.new(count: 0), nil, OutwardMessage::Reached10.new]
      else
        [model.with(count: new_count), nil, OutwardMessage::None.new]
      end
    else
      [model, nil, OutwardMessage::None.new]
    end
  }
end
```

### Panel

```ruby
module Panel
  Model = Data.define(:leaf1, :leaf2, :name, :count, :nested_resets)

  module OutwardMessage
    SelfReset = Data.define(:panel_name)
    LeafReset = Data.define(:leaf_name)
    None = Data.define
  end

  # Panel receives wrapped messages from Root
  Update = -> (message, model) {
    case message
    # Panel's own counter (key 'a' or 'b' from Root)
    in :increment
      new_count = model.count + 1
      if new_count >= 10
        [model.with(count: 0), nil, OutwardMessage::SelfReset.new(panel_name: model.name)]
      else
        [model.with(count: new_count), nil, OutwardMessage::None.new]
      end

    # Dispatch to Leaf1 (key '1' or '3' from Root)
    in [:leaf1, nested_message]
      new_leaf, cmd, outward_message = Leaf::Update.call(nested_message, model.leaf1)
      new_model = model.with(leaf1: new_leaf)

      case outward_message
      in Leaf::OutwardMessage::Reached10
        new_model = new_model.with(nested_resets: model.nested_resets + 1)
        [new_model, cmd, OutwardMessage::LeafReset.new(leaf_name: "#{model.name}/Leaf1")]
      else
        [new_model, cmd, OutwardMessage::None.new]
      end

    # Dispatch to Leaf2 (key '2' or '4' from Root)
    in [:leaf2, nested_message]
      new_leaf, cmd, outward_message = Leaf::Update.call(nested_message, model.leaf2)
      new_model = model.with(leaf2: new_leaf)

      case outward_message
      in Leaf::OutwardMessage::Reached10
        new_model = new_model.with(nested_resets: model.nested_resets + 1)
        [new_model, cmd, OutwardMessage::LeafReset.new(leaf_name: "#{model.name}/Leaf2")]
      else
        [new_model, cmd, OutwardMessage::None.new]
      end

    else
      [model, nil, OutwardMessage::None.new]
    end
  }
end
```

### Root

```ruby
module Root
  Model = Data.define(:panel_a, :panel_b, :count, :total_resets)

  # Root receives ALL keyboard events from the runtime
  Update = -> (message, model) {
    if message.enter?
      # Root's own counter
      new_count = model.count + 1
      if new_count >= 10
        # Root counts its own reset
        [model.with(count: 0, total_resets: model.total_resets + 1), nil]
      else
        [model.with(count: new_count), nil]
      end
    elsif message.a?
      dispatch_to_panel(:panel_a, :increment, model)
    elsif message.b?
      dispatch_to_panel(:panel_b, :increment, model)
    elsif message.one?
      dispatch_to_panel(:panel_a, [:leaf1, :increment], model)
    elsif message.two?
      dispatch_to_panel(:panel_a, [:leaf2, :increment], model)
    elsif message.three?
      dispatch_to_panel(:panel_b, [:leaf1, :increment], model)
    elsif message.four?
      dispatch_to_panel(:panel_b, [:leaf2, :increment], model)
    elsif message.ctrl_c? || message.q?
      Rooibos::Command.exit
    else
      [model, nil]
    end
  }

  def self.dispatch_to_panel(panel_key, nested_message, model)
    panel_model = model.public_send(panel_key)
    new_panel, cmd, outward_message = Panel::Update.call(nested_message, panel_model)
    new_model = model.with(panel_key => new_panel)

    case outward_message
    in Panel::OutwardMessage::SelfReset(panel_name:)
      puts "Panel reset: #{panel_name}"
      [new_model.with(total_resets: model.total_resets + 1), cmd]
    in Panel::OutwardMessage::LeafReset(leaf_name:)
      puts "Leaf reset: #{leaf_name}"
      [new_model.with(total_resets: model.total_resets + 1), cmd]
    else
      [new_model, cmd]
    end
  end
end
```

### Data Flow

```
Inward: User presses '1'
        → Runtime delivers keyboard message to Root::Update
        → Root matches message.one?, calls dispatch_to_panel(:panel_a, [:leaf1, :increment], model)
        → Panel::Update receives [:leaf1, :increment], calls Leaf::Update.call(:increment, ...)
        → Leaf::Update receives :increment, increments counter

Outward: Leaf returns [model, nil, OutwardMessage::Reached10]
         → Panel inspects outward_message, increments nested_resets
         → Panel returns [model, nil, OutwardMessage::LeafReset]
         → Root inspects outward_message, increments total_resets

```

### Trade-offs

| Pros | Cons |
|------|------|
| Explicit communication contract | Signature differs from standard `[model, cmd]` |
| Type-safe OutwardMessage (Data.define) | Every level must handle/propagate OutwardMessage |
| Reusable nested fragments | More ceremony |

---

## Pattern 2: Action Enum Return

Nested Update returns an Action object instead of a tuple. Outer fragment pattern matches on actions.

**Inspiration**: Iced (Rust), Ratatui

### Leaf

```ruby
module Leaf
  Model = Data.define(:count)

  module Action
    Updated = Data.define(:model, :command)
    Reached10 = Data.define(:model, :command)
  end

  Update = -> (message, model) {
    if message == :increment
      new_count = model.count + 1
      if new_count >= 10
        Action::Reached10.new(model: Model.new(count: 0), command: nil)
      else
        Action::Updated.new(model: model.with(count: new_count), command: nil)
      end
    else
      Action::Updated.new(model: model, command: nil)
    end
  }
end
```

### Panel

```ruby
module Panel
  Model = Data.define(:leaf1, :leaf2, :name, :count, :nested_resets)

  module Action
    Updated = Data.define(:model, :command)
    SelfReset = Data.define(:model, :command, :panel_name)
    LeafReset = Data.define(:model, :command, :leaf_name)
  end

  Update = -> (message, model) {
    case message
    # Panel's own counter
    in :increment
      new_count = model.count + 1
      if new_count >= 10
        new_model = model.with(count: 0)
        Action::SelfReset.new(model: new_model, command: nil, panel_name: model.name)
      else
        new_model = model.with(count: new_count)
        Action::Updated.new(model: new_model, command: nil)
      end

    # Dispatch to Leaf1
    in [:leaf1, nested_message]
      action = Leaf::Update.call(nested_message, model.leaf1)
      new_model = model.with(leaf1: action.model)

      case action
      in Leaf::Action::Reached10
        new_model = new_model.with(nested_resets: model.nested_resets + 1)
        Action::LeafReset.new(
          model: new_model,
          command: action.command,
          leaf_name: "#{model.name}/Leaf1"
        )
      else
        Action::Updated.new(model: new_model, command: action.command)
      end

    # Dispatch to Leaf2
    in [:leaf2, nested_message]
      action = Leaf::Update.call(nested_message, model.leaf2)
      new_model = model.with(leaf2: action.model)

      case action
      in Leaf::Action::Reached10
        new_model = new_model.with(nested_resets: model.nested_resets + 1)
        Action::LeafReset.new(
          model: new_model,
          command: action.command,
          leaf_name: "#{model.name}/Leaf2"
        )
      else
        Action::Updated.new(model: new_model, command: action.command)
      end

    else
      Action::Updated.new(model: model, command: nil)
    end
  }
end
```

### Root

```ruby
module Root
  Model = Data.define(:panel_a, :panel_b, :count, :total_resets)

  # Root receives ALL keyboard events from the runtime
  Update = -> (message, model) {
    if message.enter?
      # Root's own counter
      new_count = model.count + 1
      if new_count >= 10
        # Root counts its own reset
        [model.with(count: 0, total_resets: model.total_resets + 1), nil]
      else
        [model.with(count: new_count), nil]
      end
    elsif message.a?
      dispatch_to_panel(:panel_a, :increment, model)
    elsif message.b?
      dispatch_to_panel(:panel_b, :increment, model)
    elsif message.one?
      dispatch_to_panel(:panel_a, [:leaf1, :increment], model)
    elsif message.two?
      dispatch_to_panel(:panel_a, [:leaf2, :increment], model)
    elsif message.three?
      dispatch_to_panel(:panel_b, [:leaf1, :increment], model)
    elsif message.four?
      dispatch_to_panel(:panel_b, [:leaf2, :increment], model)
    elsif message.ctrl_c? || message.q?
      Rooibos::Command.exit
    else
      [model, nil]
    end
  }

  def self.dispatch_to_panel(panel_key, nested_message, model)
    panel_model = model.public_send(panel_key)
    action = Panel::Update.call(nested_message, panel_model)
    new_model = model.with(panel_key => action.model)

    case action
    in Panel::Action::SelfReset(panel_name:)
      puts "Panel reset: #{panel_name}"
      [new_model.with(total_resets: model.total_resets + 1), action.command]
    in Panel::Action::LeafReset(leaf_name:)
      puts "Leaf reset: #{leaf_name}"
      [new_model.with(total_resets: model.total_resets + 1), action.command]
    else
      [new_model, action.command]
    end
  end
end
```

### Trade-offs

| Pros | Cons |
|------|------|
| Rich action semantics | Actions bundle model+cmd, can feel heavy |
| Pattern matching is expressive | Every action variant needs model field |
| Self-documenting action types | Different return type than Rooibos standard |

---

## Pattern 3: Command-Based Message Dispatch

Nested returns a command that produces a message. Runtime dispatches message to Root asynchronously.

**Inspiration**: Bubble Tea (Go)

### Message Types for Outward Messages

Define structured Message classes following the blessed pattern:

```ruby
# Message when a leaf fragment resets
class LeafReset < Data.define(:envelope, :count)
  include Rooibos::Message::Predicates
end

# Message when a panel resets
class PanelReset < Data.define(:envelope, :count)
  include Rooibos::Message::Predicates
end
```

Rooibos ships `Command.deliver(message)` for exactly this purpose.

### Leaf

```ruby
module Leaf
  Model = Data.define(:count, :name)

  Update = -> (message, model) {
    if message == :increment
      new_count = model.count + 1
      if new_count >= 10
        # Return a command that delivers a LeafReset message to Root
        reset_msg = LeafReset.new(envelope: model.name.to_sym, count: new_count)
        [Model.new(count: 0, name: model.name), Command.deliver(reset_msg)]
      else
        [model.with(count: new_count), nil]
      end
    else
      [model, nil]
    end
  }
end
```

### Panel

```ruby
module Panel
  Model = Data.define(:leaf1, :leaf2, :name, :count)

  Update = -> (message, model) {
    case message
    # Panel's own counter
    in :increment
      new_count = model.count + 1
      if new_count >= 10
        # Emit command to notify Root asynchronously
        reset_msg = PanelReset.new(envelope: model.name.to_sym, count: new_count)
        [model.with(count: 0), Command.deliver(reset_msg)]
      else
        [model.with(count: new_count), nil]
      end

    # Dispatch to Leaf1
    in [:leaf1, nested_message]
      new_leaf, cmd = Leaf::Update.call(nested_message, model.leaf1)
      [model.with(leaf1: new_leaf), cmd]

    # Dispatch to Leaf2
    in [:leaf2, nested_message]
      new_leaf, cmd = Leaf::Update.call(nested_message, model.leaf2)
      [model.with(leaf2: new_leaf), cmd]

    else
      [model, nil]
    end
  }
end
```

### Root

```ruby
module Root
  Model = Data.define(:panel_a, :panel_b, :count, :total_resets)

  # Root receives ALL keyboard events AND command-produced messages
  Update = -> (message, model) {
    # Handle structured messages (async, from DeliverToRoot)
    # Pattern match on :type and :envelope
    case message
    in { type: :leaf_reset, envelope:, count: }
      puts "Leaf #{envelope} reset at #{count}"
      [model.with(total_resets: model.total_resets + 1), nil]
    in { type: :panel_reset, envelope:, count: }
      puts "Panel #{envelope} reset at #{count}"
      [model.with(total_resets: model.total_resets + 1), nil]
    else
      # Handle keyboard events — also use predicates!
      if message.enter?
        # Root's own counter
        new_count = model.count + 1
        if new_count >= 10
          # Root counts its own reset
          [model.with(count: 0, total_resets: model.total_resets + 1), nil]
        else
          [model.with(count: new_count), nil]
        end
      elsif message.a?
        dispatch_to_panel(:panel_a, :increment, model)
      elsif message.b?
        dispatch_to_panel(:panel_b, :increment, model)
      elsif message.one?
        dispatch_to_panel(:panel_a, [:leaf1, :increment], model)
      elsif message.two?
        dispatch_to_panel(:panel_a, [:leaf2, :increment], model)
      elsif message.three?
        dispatch_to_panel(:panel_b, [:leaf1, :increment], model)
      elsif message.four?
        dispatch_to_panel(:panel_b, [:leaf2, :increment], model)
      elsif message.ctrl_c?
        Rooibos::Command.exit
      else
        [model, nil]
      end
    end
  }

  def self.dispatch_to_panel(panel_key, nested_message, model)
    panel_model = model.public_send(panel_key)
    new_panel, cmd = Panel::Update.call(nested_message, panel_model)
    [model.with(panel_key => new_panel), cmd]
  end
end
```

### Data Flow

```
Inward: User presses '1'
        → Runtime delivers keyboard message to Root::Update
        → Root matches message.one?, calls dispatch_to_panel(:panel_a, [:leaf1, :increment], model)
        → Panel::Update receives [:leaf1, :increment], calls Leaf::Update.call(:increment, ...)
        → Leaf::Update receives :increment, increments counter

Outward: Leaf returns [model, Command.deliver(LeafReset.new(...))]
         → Runtime executes command asynchronously
         → Command::Deliver calls out.put(LeafReset.new(...))
         → Runtime delivers LeafReset to Root::Update
         → Root pattern matches { type: :leaf_reset, envelope:, count: }
         → Or uses predicates: message.leaf_reset? and message.leaf1?
```

### Trade-offs

| Pros | Cons |
|------|------|
| Uses standard `[model, cmd]` signature | Indirect — messages route through runtime |
| Natural fit with Rooibos command system | Async — timing is non-deterministic |
| Nested fragments fully decoupled | Root must handle all command-produced messages |
| Structured messages with pattern matching | Requires defining Message classes |
| Predicates work: `message.leaf_reset?` | |

---

## Pattern 4: Scope/Pullback (Explicit Observation)

Outer fragment calls nested Update and directly observes the result. No special types — outer fragment just knows what to look for.

**Inspiration**: TCA (Swift), manual TEA composition

### Leaf

```ruby
module Leaf
  Model = Data.define(:count, :just_reset)

  Update = -> (message, model) {
    case message
    in :increment
      new_count = model.count + 1
      if new_count >= 10
        [Model.new(count: 0, just_reset: true), nil]
      else
        [model.with(count: new_count, just_reset: false), nil]
      end
    in :clear_reset_flag
      [model.with(just_reset: false), nil]
    else
      [model.with(just_reset: false), nil]
    end
  }
end
```

### Panel

```ruby
module Panel
  Model = Data.define(:leaf1, :leaf2, :name, :count, :just_reset_self, :last_reset_leaf)

  Update = -> (message, model) {
    case message
    # Panel's own counter
    in :increment
      new_count = model.count + 1
      if new_count >= 10
        [model.with(count: 0, just_reset_self: true), nil]
      else
        [model.with(count: new_count, just_reset_self: false), nil]
      end

    # Dispatch to Leaf1
    in [:leaf1, nested_message]
      new_leaf, cmd = Leaf::Update.call(nested_message, model.leaf1)
      new_model = model.with(leaf1: new_leaf, just_reset_self: false)

      # Observe nested state directly
      if new_leaf.just_reset
        new_model = new_model.with(last_reset_leaf: "Leaf1")
      end

      [new_model, cmd]

    # Dispatch to Leaf2
    in [:leaf2, nested_message]
      new_leaf, cmd = Leaf::Update.call(nested_message, model.leaf2)
      new_model = model.with(leaf2: new_leaf, just_reset_self: false)

      if new_leaf.just_reset
        new_model = new_model.with(last_reset_leaf: "Leaf2")
      end

      [new_model, cmd]

    in :clear_last_reset
      [model.with(last_reset_leaf: nil, just_reset_self: false), nil]

    else
      [model.with(just_reset_self: false), nil]
    end
  }
end
```

### Root

```ruby
module Root
  Model = Data.define(:panel_a, :panel_b, :count, :total_resets)

  # Root receives ALL keyboard events from the runtime
  Update = -> (message, model) {
    if message.enter?
      # Root's own counter
      new_count = model.count + 1
      if new_count >= 10
        # Root counts its own reset
        [model.with(count: 0, total_resets: model.total_resets + 1), nil]
      else
        [model.with(count: new_count), nil]
      end
    elsif message.a?
      dispatch_to_panel(:panel_a, :increment, model)
    elsif message.b?
      dispatch_to_panel(:panel_b, :increment, model)
    elsif message.one?
      dispatch_to_panel(:panel_a, [:leaf1, :increment], model)
    elsif message.two?
      dispatch_to_panel(:panel_a, [:leaf2, :increment], model)
    elsif message.three?
      dispatch_to_panel(:panel_b, [:leaf1, :increment], model)
    elsif message.four?
      dispatch_to_panel(:panel_b, [:leaf2, :increment], model)
    elsif message.ctrl_c? || message.q?
      Rooibos::Command.exit
    else
      [model, nil]
    end
  }

  def self.dispatch_to_panel(panel_key, nested_message, model)
    panel_model = model.public_send(panel_key)
    new_panel, cmd = Panel::Update.call(nested_message, panel_model)
    new_model = model.with(panel_key => new_panel)

    # Observe panel state for self-reset
    if new_panel.just_reset_self
      puts "Panel reset: #{new_panel.name}"
      new_model = new_model.with(
        total_resets: model.total_resets + 1,
        panel_key => new_panel.with(just_reset_self: false)
      )
    # Observe panel state for leaf-reset
    elsif new_panel.last_reset_leaf
      puts "Leaf reset: #{new_panel.name}/#{new_panel.last_reset_leaf}"
      new_model = new_model.with(
        total_resets: model.total_resets + 1,
        panel_key => new_panel.with(last_reset_leaf: nil)
      )
    end

    [new_model, cmd]
  end
end
```

### Trade-offs

| Pros | Cons |
|------|------|
| Standard `[model, cmd]` signature | Outer fragment coupled to nested model structure |
| No new types or abstractions | Flag fields clutter the model |
| Easy to understand | Must clear flags to avoid re-triggering |

---

## Pattern 5: State Inspection After Dispatch

Outer fragment dispatches, then checks nested model for state changes. The "Rubyist" pattern — simple, pragmatic, intention-revealing.

**Inspiration**: Universal escape hatch, pragmatic Ruby

### Leaf

```ruby
module Leaf
  Model = Data.define(:count)

  RESET_THRESHOLD = 10

  Update = -> (message, model) {
    if message == :increment
      new_count = model.count + 1
      if new_count >= RESET_THRESHOLD
        [Model.new(count: 0), nil]
      else
        [model.with(count: new_count), nil]
      end
    else
      [model, nil]
    end
  }

  # Predicate for outer fragment to check
  def self.just_reset?(old_model, new_model)
    old_model.count > 0 && new_model.count == 0
  end
end
```

### Panel

```ruby
module Panel
  Model = Data.define(:leaf1, :leaf2, :name, :count)

  RESET_THRESHOLD = 10

  Update = -> (message, model) {
    case message
    # Panel's own counter
    in :increment
      new_count = model.count + 1
      if new_count >= RESET_THRESHOLD
        [model.with(count: 0), nil]
      else
        [model.with(count: new_count), nil]
      end

    # Dispatch to Leaf1
    in [:leaf1, nested_message]
      old_leaf = model.leaf1
      new_leaf, cmd = Leaf::Update.call(nested_message, old_leaf)
      new_model = model.with(leaf1: new_leaf)

      # Check state change using predicate
      if Leaf.just_reset?(old_leaf, new_leaf)
        puts "#{model.name}/Leaf1 reset!"
      end

      [new_model, cmd]

    # Dispatch to Leaf2
    in [:leaf2, nested_message]
      old_leaf = model.leaf2
      new_leaf, cmd = Leaf::Update.call(nested_message, old_leaf)
      new_model = model.with(leaf2: new_leaf)

      if Leaf.just_reset?(old_leaf, new_leaf)
        puts "#{model.name}/Leaf2 reset!"
      end

      [new_model, cmd]

    else
      [model, nil]
    end
  }

  # Predicate for Panel's own reset
  def self.just_reset?(old_model, new_model)
    old_model.count > 0 && new_model.count == 0
  end

  def self.any_leaf_reset?(old_model, new_model)
    Leaf.just_reset?(old_model.leaf1, new_model.leaf1) ||
      Leaf.just_reset?(old_model.leaf2, new_model.leaf2)
  end
end
```

### Root

```ruby
module Root
  Model = Data.define(:panel_a, :panel_b, :count, :total_resets)

  RESET_THRESHOLD = 10

  # Root receives ALL keyboard events from the runtime
  Update = -> (message, model) {
    if message.enter?
      # Root's own counter
      new_count = model.count + 1
      if new_count >= RESET_THRESHOLD
        # Root counts its own reset
        [model.with(count: 0, total_resets: model.total_resets + 1), nil]
      else
        [model.with(count: new_count), nil]
      end
    elsif message.a?
      dispatch_to_panel(:panel_a, :increment, model)
    elsif message.b?
      dispatch_to_panel(:panel_b, :increment, model)
    elsif message.one?
      dispatch_to_panel(:panel_a, [:leaf1, :increment], model)
    elsif message.two?
      dispatch_to_panel(:panel_a, [:leaf2, :increment], model)
    elsif message.three?
      dispatch_to_panel(:panel_b, [:leaf1, :increment], model)
    elsif message.four?
      dispatch_to_panel(:panel_b, [:leaf2, :increment], model)
    elsif message.ctrl_c? || message.q?
      Rooibos::Command.exit
    else
      [model, nil]
    end
  }

  def self.dispatch_to_panel(panel_key, nested_message, model)
    old_panel = model.public_send(panel_key)
    new_panel, cmd = Panel::Update.call(nested_message, old_panel)
    new_model = model.with(panel_key => new_panel)

    # Check Panel's own reset OR any leaf reset
    if Panel.just_reset?(old_panel, new_panel) || Panel.any_leaf_reset?(old_panel, new_panel)
      new_model = new_model.with(total_resets: model.total_resets + 1)
    end

    [new_model, cmd]
  end
end
```

### Data Flow

```
Inward: User presses '1'
        → Runtime delivers keyboard message to Root::Update
        → Root matches message.one?, calls dispatch_to_panel(:panel_a, [:leaf1, :increment], model)
        → Panel::Update receives [:leaf1, :increment], calls Leaf::Update.call(:increment, ...)
        → Leaf::Update receives :increment, returns [model(count: 0), nil]

Outward: Panel compares old_leaf vs new_leaf using Leaf.just_reset? predicate
         → Panel logs reset, returns [new_model, cmd]
         → Root compares old_panel vs new_panel using Panel.any_leaf_reset? predicate
         → Root increments total_resets
```

### Trade-offs

| Pros | Cons |
|------|------|
| Standard `[model, cmd]` signature | Predicate logic required |
| No model ceremony (no flags) | Coupling to model structure |
| Intention-revealing predicates | Must remember old state for comparison |
| Very Rubyist | None — this is the pragmatic choice |

---

## Comparison Summary

| Pattern | Signature | Coupling | Ceremony | Ruby Feel |
|---------|-----------|----------|----------|-----------|
| **1. OutwardMessage (3-tuple)** | `[m, c, o]` | Low | High | Functional |
| **2. Action Enum** | `Action` | Low | High | Type-heavy |
| **3. Command-Based** | `[m, c]` | Medium | Medium | Async-native |
| **4. Scope/Pullback** | `[m, c]` | High | Low | Explicit |
| **5. State Inspection** | `[m, c]` | High | Low | ⭐ Rubyist |

---

## Choosing Your Pattern

**Choose Pattern 1 (OutwardMessage)** if:
- You want explicit, typed communication contracts
- You're building a library of reusable fragments
- You prefer functional purity over Ruby idiom

**Choose Pattern 2 (Action Enum)** if:
- You want rich semantic actions with payloads
- You're comfortable with heavier type definitions
- You're coming from Rust/Iced background

**Choose Pattern 3 (Command-Based)** if:
- You want async-friendly message passing
- Your app already heavily uses commands
- You're comfortable with root handling routing

**Choose Pattern 4 (Scope/Pullback)** if:
- You want explicit observation without predicates
- You don't mind flag fields in models
- You want TCA-style outer fragment visibility

**Choose Pattern 5 (State Inspection)** if:
- You want the simplest, most Ruby-ish solution
- You prefer predicates over flags
- You want minimal ceremony
- **This is the recommended default**

---

## Mixing Patterns

You can mix patterns! Use OutwardMessage for reusable library fragments, state inspection for app-specific ones:

```ruby
module MyApp
  Update = -> (message, model) {
    case message
    in [:reusable_modal, child_message]
      # Pattern 1: Library fragment uses OutwardMessage
      new_modal, cmd, outward_message = ReusableModal::Update.call(child_message, model.modal)
      # Handle outward_message...

    in [:app_panel, child_message]
      # Pattern 5: App fragment uses state inspection
      old_panel = model.panel
      new_panel, cmd = AppPanel::Update.call(child_message, old_panel)
      if AppPanel.needs_refresh?(old_panel, new_panel)
        # Handle...
      end
    end
  }
end
```

---

Related: [Fractal Architecture](./fractal_architecture.md) | [Message Routing](./message_routing.md) | [Reusable Fragments](./reusable_fragments.md)

---

[**Previous:** Message Routing](./message_routing.md) | [**Next:** Reusable Fragments](./reusable_fragments.md)
