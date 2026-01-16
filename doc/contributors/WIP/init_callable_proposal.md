<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Init Callable Architecture Proposal

## Problem Statement

The current codebase has **three different names** for the initial state instance:

1. **`MODEL`** - Used in simple examples (README, verify_readme_usage)
2. **`INITIAL`** - Used in fractal fragments (dashboard examples)
3. **`init:`** - Runtime parameter for startup commands (different semantics)

Additionally, the planned v0.4.0 transition (`INITIAL` → `Initial`) would create visual collision with `Model`, where both look like type names despite having different purposes.

### Current Fragment Pattern

```ruby
module SystemInfo
  Model = Data.define(:output, :loading)
  INITIAL = Model.new(output: "Press 's'", loading: false)  # Static constant
  
  UPDATE = ->(message, model) { ... }
  VIEW = ->(model, tui) { ... }
end
```

### Current Limitations

- **No parameterization**: Child fragments can't receive initialization props from parents
- **Naming confusion**: `Model` (type) vs `INITIAL`/`MODEL` (instance) vs `init:` (command)
- **Static only**: Can't dispatch initial commands alongside state
- **No context**: Root fragments can't access ARGV, ENV, or other runtime context

## Proposed Solution

Replace the static `INITIAL`/`MODEL` constant with an **`Init` callable** that:

1. **Returns `[model, command]`** - Same pattern as `Update`
2. **Accepts flags/props** - Context from parent or runtime
3. **Supports DWIM**: Can return just `model` (no command) like `Update`

### New Fragment Pattern

```ruby
module SystemInfo
  Model = Data.define(:output, :loading)
  
  # Init receives flags from parent, returns [model, command?]
  Init = ->(disabled: false) do
    message = disabled ? "(disabled)" : "Press 's' for system info"
    [Model.new(output: message, loading: false), nil]
  end
  
  Update = ->(message, model) { ... }
  View = ->(model, tui) { ... }
end
```

### Root Fragment with Runtime Context

```ruby
module App
  Model = Data.define(:user_name, :debug_mode, :data)
  
  Init = ->(argv:, env:) do
    debug = env['DEBUG'] == '1'
    name = argv[0] || env['USER'] || 'guest'
    
    model = Model.new(user_name: name, debug_mode: debug, data: nil)
    command = Command.http(:get, "/api/startup", :initial_data)
    
    [model, command]
  end
  
  Update = ->(message, model) { ... }
  View = ->(model, tui) { ... }
end
```

### Fractal Composition

```ruby

module Dashboard
  Model = Data.define(:stats, :network, :theme)

  Init = ->(theme: :dark, env:) do
    # Parent can pass props to children
    stats_model, stats_cmd = StatsPanel::Init.(theme: theme)
    network_model, network_cmd = NetworkPanel::Init.(theme: theme)

    model = Model.new(stats: stats_model, network: network_model, theme: theme)
    command = Command.batch(
      Rooibos.route(stats_cmd, :stats),
      Rooibos.route(network_cmd, :network)
    )

    [model, command]
  end

  Update = from_router
  View = ->(model, tui) { ... }
end
```

## Benefits

### 1. Eliminates Naming Confusion

| Current (3 names) | Proposed (1 name) |
|-------------------|-------------------|
| `Model` (type) | `Model` (type) |
| `INITIAL` or `MODEL` (instance) | `Init` (callable) |
| `init:` (runtime param) | `init:` (runtime param) |

### 2. Enables Parameterization (React-Style Props)

Parents can pass configuration to children:

```ruby
# Parent decides child's theme, debug mode, etc.
child_model, child_cmd = ChildFragment::Init.(theme: :light, debug: true)
```

### 3. Unifies Initialization Pattern

Both `Init` and `Update` now follow the same signature:

```ruby
Init   :: (flags)            -> [Model, Command?]
Update :: (Message, Model) -> [Model, Command?]
```

### 4. Supports Initial Commands

No need for separate `init:` runtime parameter pattern:

```ruby
# Old way
INITIAL = Model.new(data: nil)
Rooibos.run(model: INITIAL, init: -> { fetch_data_command })

# New way
Init = -> { [Model.new(data: nil), fetch_data_command] }
Rooibos.run(fragment: MyApp) # Init is called automatically
```

### 5. Access to Runtime Context

Root fragments can inspect ARGV, ENV, config files, etc.:

```ruby
Init = ->(argv:, env:) do
  config = parse_config(argv[0]) if argv[0]
  # ...
end
```

## Migration Path

### Phase 1: Introduce `Init` alongside `INITIAL`

Both patterns work during transition:

```ruby
# Old style (deprecated)
INITIAL = Model.new(...)

# New style (preferred)
Init = -> { Model.new(...) }
```

### Phase 2: Runtime Changes

```ruby
# Current
Rooibos.run(model: Fragment::INITIAL, view: Fragment::VIEW, update: Fragment::UPDATE)

# Transitional (supports both)
Rooibos.run(fragment: Fragment) # Calls Fragment::Init
# OR
Rooibos.run(model: initial_model, view: view, update: update) # Old style

# Future
Rooibos.run(fragment: Fragment, argv: ARGV, env: ENV)
```

### Phase 3: DSL for Fractal Composition

Router could auto-call child `Init`:

```ruby

module Dashboard
  include Rooibos::Router

  # Automatically calls StatsPanel::Init and NetworkPanel::Init
  mount :stats, fragment: StatsPanel, theme: :dark
  mount :network, fragment: NetworkPanel, theme: :dark

  Update = from_router
end
```

## Open Questions

### 1. Fragment Signature

What constants are required?

**Option A: All four**
```ruby
Model, Init, Update, View  # Complete fragment
```

**Option B: Flexible**
```ruby
Model, Update, View  # No Init = empty model
Model, Init          # View-less (backend fragment?)
```

### 2. Init Return Type DWIM

How flexible should the return be?

```ruby
Init = -> { Model.new(...) }                    # Just model, no command
Init = -> { [Model.new(...), nil] }             # Explicit tuple
Init = -> { [Model.new(...), some_command] }    # With command
```

### 3. Backward Compatibility

**Breaking or transitional?**

- **Option A**: v0.5.0 breaking change, remove `INITIAL` support entirely
- **Option B**: v0.4.x transitional, support both patterns with deprecation warnings
- **Option C**: v0.4.x additive, keep `INITIAL` forever, `Init` is optional

### 4. Runtime API

**How does `Rooibos.run` change?**

```ruby
# Current
Rooibos.run(model: initial, view: view, update: update, init: startup_cmd)

# Proposed Option 1: Fragment-first
Rooibos.run(fragment: App, argv: ARGV, env: ENV)

# Proposed Option 2: Hybrid
Rooibos.run(fragment: App) # Uses App::Init
# OR
Rooibos.run(model: model, view: view, update: update) # Old style still works
```

### 5. Router DSL Integration

Should `route :child, to: ChildFragment` auto-initialize?

```ruby
# Manual (explicit control)
route :child, to: ChildFragment
Init = ->(theme:) do
  child_model, child_cmd = ChildFragment::Init.(theme: theme)
  [Model.new(child: child_model), Rooibos.route(child_cmd, :child)]
end

# Automatic (magic convenience)
mount :child, fragment: ChildFragment, theme: :dark # Auto-calls Init
```

## Implementation Sketch

### Runtime Changes

```ruby
module Rooibos
  def self.run(fragment: nil, model: nil, view: nil, update: nil, argv: [], env: {})
    if fragment
      # New style: fragment-first
      init_result = fragment::Init.call(argv: argv, env: env)
      model, init_cmd = normalize_update_result(init_result)
      view = fragment::View
      update = fragment::Update
    else
      # Old style: explicit model/view/update
      # (backward compatible)
    end
    
    Runtime.run(model: model, view: view, update: update, init: init_cmd)
  end
end
```

### Fragment Helpers

```ruby

module Rooibos::Fragment
  # Normalize Init or Update return values
  def self.call_init(fragment, **flags)
    result = fragment::Init.call(**flags)
    normalize(result)
  end

  def self.normalize(result)
    case result
    in [model, command] then [model, command]
    in model then [model, nil]
    end
  end
end
```

## Recommendation

I think this is a **excellent** direction because:

1. ✅ **Solves the naming collision** completely
2. ✅ **Enables parent-to-child props** (long-standing limitation)
3. ✅ **Unifies Init and Update patterns** (both return tuples)
4. ✅ **Removes runtime context limitations** (ARGV, ENV access)
5. ✅ **Simplifies the "what's my initial command?" pattern**

### Suggested Approach

1. **v0.4.x**: Introduce `Init` as **optional**, keep `INITIAL` support
2. **Document the pattern** with examples and migration guide
3. **Add Router DSL sugar** for `mount :child, fragment: ChildFragment, props...`
4. **v0.5.0**: Deprecate `INITIAL`, make `Init` required

This gives users time to migrate while immediately solving the parameterization problem for new code.

## Next Steps

1. Get user feedback on this proposal
2. Prototype the runtime changes
3. Convert one example (fractal dashboard) to new pattern
4. Document the full API and migration path
