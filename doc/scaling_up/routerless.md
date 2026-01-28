<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Routerless Composition Patterns

After reading this guide, you will know:

- Five patterns for outward communication without the Router DSL
- How each pattern handles data flow in both directions
- When explicit control is worth the extra code
- Trade-offs between simplicity, coupling, and ceremony

---

## Context

You've been using the [Router DSL](routerful.md). It handles keyboard dispatch, routes messages to nested fragments, and coordinates outward communication with `forward` blocks. For most apps, that's exactly right.

But the Router is optional. Rooibos's core is just `(message, model) -> [model, command]`. Everything else is layered on top.

## Problem

The Router abstracts away dispatch and forwarding. That abstraction is valuable — until you need something it doesn't support. Maybe you want custom dispatch logic. Maybe you're debugging and need to see exactly how data flows. Maybe you prefer explicit code over declarative DSLs.

## Solution

Write your own Update functions. Handle inward dispatch with pattern matching. Handle outward communication with explicit checks. This guide shows five patterns for doing so.

All patterns use the same 7-fragment dashboard from [Simple Apps Don't Need Fragments](fragmentless.md):

```
Root
├── Left Panel
│   ├── Left Top
│   └── Left Bottom
└── Right Panel
    ├── Right Top
    └── Right Bottom
```

We show **data flowing both directions**:
- **Inward**: Outer fragment passes messages/data to nested fragments
- **Outward**: Nested fragments communicate events back to outer fragments

---

## The Example App: Seven Counters

Each of the 7 fragments has its own counter. Keyboard events arrive at Root's Update, which dispatches them inward to the appropriate fragment. Counters signal outward at two thresholds:
- **Count hits 5:** Signal a milestone to Root
- **Count hits 10:** Reset and signal to the parent

**Keyboard mapping:**
- `Enter` → Root's counter
- `a` → Left Panel's counter
- `b` → Right Panel's counter
- `1` → Left Top's counter
- `2` → Left Bottom's counter
- `3` → Right Top's counter
- `4` → Right Bottom's counter

```ruby
# Shared structures (used by all patterns)
module Leaf
  Model = Data.define(:name, :count)
  Init = -> (name:) { Model.new(name:, count: 0) }

  View = -> (model, tui) {
    tui.block(title: "#{model.name} [#{model.count}]", borders: [:all])
  }
end

module Panel
  Model = Data.define(:top_leaf, :bottom_leaf, :name, :count, :nested_resets)
  Init = -> (name:, top_leaf_name:, bottom_leaf_name:) {
    Model.new(
      top_leaf: Leaf::Init.(name: top_leaf_name),
      bottom_leaf: Leaf::Init.(name: bottom_leaf_name),
      name: name,
      count: 0,
      nested_resets: 0
    )
  }

  View = -> (model, tui) {
    tui.block(
      title: "#{model.name} [#{model.count}] (resets: #{model.nested_resets})",
      borders: [:all],
      children: [
        tui.layout(
          direction: :vertical,
          constraints: [tui.constraint_percentage(50), tui.constraint_percentage(50)],
          children: [Leaf::View.(model.top_leaf, tui), Leaf::View.(model.bottom_leaf, tui)]
        )
      ]
    )
  }
end

module Root
  Model = Data.define(:left_panel, :right_panel, :count, :total_resets, :milestones)
  Init = -> {
    Model.new(
      left_panel: Panel::Init.(name: "Left Panel", top_leaf_name: "Left Top", bottom_leaf_name: "Left Bottom"),
      right_panel: Panel::Init.(name: "Right Panel", top_leaf_name: "Right Top", bottom_leaf_name: "Right Bottom"),
      count: 0,
      total_resets: 0,
      milestones: 0
    )
  }

  View = -> (model, tui) {
    tui.block(
      title: "Root [#{model.count}] (resets: #{model.total_resets}, milestones: #{model.milestones})",
      borders: [:all],
      children: [
        tui.layout(
          direction: :horizontal,
          constraints: [tui.constraint_percentage(50), tui.constraint_percentage(50)],
          children: [Panel::View.(model.left_panel, tui), Panel::View.(model.right_panel, tui)]
        )
      ]
    )
  }
end
```

**The key insight**: All keyboard events arrive at `Root::Update`. Root decides where to dispatch them:
- `Enter` → Root handles directly
- `a`, `1`, `2` → Root wraps and dispatches to Left Panel
- `b`, `3`, `4` → Root wraps and dispatches to Right Panel
- Left/Right Panel then dispatch `1`/`2` or `3`/`4` to their nested Leafs


---

## Pattern 1: Extended Tuple Return (OutwardMessage)

Nested Update returns a 3-tuple: `[model, command, outward_message]`. Outer fragment destructures and handles the third element.

**Inspiration**: Elm, Elmish (F#)

### Leaf

```ruby
module Leaf
  Model = Data.define(:count)

  module OutwardMessage
    Reached5 = Data.define   # Milestone - goes to Root
    Reached10 = Data.define  # Reset - handled by Panel
    None = Data.define
  end

  # Leaf receives :increment from outer fragment, not raw keyboard events
  Update = -> (message, model) {
    if message == :increment
      new_count = model.count + 1
      case new_count
      when 5
        [model.with(count: new_count), nil, OutwardMessage::Reached5.new]
      when 10
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
  Model = Data.define(:top_leaf, :bottom_leaf, :name, :count, :nested_resets)

  module OutwardMessage
    SelfMilestone = Data.define(:panel_name)  # Panel hit 5
    SelfReset = Data.define(:panel_name)      # Panel hit 10
    LeafMilestone = Data.define(:leaf_name)   # Leaf hit 5 - pass to Root
    LeafReset = Data.define(:leaf_name)       # Leaf hit 10
    None = Data.define
  end

  # Panel receives wrapped messages from Root
  Update = -> (message, model) {
    case message
    # Panel's own counter (key 'a' or 'b' from Root)
    in :increment
      new_count = model.count + 1
      case new_count
      when 5
        [model.with(count: new_count), nil, OutwardMessage::SelfMilestone.new(panel_name: model.name)]
      when 10
        [model.with(count: 0), nil, OutwardMessage::SelfReset.new(panel_name: model.name)]
      else
        [model.with(count: new_count), nil, OutwardMessage::None.new]
      end

    # Dispatch to Leaf 1 (key '1' or '3' from Root)
    in [:top_leaf, nested_message]
      new_leaf, cmd, outward_message = Leaf::Update.call(nested_message, model.top_leaf)
      new_model = model.with(top_leaf: new_leaf)

      case outward_message
      in Leaf::OutwardMessage::Reached5
        [new_model, cmd, OutwardMessage::LeafMilestone.new(leaf_name: "#{model.name}/Leaf 1")]
      in Leaf::OutwardMessage::Reached10
        new_model = new_model.with(nested_resets: model.nested_resets + 1)
        [new_model, cmd, OutwardMessage::LeafReset.new(leaf_name: "#{model.name}/Leaf 1")]
      else
        [new_model, cmd, OutwardMessage::None.new]
      end

    # Dispatch to Leaf 2 (key '2' or '4' from Root)
    in [:bottom_leaf, nested_message]
      new_leaf, cmd, outward_message = Leaf::Update.call(nested_message, model.bottom_leaf)
      new_model = model.with(bottom_leaf: new_leaf)

      case outward_message
      in Leaf::OutwardMessage::Reached5
        [new_model, cmd, OutwardMessage::LeafMilestone.new(leaf_name: "#{model.name}/Leaf 2")]
      in Leaf::OutwardMessage::Reached10
        new_model = new_model.with(nested_resets: model.nested_resets + 1)
        [new_model, cmd, OutwardMessage::LeafReset.new(leaf_name: "#{model.name}/Leaf 2")]
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
  Model = Data.define(:left_panel, :right_panel, :count, :total_resets, :milestones)

  # Root receives ALL keyboard events from the runtime
  Update = -> (message, model) {
    if message.enter?
      # Root's own counter
      new_count = model.count + 1
      case new_count
      when 5
        [model.with(count: new_count, milestones: model.milestones + 1), nil]
      when 10
        [model.with(count: 0, total_resets: model.total_resets + 1), nil]
      else
        [model.with(count: new_count), nil]
      end
    elsif message.a?
      dispatch_to_panel(:left_panel, :increment, model)
    elsif message.b?
      dispatch_to_panel(:right_panel, :increment, model)
    elsif message.one?
      dispatch_to_panel(:left_panel, [:top_leaf, :increment], model)
    elsif message.two?
      dispatch_to_panel(:left_panel, [:bottom_leaf, :increment], model)
    elsif message.three?
      dispatch_to_panel(:right_panel, [:top_leaf, :increment], model)
    elsif message.four?
      dispatch_to_panel(:right_panel, [:bottom_leaf, :increment], model)
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
    in Panel::OutwardMessage::SelfMilestone(panel_name:)
      [new_model.with(milestones: model.milestones + 1), cmd]
    in Panel::OutwardMessage::SelfReset(panel_name:)
      [new_model.with(total_resets: model.total_resets + 1), cmd]
    in Panel::OutwardMessage::LeafMilestone(leaf_name:)
      [new_model.with(milestones: model.milestones + 1), cmd]
    in Panel::OutwardMessage::LeafReset(leaf_name:)
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
        → Root matches message.one?, calls dispatch_to_panel(:left_panel, [:top_leaf, :increment], model)
        → Panel::Update receives [:top_leaf, :increment], calls Leaf::Update.call(:increment, ...)
        → Leaf::Update receives :increment, increments counter

Outward (at 5): Leaf returns [model, nil, OutwardMessage::Reached5]
                → Panel propagates [model, nil, OutwardMessage::LeafMilestone]
                → Root increments milestones

Outward (at 10): Leaf returns [model, nil, OutwardMessage::Reached10]
                 → Panel increments nested_resets, returns [model, nil, OutwardMessage::LeafReset]
                 → Root increments total_resets
```

### Trade-offs

| Pros | Cons |
|------|------|
| Explicit communication contract | Signature differs from standard `[model, cmd]` |
| Type-safe OutwardMessage (Data.define) | Every level must handle/propagate OutwardMessage |
| Reusable nested fragments | More ceremony |

---

## Pattern 2: Command.bubble (Manual Bubbling)

Nested Update returns `Command.bubble(message)`. Outer fragment manually checks for bubbled commands and handles them.

**Inspiration**: Iced (Rust) Action Enum, wrapped in Rooibos command semantics

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

### Leaf

```ruby
module Leaf
  Model = Data.define(:name, :count)

  Update = -> (message, model) {
    if message == :increment
      new_count = model.count + 1
      case new_count
      when 5
        [model.with(count: new_count), Rooibos::Command.bubble(Milestone.new(envelope: model.name, count: new_count))]
      when 10
        [Model.new(name: model.name, count: 0), Rooibos::Command.bubble(LeafReset.new(envelope: model.name, count: new_count))]
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
  Model = Data.define(:top_leaf, :bottom_leaf, :name, :count, :nested_resets)

  Update = -> (message, model) {
    case message
    # Panel's own counter
    in :increment
      new_count = model.count + 1
      case new_count
      when 5
        [model.with(count: new_count), Rooibos::Command.bubble(Milestone.new(envelope: model.name, count: new_count))]
      when 10
        [model.with(count: 0), Rooibos::Command.bubble(PanelReset.new(envelope: model.name, count: new_count))]
      else
        [model.with(count: new_count), nil]
      end

    # Dispatch to top leaf
    in [:top_leaf, nested_message]
      new_leaf, cmd = Leaf::Update.call(nested_message, model.top_leaf)
      new_model = model.with(top_leaf: new_leaf)
      return_value_from(cmd, new_model)

    # Dispatch to bottom leaf
    in [:bottom_leaf, nested_message]
      new_leaf, cmd = Leaf::Update.call(nested_message, model.bottom_leaf)
      new_model = model.with(bottom_leaf: new_leaf)
      return_value_from(cmd, new_model)

    else
      [model, nil]
    end
  }

  # Handle bubbled commands from leaves - observe and re-bubble
  def self.return_value_from(cmd, model)
    return [model, nil] unless cmd.is_a?(Rooibos::Command::Bubble)

    bubbled_message = cmd.message
    case bubbled_message
    when LeafReset
      # Observe: increment nested_resets, then continue bubbling
      [model.with(nested_resets: model.nested_resets + 1), cmd]
    else
      # Pass through unchanged
      [model, cmd]
    end
  end
end
```

### Root

```ruby
module Root
  Model = Data.define(:left_panel, :right_panel, :count, :total_resets, :milestones)

  Update = -> (message, model) {
    if message.enter?
      # Root's own counter
      new_count = model.count + 1
      case new_count
      when 5
        [model.with(count: new_count, milestones: model.milestones + 1), nil]
      when 10
        [model.with(count: 0, total_resets: model.total_resets + 1), nil]
      else
        [model.with(count: new_count), nil]
      end
    elsif message.a?
      dispatch_to_panel(:left_panel, :increment, model)
    elsif message.b?
      dispatch_to_panel(:right_panel, :increment, model)
    elsif message.one?
      dispatch_to_panel(:left_panel, [:top_leaf, :increment], model)
    elsif message.two?
      dispatch_to_panel(:left_panel, [:bottom_leaf, :increment], model)
    elsif message.three?
      dispatch_to_panel(:right_panel, [:top_leaf, :increment], model)
    elsif message.four?
      dispatch_to_panel(:right_panel, [:bottom_leaf, :increment], model)
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

    # Handle bubbled commands - Root is the terminal handler
    return [new_model, nil] unless cmd.is_a?(Rooibos::Command::Bubble)

    bubbled_message = cmd.message
    case bubbled_message
    when Milestone
      [new_model.with(milestones: model.milestones + 1), nil]
    when LeafReset, PanelReset
      [new_model.with(total_resets: model.total_resets + 1), nil]
    else
      [new_model, nil]
    end
  end
end
```

### Data Flow

```
Inward: User presses '1'
        → Runtime delivers keyboard message to Root::Update
        → Root matches message.one?, calls dispatch_to_panel(:left_panel, [:top_leaf, :increment], model)
        → Panel::Update receives [:top_leaf, :increment], calls Leaf::Update.call(:increment, ...)
        → Leaf::Update receives :increment, increments counter

Outward (at 5): Leaf returns [model, Rooibos::Command.bubble(Milestone)]
                → Panel's return_value_from passes it through unchanged
                → Root's dispatch_to_panel extracts message, increments milestones

Outward (at 10): Leaf returns [model, Rooibos::Command.bubble(LeafReset)]
                 → Panel's return_value_from observes it, increments nested_resets, re-bubbles
                 → Root's dispatch_to_panel extracts message, increments total_resets
```

### Trade-offs

| Pros | Cons |
|------|------|
| Standard `[model, cmd]` signature | Must manually check for Rooibos::Command::Bubble |
| Same message types as Router DSL | Each level must handle/re-bubble |
| Shows exactly how Router bubbling works | More ceremony than Router's `observe` |

---

## Pattern 3: Command.deliver (Skip Intermediates)

Nested returns `Command.deliver(message)`. Runtime dispatches message directly to Root, bypassing intermediate fragments.

**Inspiration**: Bubble Tea (Go)

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

### Leaf

```ruby
module Leaf
  Model = Data.define(:count, :name)

  Update = -> (message, model) {
    if message == :increment
      new_count = model.count + 1
      case new_count
      when 5
        # Deliver milestone directly to Root
        [model.with(count: new_count), Rooibos::Command.deliver(Milestone.new(envelope: model.name, count: new_count))]
      when 10
        # Deliver reset to Root
        [Model.new(count: 0, name: model.name), Rooibos::Command.deliver(LeafReset.new(envelope: model.name, count: new_count))]
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
  Model = Data.define(:top_leaf, :bottom_leaf, :name, :count)

  Update = -> (message, model) {
    case message
    # Panel's own counter
    in :increment
      new_count = model.count + 1
      case new_count
      when 5
        [model.with(count: new_count), Rooibos::Command.deliver(Milestone.new(envelope: model.name, count: new_count))]
      when 10
        [model.with(count: 0), Rooibos::Command.deliver(PanelReset.new(envelope: model.name, count: new_count))]
      else
        [model.with(count: new_count), nil]
      end

    # Dispatch to Leaf 1
    in [:top_leaf, nested_message]
      new_leaf, cmd = Leaf::Update.call(nested_message, model.top_leaf)
      [model.with(top_leaf: new_leaf), cmd]

    # Dispatch to Leaf 2
    in [:bottom_leaf, nested_message]
      new_leaf, cmd = Leaf::Update.call(nested_message, model.bottom_leaf)
      [model.with(bottom_leaf: new_leaf), cmd]

    else
      [model, nil]
    end
  }
end
```

### Root

```ruby
module Root
  Model = Data.define(:left_panel, :right_panel, :count, :total_resets, :milestones)

  # Root receives ALL keyboard events AND command-produced messages
  Update = -> (message, model) {
    # Handle structured messages (from Rooibos::Command.deliver)
    if message.milestone?
      [model.with(milestones: model.milestones + 1), nil]
    elsif message.leaf_reset? || message.panel_reset?
      [model.with(total_resets: model.total_resets + 1), nil]
    elsif message.enter?
      # Root's own counter
      new_count = model.count + 1
      case new_count
      when 5
        [model.with(count: new_count, milestones: model.milestones + 1), nil]
      when 10
        [model.with(count: 0, total_resets: model.total_resets + 1), nil]
      else
        [model.with(count: new_count), nil]
      end
    elsif message.a?
      dispatch_to_panel(:left_panel, :increment, model)
    elsif message.b?
      dispatch_to_panel(:right_panel, :increment, model)
    elsif message.one?
      dispatch_to_panel(:left_panel, [:top_leaf, :increment], model)
    elsif message.two?
      dispatch_to_panel(:left_panel, [:bottom_leaf, :increment], model)
    elsif message.three?
      dispatch_to_panel(:right_panel, [:top_leaf, :increment], model)
    elsif message.four?
      dispatch_to_panel(:right_panel, [:bottom_leaf, :increment], model)
    elsif message.ctrl_c?
      Rooibos::Command.exit
    else
      [model, nil]
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
        → Root matches message.one?, calls dispatch_to_panel(:left_panel, [:top_leaf, :increment], model)
        → Panel::Update receives [:top_leaf, :increment], calls Leaf::Update.call(:increment, ...)
        → Leaf::Update receives :increment, increments counter

Outward (at 5): Leaf returns [model, Rooibos::Command.deliver(Milestone.new(...))]
                → Runtime executes command, delivers Milestone to Root::Update
                → Root matches message.milestone?, increments milestones

Outward (at 10): Leaf returns [model, Rooibos::Command.deliver(LeafReset.new(...))]
                 → Runtime executes command, delivers LeafReset to Root::Update
                 → Root matches message.leaf_reset?, increments total_resets
```

### Trade-offs

| Pros | Cons |
|------|------|
| Uses standard `[model, cmd]` signature | Indirect — messages route through runtime |
| Natural fit with Rooibos command system | Async — timing is non-deterministic |
| Nested fragments fully decoupled | Root must handle all command-produced messages |
| Structured messages with pattern matching | Requires defining Message classes |
| Predicates work: `message.leaf_reset?` | Panel can't observe leaf milestones (deliver bypasses it) |

---

## Pattern 4: Scope/Pullback (Explicit Observation)

Outer fragment calls nested Update and directly observes the result. No special types — outer fragment just knows what to look for.

**Inspiration**: TCA (Swift), manual TEA composition

### Leaf

```ruby
module Leaf
  Model = Data.define(:count, :just_milestone, :just_reset)

  Update = -> (message, model) {
    case message
    in :increment
      new_count = model.count + 1
      case new_count
      when 5
        [model.with(count: new_count, just_milestone: true, just_reset: false), nil]
      when 10
        [Model.new(count: 0, just_milestone: false, just_reset: true), nil]
      else
        [model.with(count: new_count, just_milestone: false, just_reset: false), nil]
      end
    in :clear_flags
      [model.with(just_milestone: false, just_reset: false), nil]
    else
      [model.with(just_milestone: false, just_reset: false), nil]
    end
  }
end
```

### Panel

```ruby
module Panel
  Model = Data.define(:top_leaf, :bottom_leaf, :name, :count, :just_milestone, :just_reset, :nested_resets, :last_leaf_event)

  Update = -> (message, model) {
    case message
    # Panel's own counter
    in :increment
      new_count = model.count + 1
      case new_count
      when 5
        [model.with(count: new_count, just_milestone: true, just_reset: false), nil]
      when 10
        [model.with(count: 0, just_milestone: false, just_reset: true), nil]
      else
        [model.with(count: new_count, just_milestone: false, just_reset: false), nil]
      end

    # Dispatch to Leaf 1
    in [:top_leaf, nested_message]
      new_leaf, cmd = Leaf::Update.call(nested_message, model.top_leaf)
      new_model = model.with(top_leaf: new_leaf, just_milestone: false, just_reset: false)

      # Observe nested state directly
      if new_leaf.just_milestone
        new_model = new_model.with(last_leaf_event: :top_leaf_milestone)
      elsif new_leaf.just_reset
        new_model = new_model.with(nested_resets: model.nested_resets + 1, last_leaf_event: :top_leaf_reset)
      end

      [new_model, cmd]

    # Dispatch to Leaf 2
    in [:bottom_leaf, nested_message]
      new_leaf, cmd = Leaf::Update.call(nested_message, model.bottom_leaf)
      new_model = model.with(bottom_leaf: new_leaf, just_milestone: false, just_reset: false)

      if new_leaf.just_milestone
        new_model = new_model.with(last_leaf_event: :bottom_leaf_milestone)
      elsif new_leaf.just_reset
        new_model = new_model.with(nested_resets: model.nested_resets + 1, last_leaf_event: :bottom_leaf_reset)
      end

      [new_model, cmd]

    in :clear_flags
      [model.with(last_leaf_event: nil, just_milestone: false, just_reset: false), nil]

    else
      [model.with(just_milestone: false, just_reset: false), nil]
    end
  }
end
```

### Root

```ruby
module Root
  Model = Data.define(:left_panel, :right_panel, :count, :total_resets, :milestones)

  # Root receives ALL keyboard events from the runtime
  Update = -> (message, model) {
    if message.enter?
      # Root's own counter
      new_count = model.count + 1
      case new_count
      when 5
        [model.with(count: new_count, milestones: model.milestones + 1), nil]
      when 10
        [model.with(count: 0, total_resets: model.total_resets + 1), nil]
      else
        [model.with(count: new_count), nil]
      end
    elsif message.a?
      dispatch_to_panel(:left_panel, :increment, model)
    elsif message.b?
      dispatch_to_panel(:right_panel, :increment, model)
    elsif message.one?
      dispatch_to_panel(:left_panel, [:top_leaf, :increment], model)
    elsif message.two?
      dispatch_to_panel(:left_panel, [:bottom_leaf, :increment], model)
    elsif message.three?
      dispatch_to_panel(:right_panel, [:top_leaf, :increment], model)
    elsif message.four?
      dispatch_to_panel(:right_panel, [:bottom_leaf, :increment], model)
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

    # Observe panel state for self-milestone
    if new_panel.just_milestone
      new_model = new_model.with(
        milestones: model.milestones + 1,
        panel_key => new_panel.with(just_milestone: false)
      )
    # Observe panel state for self-reset
    elsif new_panel.just_reset
      new_model = new_model.with(
        total_resets: model.total_resets + 1,
        panel_key => new_panel.with(just_reset: false)
      )
    # Observe panel state for leaf events
    elsif new_panel.last_leaf_event
      case new_panel.last_leaf_event
      when :top_leaf_milestone, :bottom_leaf_milestone
        new_model = new_model.with(
          milestones: model.milestones + 1,
          panel_key => new_panel.with(last_leaf_event: nil)
        )
      when :top_leaf_reset, :bottom_leaf_reset
        new_model = new_model.with(
          total_resets: model.total_resets + 1,
          panel_key => new_panel.with(last_leaf_event: nil)
        )
      end
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

  MILESTONE_THRESHOLD = 5
  RESET_THRESHOLD = 10

  Update = -> (message, model) {
    if message == :increment
      new_count = model.count + 1
      case new_count
      when RESET_THRESHOLD
        [Model.new(count: 0), nil]
      else
        [model.with(count: new_count), nil]
      end
    else
      [model, nil]
    end
  }

  # Predicates for outer fragment to check
  def self.hit_milestone?(old_model, new_model)
    old_model.count < MILESTONE_THRESHOLD && new_model.count == MILESTONE_THRESHOLD
  end

  def self.just_reset?(old_model, new_model)
    old_model.count > 0 && new_model.count == 0
  end
end
```

### Panel

```ruby
module Panel
  Model = Data.define(:top_leaf, :bottom_leaf, :name, :count, :nested_resets)

  MILESTONE_THRESHOLD = 5
  RESET_THRESHOLD = 10

  Update = -> (message, model) {
    case message
    # Panel's own counter
    in :increment
      new_count = model.count + 1
      case new_count
      when RESET_THRESHOLD
        [model.with(count: 0), nil]
      else
        [model.with(count: new_count), nil]
      end

    # Dispatch to Leaf 1
    in [:top_leaf, nested_message]
      old_leaf = model.top_leaf
      new_leaf, cmd = Leaf::Update.call(nested_message, old_leaf)
      new_model = model.with(top_leaf: new_leaf)

      # Track nested resets
      if Leaf.just_reset?(old_leaf, new_leaf)
        new_model = new_model.with(nested_resets: model.nested_resets + 1)
      end

      [new_model, cmd]

    # Dispatch to Leaf 2
    in [:bottom_leaf, nested_message]
      old_leaf = model.bottom_leaf
      new_leaf, cmd = Leaf::Update.call(nested_message, old_leaf)
      new_model = model.with(bottom_leaf: new_leaf)

      if Leaf.just_reset?(old_leaf, new_leaf)
        new_model = new_model.with(nested_resets: model.nested_resets + 1)
      end

      [new_model, cmd]

    else
      [model, nil]
    end
  }

  # Predicates for Panel's own state changes
  def self.hit_milestone?(old_model, new_model)
    old_model.count < MILESTONE_THRESHOLD && new_model.count == MILESTONE_THRESHOLD
  end

  def self.just_reset?(old_model, new_model)
    old_model.count > 0 && new_model.count == 0
  end

  def self.any_leaf_milestone?(old_model, new_model)
    Leaf.hit_milestone?(old_model.top_leaf, new_model.top_leaf) ||
      Leaf.hit_milestone?(old_model.bottom_leaf, new_model.bottom_leaf)
  end

  def self.any_leaf_reset?(old_model, new_model)
    Leaf.just_reset?(old_model.top_leaf, new_model.top_leaf) ||
      Leaf.just_reset?(old_model.bottom_leaf, new_model.bottom_leaf)
  end
end
```

### Root

```ruby
module Root
  Model = Data.define(:left_panel, :right_panel, :count, :total_resets, :milestones)

  MILESTONE_THRESHOLD = 5
  RESET_THRESHOLD = 10

  # Root receives ALL keyboard events from the runtime
  Update = -> (message, model) {
    if message.enter?
      # Root's own counter
      new_count = model.count + 1
      case new_count
      when MILESTONE_THRESHOLD
        [model.with(count: new_count, milestones: model.milestones + 1), nil]
      when RESET_THRESHOLD
        [model.with(count: 0, total_resets: model.total_resets + 1), nil]
      else
        [model.with(count: new_count), nil]
      end
    elsif message.a?
      dispatch_to_panel(:left_panel, :increment, model)
    elsif message.b?
      dispatch_to_panel(:right_panel, :increment, model)
    elsif message.one?
      dispatch_to_panel(:left_panel, [:top_leaf, :increment], model)
    elsif message.two?
      dispatch_to_panel(:left_panel, [:bottom_leaf, :increment], model)
    elsif message.three?
      dispatch_to_panel(:right_panel, [:top_leaf, :increment], model)
    elsif message.four?
      dispatch_to_panel(:right_panel, [:bottom_leaf, :increment], model)
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

    # Check for milestones
    if Panel.hit_milestone?(old_panel, new_panel) || Panel.any_leaf_milestone?(old_panel, new_panel)
      new_model = new_model.with(milestones: model.milestones + 1)
    end

    # Check for resets
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
        → Root matches message.one?, calls dispatch_to_panel(:left_panel, [:top_leaf, :increment], model)
        → Panel::Update receives [:top_leaf, :increment], calls Leaf::Update.call(:increment, ...)
        → Leaf::Update receives :increment, returns [model(count: N), nil]

Outward (at 5): Root compares old_panel vs new_panel using Panel.any_leaf_milestone?
                → Root increments milestones

Outward (at 10): Panel compares old_leaf vs new_leaf using Leaf.just_reset?
                 → Panel increments nested_resets
                 → Root compares old_panel vs new_panel using Panel.any_leaf_reset?
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
| **2. Command.bubble** | `[m, c]` | Low | Medium | Command-native |
| **3. Command.deliver** | `[m, c]` | Medium | Medium | Async-native |
| **4. Scope/Pullback** | `[m, c]` | High | Low | Explicit |
| **5. State Inspection** | `[m, c]` | High | Low | ⭐ Rubyist |

---

## Choosing Your Pattern

**Choose Pattern 1 (OutwardMessage)** if:
- You want explicit, typed communication contracts
- You're building a library of reusable fragments
- You prefer functional purity over Ruby idiom

**Choose Pattern 2 (Command.bubble)** if:
- You want the same semantics as Router's `observe`
- Intermediate fragments need to observe events
- You're already using Command types throughout

**Choose Pattern 3 (Command.deliver)** if:
- Nested fragments should signal directly to Root
- Intermediate fragments don't need to observe
- You want the same semantics as Router's `intercept`

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

## See Also

- [Simple Apps Don't Need Fragments](fragmentless.md) — Start here for simple apps
- [Router-Based Composition](routerful.md) — Declarative patterns with Router DSL
- [Fractal Architecture](fractal_architecture.md) — When and why to decompose
- [Message Routing](message_routing.md) — How messages flow through fragments
- [Reusable Fragments](reusable_fragments.md) — Building library-quality components
