<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Tabbed Fragments Example App

Demonstrate **every** Router API by nesting the Seven Counters dashboard as `CounterTab`, with `ColorTab` (scrollable XKCD colors), clickable `TabBar`, and theme switching.

## Router API Coverage

| API | Fragment | Usage |
|-----|----------|-------|
| `route :name, to:` | App, CounterTab, Panel | Standard child routes |
| `action :name, handler` | App | `:quit` |
| `action:` + `route:` keymap | App | Semantic envelope routing |
| `keymap` guards (`when:`) | App | Conditional routing by active tab |
| `keymap` | App, TabBar | Key bindings |
| `mousemap` | TabBar | Click to select tab |
| `forward broadcast:` | App | `:resize` to all tabs |
| `forward with_type` block | ColorTab | Resize handler |
| `forward with_envelope as:` | CounterTab, Panel | **NEW** Envelope transformation |
| `observe` | App, CounterTab | Track resets/milestones/tab selection |
| `observe_all` | App | Count all messages |
| `intercept` | CounterTab, Panel, Leaf, ColorTab | Handle semantic envelopes |
| `intercept_all` | CounterTab, ColorTab | Disable input when inactive |
| `intercept` + re-bubble | Panel | Transform `LeafReset` → `PanelChildReset` |
| `otherwise route_to:` | App | Fallback to TabBar |
| `from_router` | All Router fragments | Generate Update |
| `Command.bubble` | Leaf, Panel, App | Outward at threshold |
| `Command.deliver` | Leaf, Panel | Fire-and-forget milestones |
| `Command.batch` + bubble | ColorTab | Bubble `ColorChanged` + animation timer |

---

## Semantic Envelope Pattern

Each layer sends envelopes in its **child's API language**, not in key names:

```
App                    → CounterTab: :counter_1, :counter_2, :counter_3, :counter_4
CounterTab (as:)       → Panel:      :leaf_1, :leaf_2, :panel_self
Panel (as:)            → Leaf:       :increment
```

This ensures proper encapsulation:
- App knows CounterTab has counters 1-4, not how they're organized
- CounterTab knows Panel has leaf_1/leaf_2, not their internal names
- Panel knows Leaf responds to :increment, not specific key names

---

## File Structure

```
examples/app_tabbed_fragments/
├── app.rb
├── data/
│   └── xkcd_colors.txt       # Downloaded via curl
└── fragments/
    ├── app.rb
    ├── tab_bar.rb
    ├── counter_tab.rb
    ├── panel.rb
    ├── leaf.rb
    ├── color_tab.rb
    ├── controls.rb
    └── messages.rb
```

---

## Verification

```bash
ruby examples/app_tabbed_fragments/app.rb
```

1. Tab switching (keyboard Tab key)
2. CounterTab: 1-4 leaves, a/b panels, counters increment
3. ColorTab: scroll with j/k, Enter selects
4. Theme: `t` cycles border colors
5. Message count visible in TabBar title
6. Resize terminal → ColorTab recalculates visible items
7. `q` to quit

---

## Required Router Enhancement: `as:` Option

The example uses `forward ... as:` which is **not yet implemented**. This section documents what needs to be added.

### API Design

```ruby
forward do |messages|
  messages.with_envelope :counter_1, route_to: :left_panel, as: :leaf_1
end
```

When `as:` is provided, the Router should create a **new** `Message::Routed` with the transformed envelope before forwarding to the child fragment.

### Implementation Location

[ForwardBuilder#with_envelope](file:///Users/kerrick/Developer/ratatui_ruby-tea/lib/rooibos/router.rb#L1043) in `lib/rooibos/router.rb`

### Changes Required

1. **Add `as:` parameter to `with_envelope`**:
   ```ruby
   def with_envelope(envelope_name, route_to: nil, as: nil, &handler)
     envelope_sym = envelope_name.to_s.to_sym
     as_sym = as&.to_s&.to_sym
     @handlers << {
       predicate: -> (msg) { msg.respond_to?(:envelope) && msg.envelope == envelope_sym },
       handler:,
       action: nil,
       broadcast: false,
       broadcast_to: nil,
       route_to:,
       transform_envelope: as_sym,
     }
   end
   ```

2. **Handle `transform_envelope` in RouterUpdate#call** (around line 600-610):
   ```ruby
   elsif config[:route_to]
     route_key, route_config = find_route_config(config[:route_to])
     if route_config && route_key
       fragment_update = route_config.fragment.const_get(:Update)
       child_model = route_config.reader ? route_config.reader.call(model) : model.public_send(route_key)
       
       # Transform envelope if as: was specified
       routed_message = if config[:transform_envelope] && message.respond_to?(:envelope)
         Rooibos::Message::Routed.new(envelope: config[:transform_envelope], event: message.event)
       else
         message
       end
       
       new_child_model, cmd = fragment_update.call(routed_message, child_model)
       # ... rest unchanged
     end
   end
   ```

3. **Add RBS signature** in `sig/rooibos/router.rbs`

4. **TDD tests** in `test/router/test_forward.rb`:
   - Test that `as:` transforms envelope
   - Test that original event is preserved
   - Test that without `as:`, envelope passes through unchanged

### Validation

After implementing, run:
```bash
bundle exec agent_rake
ruby examples/app_tabbed_fragments/app.rb
```

---

## Required Router Enhancement: Unified Guard System

All Router DSL predicates receive **`(model, message)`** for consistency. Guards can be scoped with top-level `only`/`skip` blocks that apply to any router declaration.

### Unified Predicate Signature

**All predicates**: `-> (model, message) { ... }`

```ruby
# Use _ for unused arguments
intercept when: -> (model, _) { !model.active }, then: ...
observe when: -> (_, msg) { msg.key? }, then: ...

# Keymap guards become (model, message) too
keymap do |map|
  map.key :j, :move, when: -> (model, msg) { model.editable? && msg.shift? }
end
```

### Module-Level `only`/`skip` Blocks

`only`/`skip` are module-level methods that work **anywhere**, including inside keymap/forward blocks. This **replaces** `map.only`/`map.skip`:

```ruby
only when: -> (model, _) { model.focused? } do
  intercept when: -> (_, msg) { msg.q? }, then: -> (_, model) { ... }
  observe when: -> (_, msg) { msg.key? }, then: -> (_, model) { ... }
  otherwise route_to: :active_panel
end

keymap do |map|
  map.key :q, :quit  # always available
  
  only when: -> (model, _) { model.editable? } do
    map.key :d, :delete  # guarded
    map.key :x, :cut
  end
end

skip when: -> (model, _) { model.locked? } do
  keymap do |map|
    map.key :d, :delete
  end
end
```

### Multiple `otherwise` Declarations

With guards, `otherwise` becomes a conditional fallthrough chain:

```ruby
otherwise route_to: :counter_tab, when: -> (model, _) { model.active_tab == :counter }
otherwise route_to: :color_tab, when: -> (model, _) { model.active_tab == :color }
otherwise route_to: :tab_bar  # catch-all (no guard)
```

### Affected DSL Elements

| DSL | Current Predicate | New Predicate |
|-----|-------------------|---------------|
| `intercept when:` | `-> (msg)` | `-> (model, msg)` |
| `observe when:` | `-> (msg)` | `-> (model, msg)` |
| `keymap when:` | `-> (model)` | `-> (model, msg)` |
| `mousemap when:` | `-> (model)` | `-> (model, msg)` |
| `forward when:` | N/A (new) | `-> (model, msg)` |
| `otherwise when:` | N/A (new) | `-> (model, msg)` |
| `only`/`skip` blocks | N/A (new) | `-> (model, msg)` |

### Implementation Changes

1. **Update all predicate invocations** to pass `(model, message)`
2. **Add guard to intercept/observe DSL** with `when:`/`unless:`
3. **Add guard to forward builder** methods
4. **Make `otherwise` a list** with optional guards
5. **Add top-level `only`/`skip`** that pushes to guard stack
6. **Update RBS signatures**
7. **TDD tests** for each element

### CounterTab Fix

```ruby
# Block all input when inactive
intercept_all -> (_, model) { [model, nil] },
  unless: -> (model, _) { model.active }
```

### Validation

```bash
bundle exec ruby -Itest test/router/test_intercept.rb
bundle exec agent_rake
ruby examples/app_tabbed_fragments/app.rb
```
