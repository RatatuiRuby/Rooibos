<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Scrollbar Widget Support

## Status

**Blocked.** Scrollbar overlays require frame-level rendering, which MVU abstracts away.

## Problem

Scrollbar widgets in RatatuiRuby render as overlays on the same area as content:

```ruby
# In RatatuiRuby (imperative)
frame.render_widget(paragraph, frame.area)
frame.render_widget(scrollbar, frame.area)  # Overlays on right edge
```

In Rooibos MVU, View returns a widget tree. The runtime renders all widgets sequentially. When a scrollbar is added as a sibling to a list inside a block:

```ruby
# In Rooibos (MVU)
tui.block(children: [list, scrollbar])
```

The scrollbar renders **inside** the content area, not **on** the border. It also inherits layout properties (takes up width, changes sibling positioning).

## Why This Happens

1. **No frame access in View.** View is a pure function that returns widgets. It cannot call `frame.render_widget` for overlay positioning.

2. **Children are siblings.** Block's `children` are laid out sequentially, not stacked.

3. **Scrollbar is position-aware.** It needs to know the rendered area to position itself at the right edge.

## Workarounds Considered

### 1. Overlay Widget (Not Implemented)

A dedicated overlay widget that renders children on top of each other:

```ruby
tui.overlay(base: list, overlay: scrollbar)
```

**Problem:** Would need to track which child gets which area and handle z-ordering.

### 2. Block with Scrollbar Option

Add scrollbar support directly to Block:

```ruby
tui.block(
  children: [list],
  scrollbar: { content_length: 100, position: 10 }
)
```

The Block would render its children, then overlay the scrollbar on the right border.

**Advantages:**
- Scrollbar naturally belongs with the bordered container
- No new widget type needed
- Block already handles border rendering

**Disadvantages:**
- Would need to be added to RatatuiRuby, or
- Would need to intercept TUI facade and Block.new

### 3. Custom Widget (Current Pattern)

Users implement scrollbar rendering in a custom widget that has frame access:

```ruby
class ScrollableList
  def render(area)
    # Split area, render list, then overlay scrollbar
  end
end
```

**Problem:** Breaks the pure View pattern. Custom widgets are RatatuiRuby-level, not MVU-level. Duplicates logic from Scrollbar.

### 4. Provide `Frame` to View

Pass the frame to View, so it can call `render_widget` for overlay positioning.

```ruby
module MyFragment
  View = -> (model, tui, frame) {
    tui.block(
      children: [tui.list(items: model.items)],
      scrollbar: { content_length: model.items.length, position: model.offset }
    )
  }
end
```

**Problem:** Breaks the pure View-as-returned-tree pattern.

## Recommendation

Investigate more options.

## Open Questions

1. Should scrollbar position be `offset` (scroll window position) or `selected_index`?
2. Should scrollbar automatically infer `content_length` from list children?
3. How to handle horizontal scrollbars?

## See Also

- [no_stateful_widgets.md](../../best_practices/no_stateful_widgets.md) — MVU scroll offset patterns
- [RatatuiRuby Scrollbar](https://github.com/setdef/RatatuiRuby/blob/stable/lib/ratatui_ruby/widgets/scrollbar.rb)
- [widget_scrollbar example](https://github.com/setdef/RatatuiRuby/tree/stable/examples/widget_scrollbar)
