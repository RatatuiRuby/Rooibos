<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Stateless Widgets in MVU

After reading this guide, you will know:

- Why Rooibos uses stateless widgets instead of stateful widgets
- How to achieve selection highlighting, scrolling, and bounds clamping
- When to handle Resize events for viewport-aware layouts

---

## Context

RatatuiRuby offers two widget rendering modes: stateless (`render_widget`) and stateful (`render_stateful_widget`). Stateful widgets accept a mutable state object during render, updating scroll offsets and clamping selections based on viewport size.

```ruby
# Stateful approach (imperative, inside draw block)
RatatuiRuby.draw do |frame|
  frame.render_stateful_widget(list, frame.area, @list_state)
  # @list_state is mutated during render
end
```

## Problem

MVU separates *what to display* (View) from *when to render* (Runtime). The View callable builds a widget tree. The Runtime renders it later.

Stateful widgets blur this boundary. They mutate state during render, creating hidden side effects. This breaks the MVU guarantee: **state only changes via Update**.

Passing mutable state during render means:

1. State changes happen outside Update
2. State mutations are invisible to the message flow
3. Testing becomes harder—you can't predict state after render

## Solution

Rooibos uses stateless widgets exclusively. All state management happens in your Model, computed by your Update function.

The "magic" that stateful widgets perform is simple arithmetic. You can do it yourself.

---

## What Stateful Widgets Actually Do

Stateful widgets perform two render-time operations:

### 1. Selection Bounds Clamping

If `selected >= items.length`, clamp to the last item:

```ruby
# In Update, after any selection change
def clamp_selection(model)
  max_index = model.items.length - 1
  if model.selected && model.selected > max_index
    model.with(selected: [max_index, 0].max)
  else
    model
  end
end
```

### 2. Scroll Offset Calculation

Compute which item should be at the top of the visible window:

```ruby
# In Update, after selection or viewport changes
def calculate_offset(model)
  return model unless model.selected

  visible_count = model.viewport.height
  selected = model.selected
  offset = model.offset

  # If selected is above current view, scroll up
  if selected < offset
    model.with(offset: selected)
  # If selected is below current view, scroll down
  elsif selected >= offset + visible_count
    model.with(offset: selected - visible_count + 1)
  else
    model
  end
end
```

---

## Storing Viewport Dimensions

Your Model stores the terminal dimensions. Query them in `Init` and update on `Resize` events.

### Init

```ruby
Init = -> {
  [
    Model.new(
      items: [],
      selected: nil,
      offset: 0,
      viewport: RatatuiRuby.viewport_area
    ),
    fetch_items_command
  ]
}
```

### Update

```ruby
Update = ->(model, message) {
  case message
  in Rooibos::Message::Resize(width:, height:)
    new_viewport = RatatuiRuby::Layout::Rect.new(x: 0, y: 0, width:, height:)
    new_model = model.with(viewport: new_viewport)
    [calculate_offset(new_model), nil]
  in SelectNext
    new_selected = [(model.selected || -1) + 1, model.items.length - 1].min
    new_model = model.with(selected: new_selected)
    [calculate_offset(new_model), nil]
  # ...
  end
}
```

### View

```ruby
View = ->(model, tui) {
  visible_items = model.items[model.offset, model.viewport.height] || []

  list = tui.list(
    items: visible_items,
    highlight_style: tui.style(fg: :yellow)
  )

  # Highlighting uses the offset-adjusted index
  if model.selected
    visible_selected = model.selected - model.offset
    list = list.with(selected_index: visible_selected)
  end

  list
}
```

---

## Benefits

### Testable State

All state changes happen in Update. Test your logic without rendering:

```ruby
def test_selection_clamps_to_bounds
  viewport = RatatuiRuby::Layout::Rect.new(x: 0, y: 0, width: 80, height: 10)
  model = Model.new(items: ["a", "b"], selected: 5, offset: 0, viewport:)
  result, _ = Update.call(model, ClampSelection.new)
  assert_equal 1, result.selected
end
```

### Predictable Rendering

View is a pure function. Given the same Model, it returns the same widget tree. No hidden mutations.

### No Frame Dependency

View runs before the draw callback. Terminal queries work normally.

---

## See Also

- [The Elm Architecture](../essentials/the_elm_architecture.md) — Core MVU concepts
- [Lists and Tables](lists_and_tables.md) — Patterns for scrollable collections
