<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Message Processing

The runtime processes messages one at a time.

You build interactive apps. Events arrive from everywhere: keyboard, mouse,
timers, HTTP responses. Coordinating concurrent results feels complex.

TEA handles the concurrency. Your `update` function handles exactly one message
per invocation. The runtime schedules everything else.

## Recurring Ticks

For animations or polling, re-dispatch the tick in your update function:

```ruby
def update(msg, model)
  case msg
  when [:tick, _elapsed]
    [model.with(frame: model.frame + 1), Command.tick(0.016, :tick)]
  end
end
```

Can a tick and a keyboard event arrive at the same time?

No. The runtime serializes all messages. Each frame, it polls for user input,
calls `update` with any event it finds, and dispatches the returned command.
Then it drains the background channel, calling `update` once for each queued
message. Two events that occur in the same frame become two sequential calls.
Each returns its own command. They never collide.

## When to Use Command.batch

Use `Command.batch` when a single message triggers multiple effects:

```ruby
when :init
  [model, Command.batch(
    Command.tick(0.016, :tick),
    Command.http(get: "/api/data", :loaded)
  )]
```

This differs from "two messages arrived simultaneously." Here, you send two
commands at once. Even if both complete in exactly the same time, their results
arrive as two distinct calls to `update`.
