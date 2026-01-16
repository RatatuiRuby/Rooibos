<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Init Callable Implementation Plan

## Problem Statement

The current codebase uses **three different names** for initial state:
- `MODEL` (simple examples: README, verify_readme_usage)
- `INITIAL` (fractal fragments: dashboard examples)  
- `init:` (runtime parameter with different semantics)

The planned v0.4.0 transition (`INITIAL` → `Initial` PascalCase) would create visual collision with `Model`, where both look like type names despite different purposes (type vs instance).

**Critical Finding**: Research of 15+ MVU/TEA frameworks shows **zero** use static constants for initialization. All use callables/functions.

## Solution: Init Callable

Replace static `INITIAL`/`MODEL` constants with `Init` callable that:
1. Returns `[model, command]` tuple (or DWIM variants)
2. Accepts flags/props for parameterization
3. Enables parent-to-child initialization data flow
4. Supports initial command dispatch alongside state

## Proposed Changes

### Core API

#### Fragment Structure (v0.4.0)
```ruby
module MyFragment
  Model = Data.define(:field1, :field2)
  
  # NEW: Init callable (optional, defaults to Model.new)
  Init = ->(flags_hash = {}) do
    model = Model.new(...)
    command = some_initial_command  # or nil
    [model, command]
  end
  
  Update = ->(message, model) { ... }
  View = ->(model, tui) { ... }
end
```

#### DWIM Return Values
```ruby
# All valid return formats:
Init = -> { Model.new(...) }                    # Just model
Init = -> { [Model.new(...), nil] }             # Explicit tuple, no command
Init = -> { [Model.new(...), some_cmd] }        # With command
Init = -> { Command.exit }                      # Just command (edge case)
```

#### Normalization Helper
```ruby
module Rooibos
  # Normalize Init return to [model, command] tuple
  # Uses DWIM logic like Update (rooibos_command? detection)
  def self.normalize_init(result)
    case result
    when Command then [nil, result]           # Just command
    in [model, command] then [model, command] # Already tuple
    else
      if result.respond_to?(:rooibos_command?) && result.rooibos_command?
        [nil, result]                         # Command without array wrapper
      else
        [result, nil]                         # Just model
      end
    end
  end
end
```

---

### Fractal Composition

#### Parent Init Calls Child Init

```ruby

module Dashboard
  Model = Data.define(:stats, :network, :theme)

  Init = ->(theme: :dark, env: {}) do
    # Call child Inits with props
    stats_model, stats_cmd = StatsPanel::Init.(theme: theme)
    network_model, network_cmd = NetworkPanel::Init.(theme: theme)

    model = Model.new(
            stats: stats_model,
            network: network_model,
            theme: theme
    )

    command = Command.batch(
            Rooibos.route(stats_cmd, :stats),
            Rooibos.route(network_cmd, :network)
    )

    [model, command]
  end

  # View composition - UNCHANGED (still manual)
  View = ->(model, tui) do
    tui.vertical_layout(
            children: [
                    StatsPanel::View.call(model.stats, tui),
                    NetworkPanel::View.call(model.network, tui)
            ]
    )
  end

  # Update routing - UNCHANGED (Router DSL)
  include Rooibos::Router
  route :stats, to: StatsPanel
  route :network, to: NetworkPanel
  Update = from_router
end
```

**Key Point**: Only `Update` uses Router DSL. `Init` and `View` remain explicit/manual composition.

---

### Runtime Integration

#### Current API (Backward Compatible)

```ruby
# Still works (old style)
Rooibos.run(
        model: MyApp::INITIAL,
        view: MyApp::VIEW,
        update: MyApp::UPDATE
)
```

#### New API (Fragment-First)

```ruby
# New style (preferred)
Rooibos.run(
        fragment: MyApp,
        argv: ARGV,
        env: ENV
)

# Equivalent to:
# model, init_cmd = MyApp::Init.(argv: ARGV, env: ENV)
# Rooibos.run(model: model, view: MyApp::View, update: MyApp::Update, init: init_cmd)
```

#### Runtime Implementation
```ruby
module Rooibos
  def self.run(fragment: nil, model: nil, view: nil, update: nil, argv: [], env: {}, init: nil)
    if fragment
      # New style: fragment-first
      init_callable = fragment.const_defined?(:Init) ? fragment::Init : -> { fragment::Model.new }
      init_result = init_callable.call(argv: argv, env: env)
      model, init_cmd = normalize_init(init_result)
      view = fragment::View
      update = fragment::Update
      init = init_cmd  # Override init param with Init-generated command
    else
      # Old style: explicit parameters (backward compatible)
      # model, view, update, init already provided
    end
    
    Runtime.run(model: model, view: view, update: update, init: init)
  end
end
```

---

## Migration Strategy

### v0.4.0: Breaking Change (Zero Users, Zero Cruft)

Since the project has **zero external users**, we will make this a **breaking change in v0.4.0**:

- ✅ `Init` callable is the **only** way to define initial state
- ❌ `INITIAL` and `MODEL` constants are **removed** (no backward compatibility)
- ✅ `Init` is **optional** (defaults to `-> { Model.new }` if not defined)
- ✅ All examples and documentation use `Init` pattern
- ✅ Clean slate, no migration debt

**Rationale**: Adding backward compatibility for a non-existent user base creates unnecessary code complexity and testing burden. Break now while we can.

---

## Implementation Checklist

### Core Implementation
- [ ] **`Rooibos.normalize_init` helper**
  - [ ] Implement DWIM logic with `rooibos_command?` detection
  - [ ] Handle all return formats: model, command, `[model, cmd]`
  - [ ] Tests for all DWIM variants
  
- [ ] **Runtime changes**
  - [ ] Add `fragment:`, `argv:`, `env:` parameters to `Rooibos.run`
  - [ ] Auto-call `fragment::Init` when `fragment:` provided
  - [ ] Default `Init` to `-> { Model.new }` if not defined
  - [ ] Maintain backward compatibility with `model:`/`view:`/`update:` params
  - [ ] Tests for both old and new API styles

### Example Migrations
- [ ] **Simple example** (verify_readme_usage)
  - [ ] Replace `MODEL` constant with `Init` callable
  - [ ] Update README code samples
  - [ ] Verify tests still pass
  
- [ ] **Fractal example** (app_fractal_dashboard)
  - [ ] Convert all fragment `INITIAL` to `Init`
  - [ ] Update parent Init to call child Inits with props
  - [ ] Compose initial commands with `Command.batch`
  - [ ] Verify all dashboard variants (base, router, manual, helpers) work

### Documentation
- [ ] **Update AGENTS.md**
  - [ ] Change Fragment definition to use `Init` instead of `INITIAL`
  - [ ] Update terminology section
  
- [ ] **Create concept documentation files**
  - [ ] `doc/init.md` (full documentation)
    - [ ] Follow documentation style guide (Alexandrian Context-Problem-Solution)
    - [ ] Explain what Init is and why it exists (vs static constants)
    - [ ] Document Init at root level (runtime integration)
    - [ ] Document Init at non-root level (fractal composition)
    - [ ] Show parameterization with flags/props
    - [ ] Document DWIM return values
    - [ ] Show Rooibos.normalize_init usage
    - [ ] Multiple complete examples (simple, fractal, with commands)
    - [ ] Link to related concepts (Fragment, Model, Update, Command)
  - [ ] Create stubs for concept doc series (H1 + "TODO" only):
    - [ ] `doc/fragment.md`
    - [ ] `doc/model.md`
    - [ ] `doc/view.md`
    - [ ] `doc/update.md`
    - [ ] `doc/command.md`
    - [ ] `doc/message.md`
    - [ ] `doc/output.md`
  
- [ ] **Update design_for_v0.4.0.md**
  - [ ] Add Init Callable section
  - [ ] Document DWIM behavior
  - [ ] Document `Rooibos.normalize_init` helper
  - [ ] Add footnote on Iced pattern inspiration
  - [ ] Add footnote on OutMsg pattern (future consideration)
  
- [ ] **Create migration guide**
  - [ ] Before/after examples
  - [ ] Deprecation timeline
  - [ ] Common patterns
  
- [ ] **Update RDoc**
  - [ ] Document `Rooibos.normalize_init`
  - [ ] Document new `Rooibos.run` signature
  - [ ] Update Fragment examples throughout

### RBS Type Signatures
- [ ] **Update Rooibos module RBS**
  ```ruby
  module Rooibos
    def self.run: (
      ?fragment: Module,
      ?model: untyped,
      ?view: ^(untyped, untyped) -> Widget,
      ?update: ^(untyped, untyped) -> untyped,
      ?init: ^() -> untyped,
      ?argv: Array[String],
      ?env: Hash[String, String]
    ) -> void
    
    def self.normalize_init: (untyped result) -> [untyped, Command?]
  end
  ```

### Testing
- [ ] **Unit tests for `Rooibos.normalize_init`**
  - [ ] Returns `[model, nil]` for model-only
  - [ ] Returns `[nil, cmd]` for command-only
  - [ ] Returns `[model, cmd]` for tuple
  - [ ] Handles `rooibos_command?` detection
  
- [ ] **Integration tests for `Rooibos.run`**
  - [ ] Fragment-first API works
  - [ ] Old API still works (backward compat)
  - [ ] Init commands are dispatched
  - [ ] ARGV/ENV passed to Init
  - [ ] Default Init works when not defined
  
- [ ] **Fractal composition tests**
  - [ ] Parent Init calls child Inits
  - [ ] Props passed to children
  - [ ] Commands batched correctly
  - [ ] Router still routes messages correctly

### CHANGELOG
- [ ] Add to `[UNRELEASED]` section:
  ```markdown
  ### Breaking Changes
  - **REMOVED**: `INITIAL` and `MODEL` constants
    - Use `Init` callable instead: `Init = -> { [Model.new(...), nil] }`
    - `Init` is optional (defaults to `-> { Model.new }`)
  
  ### Added
  - **Init Callable Pattern**: Fragments support `Init` callable for parameterized initialization
    - Returns `[model, command]` tuple (DWIM supported)
    - Accepts flags/props for parent-to-child data flow
    - `Rooibos.normalize_init` helper for composing child Inits
  - **Fragment-First Runtime API**: `Rooibos.run(fragment: MyApp, argv: ARGV, env: ENV)`
  - **Concept Documentation**: Created `doc/init.md` and series stubs
  ```

---

## Breaking Changes

**v0.4.0 is a BREAKING RELEASE**:

- ❌ **REMOVED**: `INITIAL` and `MODEL` constants (use `Init` callable instead)
- ✅ **NEW**: `Init` callable is the only supported initialization pattern
- ✅ **NEW**: Runtime `fragment:` parameter for fragment-first API

**Rationale**: Zero external users means zero migration burden. Ship clean architecture without legacy cruft.

---

## Open Questions

None - all design decisions finalized with user.

---

## Design Notes (Contributor Reference)

### Concept Documentation Series

`doc/init.md` is the **first** in a series of concept documentation pages, one for each core TEA concept:
- `doc/init.md` (this implementation)
- `doc/fragment.md` (future)
- `doc/model.md` (future)
- `doc/view.md` (future)
- `doc/update.md` (future)
- `doc/command.md` (future)
- `doc/message.md` (future)
- `doc/output.md` (future)

Each follows the Alexandrian Context-Problem-Solution pattern per `doc/contributors/documentation_style.md`.

### Why Not Auto-Init in Router DSL?

The Router DSL is **message-only** by design. It handles `Update` function routing, not initialization or view composition:

```ruby
route :stats, to: StatsPanel  # Only routes messages to StatsPanel::Update
```

Both `Init` and `View` remain **explicit composition** (manual), which provides:
- ✅ Full control over initialization order and props
- ✅ Clear, explicit data flow
- ✅ Flexibility for conditional initialization
- ✅ Consistency with View composition pattern

### Terminology Inspirations

This pattern draws from multiple proven MVU implementations:
- **Elm**: `init : () -> (Model, Cmd Msg)` tuple return
- **Iced (Rust)**: `fn new(flags: Flags) -> (State, Command)` parameterized init
- **Bubble Tea (Go)**: `func (m Model) Init() tea.Cmd` method-based init
- **Hyperapp (JS)**: `init: [state, ...effects]` array-based DWIM

See `doc/contributors/mvu_research_notes.md` for detailed analysis.

### Future: OutMsg Pattern

Elm's "Translator Pattern" / "OutMsg Pattern" allows children to emit events to parents beyond state updates. Not needed for v0.4.0, but may be considered for future:

```ruby
# Potential future enhancement
Update = ->(msg, model) do
  case msg
  in [:data_loaded, data]
    [[model.with(data: data), nil], [:parent_event_here]]
    #                                 ^^^^^^^^^^^^^^^^^^^^ OutMsg for parent
  end
end
```

See `doc/contributors/outmsg_pattern_notes.md` for details.

---

## Success Criteria

- [ ] All existing tests pass
- [ ] `bundle exec agent_rake` passes (0 warnings)
- [ ] Both old and new API styles work
- [ ] Fractal dashboard example uses Init pattern
- [ ] Simple example uses Init pattern
- [ ] Documentation is comprehensive and clear
- [ ] Migration path is documented
