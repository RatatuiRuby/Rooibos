<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Router-Based Composition Patterns

After reading this guide, you will know:

- How to use the Router DSL to coordinate messages between fragments
- When to use `Rooibos::Command.bubble` vs `Rooibos::Command.deliver` for outward communication
- How the `forward`, `intercept`, and `observe` families work together
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

**`route`** binds a fragment to a slice of your model. It declares one level of nesting. The simplest form names a model attribute:

```ruby
route :sidebar, to: Sidebar
route :file_list, to: FileList
```

Here `:sidebar` means "read from `model.sidebar`, write back with `model.with(sidebar: ...)`". The symbol is shorthand for extraction and merging.

When your model stores fragments in hashes or other structures, use `read:` and `write:` lambdas instead:

```ruby
route read: ->(model) { model.panels[:sidebar] },
      write: ->(current_model, value) { current_model.with(panels: current_model.panels.merge(sidebar: value)) },
      to: Sidebar
```

Another common pattern is dynamic routing based on model state. Route to whichever tab is active:

```ruby
route read: ->(model) { model.tabs[model.active_tab] },
      write: ->(current_model, value) { current_model.with(tabs: current_model.tabs.merge(current_model.active_tab => value)) },
      to: TabContent
```

`route` returns a **Route**, an object that pairs the fragment with its accessor. You can capture this for later reference:

```ruby
ACTIVE_TAB = route read: ->(model) { model.tabs[model.active_tab] },
                   write: ->(model, value) { model.with(tabs: model.tabs.merge(model.active_tab => value)) },
                   to: TabContent

forward_events :enter, to: ACTIVE_TAB, as: :submit
```

Most routes don't need this. Capture the Route when neither the model attribute symbol nor the fragment module can unambiguously identify the route.

When other DSL methods refer to a route (via `to:` or `route_to:`), they accept three forms:

Symbol
: the model attribute: `to: :list` (works when the attribute is used once)

Module
: the fragment: `to: FileList` (works when the fragment is used once)

Route
: the return value of `route`: `to: MY_ROUTE` (always unambiguous)

The generated Update routes messages to nested fragments automatically.

### Actions

**`action`** defines reusable handlers. Reference actions by name in `receive*`, `intercept*`, and `observe*` methods (anywhere a handler lambda is accepted).

Lambda actions run directly and return commands or model updates:

```ruby
action :quit, -> { Rooibos::Command.exit }
action scroll_up: -> (_message, model) { model.with(offset: model.offset - 1) }
```

Routed actions dispatch a `Message::Routed` to a fragment. The action name becomes the envelope:

```ruby
action go_back: HistoryPanel
action :show_details, InfoPanel
```

> [!NOTE]
> Actions are handlers, routes are destinations. Use action names where you could use a lambda (e.g., `receive_events :q, :quit`). For routing destinations, use `to:` with a model attribute symbol, a fragment module, or a Route (see [Routes](#routes)).

### Guards

Many Router declarations support **guards**, predicates that control when handlers run. Guards receive `(message, model)` and return `false` or `nil` to skip the handler.

**`only`/`skip` blocks** scope guards to multiple declarations:

```ruby
only when: -> (_message, model) { model.focused? } do
  forward_events :j, to: :list, as: :move_down
  forward_events :k, to: :list, as: :move_up
  otherwise route_to: :active_panel
end

skip when: -> (_message, model) { model.locked? } do
  receive_events :d, :delete  # skipped when locked
end
```

**`route_to` blocks** scope the destination for multiple forwards:

```ruby
only when: COUNTER_ACTIVE do
  route_to :counter_tab do
    forward_events :"1", as: :counter_1
    forward_events :"2", as: :counter_2
    forward_events :enter, as: :root_increment
  end
end
```

Choose a guard alias to match your semantics: `when:`, `if:`, `only:`, `guard:` (positive); `unless:`, `except:`, `skip:` (negative).

---

## The Three Families

The Router DSL has three core families: **forward** (route to nested fragment), **observe** (handle, and continue to other handlers), and **intercept**/**receive** (handle and stop processing). Each family has variants for different matching strategies:

Each family has the same five variants, each matching a different way. Append the suffix to any family name: `forward_events`, `intercept_events`, `observe_events`, etc.

`(no suffix)`
: Custom predicate lambda — `(message, model) → truthy/falsy`

`_routed`
: `Message::Routed` by envelope symbol

`_events`
: `RatatuiRuby::Event` by `to_sym`

`_instances_of`
: Message by class

`_all`
: Everything

All handlers receive `(message, model)` and support DWIM returns:

`nil`
: no change

`model`
: new model, no command

`command`
: command only (model unchanged)

`[model, command]`
: both

Handlers accept zero or two arguments. Zero-argument handlers work for side-effect-only cases like exiting. One-argument handlers are rejected because it's ambiguous whether you meant `message` or `model`.

### Forward Family

**`forward*`** routes messages to declared routes. The `to:` parameter identifies which route receives the message. It accepts all three forms described in [Routes](#routes): a symbol (model attribute), a module (fragment), or a Route (return value of `route`).

#### `forward`

The base `forward` method accepts a predicate lambda. The lambda receives `(message, model)`. If it returns a value other than `nil` or `false`, the message is forwarded. Use this for complex matching logic that the specialized variants cannot express:

```ruby
forward -> (msg, _) { msg.key? && msg.ctrl? },  to: :editor
forward -> (msg, _) { msg.key? && msg.shift? }, to: Sidebar
forward -> (msg, _) { msg.key? && msg.text? },  to: ACTIVE_TAB
```

#### `forward_events`

Matches raw RatatuiRuby events by their `to_sym` value. This covers key presses, mouse clicks, and other terminal events. Pass a symbol for a single event, or an array for multiple events that route to the same destination:

```ruby
forward_events :enter,      to: :active_form
forward_events [:up, :k],   to: :list
forward_events [:down, :j], to: :list
```

To avoid spreading knowledge of your keybindings throughout your application, [wrap the event in a semantic name using `as:`](#envelope-transformation-with-as).

#### `forward_routed`

Matches `Message::Routed` messages by their `envelope`. Use this when an outer fragment has already routed an event and you need to route it further to a nested fragment:

```ruby
forward_routed :submit, to: :form_validator
forward_routed :scroll_up, to: :list
```

To decouple outer fragments from deeply nested fragments, [transform the envelope before forwarding using `as:`](#envelope-transformation-with-as).

#### `forward_instances_of`

Matches messages by class. This is ideal for custom message types from your application, or RatatuiRuby event classes like `Event::Resize`:

```ruby
forward_instances_of RatatuiRuby::Event::Resize, to: :main_layout
forward_instances_of ThemeChanged,               to: :theme_manager
```

To send the same message to multiple routes, use [`broadcast:`](#broadcasting).

#### `forward_all`

Matches any message. Use it as a catch-all, or combine it with guards to conditionally route unhandled messages:

```ruby
only when: ->(message, model) { model.active_tab == :counter_tab } do
  forward_all to: :counter_tab
end
forward_all to: :active_panel
```

#### Envelope Transformation with `as:`

`as:` controls whether the forwarded message is wrapped in a `Message::Routed`. The rule is universal across all forward variants:

- **With `as:`** — Raw messages are wrapped in a new `Message::Routed` with the given envelope. Already-routed messages have their envelope transformed; the original `event` is preserved.
- **Without `as:`** — The raw message passes through unchanged. The nested fragment receives exactly what the router matched.

```ruby
# Nested fragment receives Message::Routed(envelope: :submit, event: RatatuiRuby::Event::Key(:enter))
forward_events :enter, to: :form, as: :submit

# Nested fragment receives the raw RatatuiRuby::Event::Key(:enter) event
forward_events :enter, to: :form
```

This applies to every forward variant:

```ruby
# Re-wraps with a new envelope, replacing the existing one
forward_routed :counter_1, to: :left_panel, as: :leaf_1

# Nested fragment receives the existing Routed message
forward_routed :submit, to: :form_validator

# Nested fragment receives the raw class instance
forward_instances_of RatatuiRuby::Event::Resize, to: :main_layout
```

Use `as:` to decouple layers. Each layer speaks its inner fragment's API without knowing what lies deeper. The outer fragment binds keys to semantic names. Inner fragments depend upon those names. Change keybindings without changing inner fragments. Reorganize inner fragments without changing outer ones.

> **Note**: `forward*` without `as:` passes raw messages. For transparent delegation of *all* unhandled messages, prefer [`otherwise`](#otherwise)—it always passes messages raw and doesn't require listing events individually. Use `forward*` without `as:` when you need to selectively route specific messages without adding a semantic layer.

#### Broadcasting

Broadcast messages to multiple or all routes. Use `broadcast: true` to send to all declared routes, or `broadcast_to:` with an array of specific route names:

```ruby
forward_instances_of RatatuiRuby::Event::Resize, broadcast: true
forward_instances_of ThemeChanged, broadcast_to: [:sidebar, :main_panel]
```

### Intercept / Receive Family

**`intercept*`** and **`receive*`** are aliases. Both handle a message exclusively and stop further processing. The message never reaches later handlers.

Use **`receive*`** when a message is addressed to you: inward-flowing events, routed messages from outer fragments, or terminal handling at Root.

Use **`intercept*`** when stopping a bubbled message mid-chain before it reaches its original destination.

#### `receive_events` / `intercept_events`

Matches raw RatatuiRuby events by `to_sym`. The second argument can be an action name or a handler lambda:

```ruby
receive_events :ctrl_c, :quit
receive_events :q, :quit
```

#### `receive_instances_of` / `intercept_instances_of`

Matches messages by class. Use `receive` for messages addressed to you. Use `intercept` to stop a bubbled message mid-chain:

```ruby
# Terminal handling of bubbled message at Root
receive_instances_of FatalError,
  -> (msg, model) { [model.with(error: msg), Rooibos::Command.exit] }

# Mid-chain interception of bubbled message
intercept_instances_of LeafReset,
  -> (msg, model) { model.with(resets: model.resets + 1) }

# Expected handling of routed message from outer fragment
receive_instances_of ThemeChanged,
  -> (msg, model) { model.with(theme: msg.theme) }
```

#### `receive_routed` / `intercept_routed`

Matches `Message::Routed` by envelope. Use this when an outer fragment has forwarded a message and your fragment handles it:

```ruby
receive_routed :panel_self,
  -> (_, model) {
    count = model.count + 1
    model.with(count: count >= 10 ? 0 : count)
  }
```

#### `receive` / `intercept`

The base methods accept a predicate lambda for complex matching logic. A single fragment can have multiple `receive` declarations, each handling a different concern. This keeps related logic grouped together rather than merged into one giant conditional:

```ruby
# Concern: Visual mode commands (Shift+key combinations)
only when: -> (_message, model) { model.mode == :visual } do
  receive :shift_delete, -> (_message, model) { model.with(deleted: true) }
  receive :shift_c, -> (_message, model) { [model, Rooibos::Command.custom(Clipboard.copy(model.selection))] }
end

# Concern: Insert mode (any printable character)
receive -> (message, model) { model.mode == :insert && message.key? && message.text? },
  -> (message, model) { model.with(buffer: model.buffer + message.char) }
```

Each `receive` handles one concern. The Router tries them in order; the first match wins. This is clearer than a single handler with nested conditionals.

Use `intercept` with a predicate when stopping a bubbled message mid-chain:

```ruby
intercept -> (message, model) { model.locked? && message.envelope == :bubbled_lockable },
  -> (_, _) { nil }
```

#### `receive_all` / `intercept_all`

Matches any message. Combine with guards to create conditional catch-alls. For example, block all input when a fragment is inactive:

```ruby
receive_all -> (msg, model) { [model, nil] },
  unless: -> (_, model) { model.active }
```

### Observe Family

**`observe`** processes a message, updates model, emits commands, then lets the message continue. All matching observers run in declaration order. Use observe for side effects that shouldn't block other handlers: logging, counting, updating derived state.

#### `observe_all`

Matches every message. This is useful for metrics, debugging, or global state updates that apply regardless of message type:

```ruby
observe_all -> (msg, model) {
  model.with(message_count: model.message_count + 1)
}
```

#### `observe_instances_of`

Matches messages by class. Use it to react to custom message types while allowing them to continue to other handlers:

```ruby
observe_instances_of ThemeChanged,
  -> (msg, model) { model.with(theme: msg.theme) }

observe_instances_of TabSelected,
  -> (msg, model) { model.with(active_tab: msg.tab) }
```

#### `observe_events`

Matches raw RatatuiRuby events by `to_sym`. Use it for event-specific side effects:

```ruby
observe_events :enter,
  -> (_, model) { [model, Rooibos::Command.custom(Logger.log("Enter pressed"))] }
```

---

## Otherwise

**`otherwise`** is a router-level fallback. It catches any message not handled by `intercept`, `receive`, or `forward`. Unlike `forward*`, `otherwise` always passes the raw message through, without wrapping it in `Message::Routed`. This makes it ideal for reusable fragments that handle raw events (e.g., a text editor) without knowing they're nested.

The `route_to:` parameter accepts the same three forms as `to:` in the forward family. Multiple `otherwise` declarations can use guards to create a conditional fallthrough chain.

This is useful when an outer fragment doesn't need to know everything its nested fragments handle. A tab container might only care which tab is active. It doesn't care what each tab does with keyboard events. The active tab handles its own messages; the container just routes them.

```ruby
receive_events :"[", :prev_tab
receive_events :"]", :next_tab

only when: -> (_, model) { model.focused? } do
  receive_events :k, :move_up
end

forward_instances_of RatatuiRuby::Event::Resize, broadcast: true

otherwise route_to: :counter_tab, when: -> (_, model) { model.active_tab == :counter }
otherwise route_to: :color_tab, when: -> (_, model) { model.active_tab == :color }
otherwise route_to: :dashboard

Update = from_router
```

The semantics are precise:

- `:[` and `:]` are handled by receive. Never falls through.
- `:k` when `model.focused?` is true → handled by receive.
- `:k` when `model.focused?` is false → guard fails, falls through to `otherwise`.
- `:resize` is handled by forward. Never falls through.
- Any other message when `:counter` active → first `otherwise` with matching guard.
- Any other message when `:color` active → second `otherwise` with matching guard.
- Any other message with neither active → catch-all `otherwise` routes to `:dashboard`.

This keeps the outer fragment's router minimal. It declares what it handles; everything else flows to the nested fragment.

### Deep Hierarchies

For deeply nested fragments, use `otherwise` at each level. Messages flow inward until something handles them.

Root handles tab switching and forwards everything else to the active tab:

```ruby
receive_events :"[", :prev_tab
receive_events :"]", :next_tab
otherwise route_to: :active_tab
```

The Tab fragment handles form submission and forwards everything else to the active panel:

```ruby
receive_events :enter, :submit_form
otherwise route_to: :active_panel
```

The Panel fragment handles toggles and forwards everything else to the active field:

```ruby
receive_events :space, :toggle
otherwise route_to: :active_field
```

The Field fragment is a leaf. It handles everything that made it this far. There is no `otherwise` because nothing is nested below it. A catch-all receive handles character insertion:

```ruby
receive_events :backspace, :delete_char

receive -> (msg, _) { msg.key? && msg.text? },
  -> (msg, model) { model.with(buffer: model.buffer + msg.char) }
```

Each level declares one line: `otherwise route_to: :nested`. For 15 levels, that's 15 one-liners across the whole app. Not 15 levels of explicit per-message routing.

This is declarative message drilling. The Router automates the forwarding you'd otherwise write manually. You don't need event buses, and there are no hidden dependencies. Fragments declare "I don't handle this, pass it down," and the Router does so.

---

## Message Processing Order

The router runs handlers in three phases, regardless of declaration order. First, every matching `observe` handler runs in the order you declared them. Model changes carry forward from one observer to the next. Each observer's commands dispatch independently. The runtime does not group them into a `Message::Batch`. Second, the router tries `intercept*` and `receive*` handlers in declaration order. The first match handles the message; no later intercept or receive runs. Third, if nothing intercepted or received the message, the router tries `forward*` handlers in declaration order, then falls through to `otherwise`.

---

## Generating Update

**`from_router`** generates the Update lambda:

```ruby
Update = from_router
```

The generated Update:
1. Routes prefixed messages to nested fragments
2. Handles events via intercept/forward declarations
3. Returns model unchanged for unhandled messages

---

## Outward Communication

Nested fragments send data outward using commands:

**`Rooibos::Command.bubble(message)`** sends a message outward through the fragment hierarchy. Each outer fragment gets a chance to handle it: update their state, modify it, or let it continue. Use bubble when intermediate fragments need to react.

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

Custom messages enable type checks like `message.leaf_reset?`. Use them in forward declarations or manual Update functions.

In a nested fragment's Update, check a threshold condition and send a message outward:

```ruby
if new_count >= 10
  message = LeafReset.new(envelope: model.name.to_sym, count: new_count)
  [model.with(count: 0), Rooibos::Command.deliver(message)]
else
  model.with(count: new_count)
end
```

In an outer fragment, observe the bubbled message to update local state:

```ruby
observe_instances_of LeafReset,
  -> (msg, model) { model.with(resets: model.resets + 1) }
```

### Semantic Transformation (Intercept + Re-bubble)

When a bubbled message needs transformation before continuing, intercept it and re-bubble a new message. For example, a Panel intercepts `LeafReset`, transforms it to `PanelChildReset` with added context, and re-bubbles:

```ruby
intercept_instances_of LeafReset,
  -> (msg, model) {
    transformed = PanelChildReset.new(envelope: model.name, leaf: msg.envelope, count: msg.count)
    [model.with(nested_resets: model.nested_resets + 1), Rooibos::Command.bubble(transformed)]
  }
```

This pattern lets intermediate fragments add context or aggregate information while preserving the outward flow.

### Bubble with Commands

Sometimes a fragment signals outward AND starts async work. Use `Command.batch` to do both. For example, when a user clicks "Download", bubble a notification to outer fragments while simultaneously starting an HTTP request:

```ruby
if message.download?
  [model.with(downloading: true),
   Rooibos::Command.batch(
     Rooibos::Command.bubble(DownloadStarted.new(filename: model.selected_file)),
     Rooibos::Command.http(download_url, :get)
   )]
end
```

Two things happen:

1. **The bubble** propagates outward. Each outer fragment in the hierarchy gets a chance to `observe` or `intercept` it, from the immediate outer fragment all the way to Root.
2. **The HTTP result** arrives at Root as a message. Use `forward` to route it inward to the fragment that needs it, or handle it directly at Root.

An outer fragment (perhaps several levels up) can observe the bubble:

```ruby
observe_instances_of DownloadStarted,
  -> (msg, model) { model.with(status: "Downloading #{msg.filename}...") }
```

---

## Complete Examples

Two runnable examples demonstrate Router features end-to-end:

- **[Fractal Dashboard](../../examples/app_fractal_dashboard/README.md)** — Async commands,
  `forward_events`, `forward_instances_of`, `otherwise` with guards, modal overlay.
  Includes both a manual and Router variant of the same Update.
- **[Tabbed Fragments](../../examples/app_tabbed_fragments/README.md)** — Multi-level Router
  composition, `bubble`/`deliver`/`intercept`, `forward_routed` with `as:` envelope
  transformation, `observe_instances_of`, `route_to` blocks, and tabbed navigation.

---

## See Also

- [Simple Apps Don't Need Fragments](fragmentless.md)
- [Routerless Composition](routerless.md)
- [Fractal Architecture](fractal_architecture.md)
