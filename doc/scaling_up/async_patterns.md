<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Async Patterns

After reading this guide, you will know:

- How the render loop works and what a frame is
- How to control frame rate with the `fps` parameter
- How command results interleave with terminal events
- How to build smooth animations with `Command.tick`
- How to choose between `tick` (duration-based), `clock` (wall-clock), and per-frame updates
- How to pause expensive work when the terminal loses focus

> ⚠️ **Sections below Frames are stubs.** Help us write them! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).

---

## Frames and the Render Loop

[The Runtime](../essentials/the_runtime.md) explains the contract: you write Init, Update, and View, and the runtime orchestrates them. This section explains the mechanics of that orchestration for developers building animations, real-time features, or performance-sensitive applications.

### What a Frame Is

The runtime runs a loop. Each iteration of the loop is a frame. In each frame, four things happen in order.

First, the runtime calls your View function and renders the result to the terminal. This happens every frame, whether or not anything else happened since the last frame.

Second, the runtime polls for a terminal event from RatatuiRuby. It waits briefly for the user to press a key, click the mouse, or resize the window. If nothing happens within the wait window, the poll returns a `None` event.

Third, the runtime decides whether to call Update with the polled event. Key presses, mouse clicks, resizes, and focus changes always reach Update. `None` events are dropped by default, but applications that need per-frame updates can opt in:

```ruby
Rooibos.run(MyApp, fps: 60, update_every_frame: true)
```

With `update_every_frame: true`, every event reaches Update, including `None`. Without it, idle frames skip Update entirely. View still renders either way.

Fourth, the runtime checks the message queue for completed commands. Timer completions, HTTP responses, and other messages all arrive here. Each one triggers a separate call to Update.

### Controlling Frame Rate

Two parameters control the render loop, both set at startup:

```ruby
Rooibos.run(MyApp, fps: 60, update_every_frame: false)  # defaults
```

`fps` controls how long the runtime waits for a terminal event in each frame. At 60 fps, the runtime waits up to about 16 milliseconds before moving on. A higher value feels more responsive but uses more CPU while idle. A lower value saves resources but may look choppy during animations.

`update_every_frame` controls whether `None` events reach Update. When `false` (the default), Update runs only on real input and command results. When `true`, Update runs on every frame, including idle frames where the user did nothing.

Together they define the runtime's behavior: `fps` sets the cadence, `update_every_frame` decides whether Update keeps pace.

### Terminal Events

Each frame polls exactly one terminal event. The type determines what happens.

`Key`
: The user pressed a key. Update always runs.

`Mouse`
: The user clicked or scrolled. Update always runs.

`Resize`
: The terminal window changed size. Update always runs.

`FocusGained` / `FocusLost`
: The terminal gained or lost focus. Update always runs.

`None`
: The poll timed out. No input arrived. By default, the runtime drops this event and Update does not run. With `update_every_frame: true`, `None` reaches Update like any other event.

`None` events, when enabled, are useful for smooth animations, physics simulations, or any state that changes continuously:

```ruby
receive_events :none,
  ->(_, model) { model.with(frame: model.frame + 1) }
```

> **Warning**: With `update_every_frame: true`, Update runs at the frame rate even when idle. If your Update or any fragment reachable via `otherwise` performs I/O or expensive work, it will execute on every idle frame. Keep Update pure and fast.

### How Messages Fit In

Messages from commands are not frames. They are processed at the end of the current frame, after the poll.

Suppose the user presses `j` during a frame in which a timer and an HTTP response also complete. The runtime calls Update three times in that single frame: once for the key event, once for the timer, once for the HTTP response. Each call receives the model returned by the previous call. The next frame's View renders the final result.

If no events arrive and no commands complete, Update does not run (unless `update_every_frame` is enabled, in which case the `None` event still triggers one call). View renders the same model it rendered last frame.

### View and Update Cadence

View runs every frame, always. At 60 fps, View is called up to 60 times per second even when the user is idle. Keep View fast — build a widget tree and return it. Avoid I/O, state mutation, and side effects in View. If your application feels sluggish, profile View first.

By default, Update runs less often than View. It responds to input and command results, not to the passage of time. With `update_every_frame: true`, Update matches View's cadence — both run on every frame.

### Single-Threaded Safety

The render loop is single-threaded. View, Update, and command dispatch run sequentially within each frame. Commands themselves execute on background threads and deliver results to the message queue.

This means Update never races with View. Your model is always consistent within a frame. You do not need locks, mutexes, or synchronization in your Update or View functions.

---

<!-- STUB: Streaming data from SSE or websockets -->
<!-- STUB: Polling with Command.wait and timers -->
<!-- STUB: Coordinating multiple async sources -->
<!-- STUB: Building animations with Command.tick -->
<!-- STUB: Cleaning up connections on exit -->

---

Related: [The Runtime](../essentials/the_runtime.md) | [Commands](../essentials/commands.md) | [Custom Commands](./custom_commands.md)

---

[**Previous:** Ractor Safety](./ractor_safety.md) | [**Next:** Testing](./testing.md)
