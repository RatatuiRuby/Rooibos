<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Maybe: Stateful Router

**Status:** Not implemented — noted for future consideration.

## Problem

Current routed actions require the parent fragment's model to hold child fragments' models (e.g., `model.file_list`). The Router then needs to know which field name to use when dispatching to children and updating the parent model.

This couples the Router to the parent's model structure.

## Proposed Alternative

Make the Router stateful, holding child fragment models internally:

```ruby
module ClassMethods
  def route(prefix, to:)
    # Router would also initialize and store child model
    child_model, init_command = to.const_get(:Init).()
    routed_models[prefix] = child_model
    routes[prefix] = to
  end
end
```

## Pattern Symmetry

This mirrors the architecture at every level:

| Component | Holds Model | Calls Update |
|-----------|-------------|--------------|
| Runtime   | Root model  | Root Update  |
| Router    | Child models| Child Updates|

## Pros

- Parent fragment doesn't need nested model composition
- Router becomes a true "mini-runtime" for children
- Enables features like broadcasting resize events to all children
- Parent's Update is simpler — just handles its own concerns

## Cons

- Breaks from strict Elm pattern where parent Model contains child Models
- Router becomes stateful (but Runtime already is)
- Initialization order requires careful thought
- View needs a different way to access child models for rendering

## Decision

Deferred. Current implementation requires parent to hold child models, which follows canonical Elm patterns. The stateful router approach is coherent but would be a significant architectural change.
