<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Commands

After reading this guide, you will know:

- How commands express side effects without breaking Update purity
- How to choose the right built-in command (`system`, `exit`, `wait`, `tick`, `clock`, `random`, `http`, `batch`, `all`, `cancel`)
- How the command lifecycle works: dispatch → execute → message
- How to combine multiple commands with `Command.batch`
- How `Command.clock` provides wall-clock time for pure Update functions
- How `Command.random` provides randomness without calling `Kernel.rand`

> ⚠️ **Sections above this line are stubs.** Help us write them! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).

---

<!-- STUB: Context, Problem, Solution intro -->
<!-- STUB: Command lifecycle (dispatch → execute → message) -->
<!-- STUB: Command.exit -->
<!-- STUB: Command.batch and Command.all -->
<!-- STUB: Command.cancel -->
<!-- STUB: Command.http -->

---

## Timers and Delays

### `Command.wait`

Schedule a one-shot delay. After `seconds` elapse, your Update receives a `Message::Timer` with the envelope you chose:

```ruby
# Dismiss a notification after 3 seconds
[model.with(notification: "Deleted!"), Command.wait(3.0, :dismiss)]
```

```ruby
# Handle the timer in Update:
case message
in { type: :timer, envelope: :dismiss }
  model.with(notification: nil)
end
```

`Message::Timer` has two members:

`envelope`
: The symbol you passed to `wait`. Use it to distinguish multiple timers.

`elapsed`
: How long the timer actually waited (a `Float` in seconds). Useful for animation frame timing.

### `Command.tick`

Alias for `Command.wait`. Use `tick` when the name better fits your intent (e.g. animation loops, periodic polling, heartbeats):

```ruby
# Animation loop: advance frame every 100ms
[model.with(frame: next_frame), Command.tick(0.1, :animate)]
```

Re-issue the tick in your Update to create a repeating loop. Because your Update controls the re-issue, it can also change the interval or stop the loop entirely.

> **Tip**: `wait` and `tick` are identical. Choose the name that reads best. Use `tick` for "do something repeatedly," and re-issue the command in your Update. Use `wait` for "do something after a delay," and don't re-issue the command.

---

## Wall-Clock Time

### `Command.clock`

Apps that display the time, throttle refreshes, or show "last updated 30 seconds ago" need the wall clock. But `Time.now` is a side effect. Calling it in Update makes the function non-deterministic — the same model and message produce different results depending on when you call them.

`Command.clock` solves this. It works like `tick`, but the resulting message carries the current time instead of the elapsed duration.

```ruby
Init = -> {
  model = Model.new(current_time: nil, last_refresh: nil)
  [model, Command.clock(1, :clock)]
}
```

The first argument is the delay in seconds. The second is the envelope, used to identify the clock in your Update.

Your Update receives a `Message::Clock`:

```ruby
case message
in { type: :clock, envelope: :clock, time: }
  # `time` is a Time object — the wall-clock time when the message fired
  [model.with(current_time: time.getutc.to_s),
   Command.clock(1, :clock)]  # re-issue for next tick
end
```

`Message::Clock` has two members:

`envelope`
: The symbol you passed to `clock`.

`time`
: A `Time` object. The wall-clock time at the moment the clock fired.

### Clock vs. Tick

| | `Command.tick` | `Command.clock` |
|---|---|---|
| **Answers** | "Has enough time passed?" | "What time is it?" |
| **Message** | `Message::Timer` | `Message::Clock` |
| **Members** | `elapsed` (duration) | `time` (wall clock) |
| **Use for** | Animation, debounce, delays | Displaying time, throttling, scheduling |

Use `tick` when you care about duration. Use `clock` when you care about the time.

### Example: "Last Modified" Display

A file browser that shows how long ago the selected file was modified:

```ruby
require "action_view"

Update = ->(message, model) {
  case message
  in { type: :clock, envelope: :clock, time: }
    [model.with(now: time), Command.clock(1, :clock)]
  # ... other handlers
  end
}

View = ->(model, tui) {
  ago = distance_of_time_in_words(model.selected_file.mtime, model.now)
  tui.paragraph(text: "Modified #{ago} ago")
}
```

The time arrives as data in the message. View reads it from the model. No side effects in either function.

> **Note**: `Command.clock` is Rooibos's equivalent of Elm's `Time.every`. The runtime calls `Time.now` when constructing the message, so your Update never needs to.

---

## Random Values

### `Command.random`

`Kernel#rand` and `Random` are side effects. Calling them in Update means the same model and message produce different results on each call. `Command.random` delegates to Ruby's `Random` class through the runtime, so your Update stays pure.

The last argument is always the envelope. Everything before it maps to `Random`:

```ruby
Command.random(:shuffle_files)
```

The runtime generates the value and sends a `Message::Random`:

```ruby
case message
in { type: :random, envelope: :shuffle_files, value: }
  model.with(sort_seed: value)
end
```

### Matching Ruby's `Random` API

Without a leading symbol, `Command.random` calls `Random#rand`. The arguments before the envelope are passed through:

```ruby
# rand → Float 0.0..1.0
Command.random(:spawn_chance)

# rand(max) → Integer 0..max-1
Command.random(52, :deal_card)

# rand(range) → Integer in range
Command.random(1..6, :roll_die)

# rand(float_range) → Float in range
Command.random(5.0..9.0, :x_position)
```

These return a `Message::Random` with two members:

`envelope`
: The symbol you passed as the last argument.

`value`
: The return value from `Random#rand`. A Float, Integer, or member of the range you specified.

With a leading symbol, `Command.random` calls that method on `Random` instead. This works like `public_send`:

```ruby
# bytes(n) → String of n random bytes
Command.random(:bytes, 16, :raw_key)

# urandom(n) → String of n cryptographically secure bytes
Command.random(:urandom, 32, :secure_token)

# seed → Integer (current PRNG seed)
Command.random(:seed, :current_seed)

# new_seed → Integer (fresh seed value)
Command.random(:new_seed, :fresh_seed)
```

`Random#rand` never takes a symbol as its first argument, so there is no ambiguity. A leading symbol is always a method name.

All variants return `Message::Random`.

### Testing

Random commands are testable because you construct the message directly:

```ruby
def test_deal_card
  message = Message::Random.new(envelope: :deal_card, value: 7)
  new_model, _cmd = Game::Update.call(message, model)

  assert_equal DECK[7], new_model.hand.last
end
```

No `srand`. No mocking. Build the message with the value you want, assert what Update does with it.

> **Tip**: If you need multiple random values, issue multiple `Command.random` calls via `Command.batch`. Each arrives as a separate message. Use `Command.all` if you need all values to arrive together.

---

<!-- STUB: Command comparison table (all built-ins at a glance) -->
<!-- STUB: Summary -->

---

Related: [The Runtime](./the_runtime.md) | [Update Functions](./update_functions.md) | [Async Patterns](../scaling_up/async_patterns.md)

---

[**Previous:** Views](./views.md) | [**Next:** The Runtime](./the_runtime.md)
