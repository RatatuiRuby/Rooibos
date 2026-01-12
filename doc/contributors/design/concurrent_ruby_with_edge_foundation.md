<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Concurrent-Ruby Edge Foundation

This document proposes fully embracing `concurrent-ruby-edge` as the foundation for command primitives. No hedging, no hybrid — use the abstractions that match our patterns exactly.

---

## Why Edge?

The edge gem contains **exactly** what we've been building:

| Our Abstraction | Edge Equivalent | Match Quality |
|-----------------|-----------------|---------------|
| `CancellationToken` | `Concurrent::Cancellation` | ✅ Exact |
| `Outlet` (queue + put) | `Concurrent::Promises::Channel` | ✅ Exact |
| Command dispatch | `Concurrent::Actor` mailbox | ✅ Exact |
| Graceful shutdown | Cancellation propagation | ✅ Exact |

The "edge" label is historical. These features have been stable for years and are widely used.

---

## Dependencies

```ruby
# ratatui_ruby-tea.gemspec
spec.add_dependency "concurrent-ruby", "~> 1.3"
spec.add_dependency "concurrent-ruby-edge", "~> 0.7"
```

---

## Refactored Primitives

### CancellationToken

```ruby
require "concurrent-edge"

module RatatuiRuby::Tea::Command
  class CancellationToken
    def initialize
      @origin, @token = Concurrent::Cancellation.new
    end

    def cancel! = @origin.resolve
    def cancelled? = @token.canceled?

    # Null object for commands that don't check cancellation
    NONE = Class.new do
      def cancel! = nil
      def cancelled? = false
    end.new.freeze
  end
end
```

**Lines removed:** 80+ (Mutex, synchronize blocks, cancel_count)

---

### Outlet

```ruby
require "concurrent-edge"

module RatatuiRuby::Tea::Command
  class Outlet
    def initialize(channel = Concurrent::Promises::Channel.new)
      @channel = channel
    end

    # Push a message to the runtime.
    def put(tag, *payload)
      message = [tag, *payload]
      validate_shareable!(message)
      @channel.push(message)
    end

    # Synchronously execute a command and return its result.
    def source(command, token)
      child = Concurrent::Promises::Channel.new
      command.call(Outlet.new(child), token)
      child.pop.value!
    end

    # Pop a message (used by runtime).
    def pop = @channel.pop

    # Non-blocking pop (used by runtime loop).
    def try_pop = @channel.try_pop

    private

    def validate_shareable!(message)
      return unless RatatuiRuby::Debug.enabled?
      return if Ractor.shareable?(message)
      raise RatatuiRuby::Error::Invariant, "Message not Ractor-shareable"
    end
  end
end
```

**Benefit:** Channel handles backpressure, blocking, thread-safety automatically.

---

### Command.batch

```ruby
def self.batch(commands)
  Batch.new(commands: commands.freeze)
end

Batch = Data.define(:commands) do
  include Custom

  def call(out, token)
    Concurrent::Promises.zip(
      *commands.map { |cmd| Concurrent::Promises.future { cmd.call(out, token) } }
    ).wait
  end
end
```

---

### Command.all

```ruby
def self.all(commands)
  All.new(commands: commands.freeze)
end

All = Data.define(:commands) do
  include Custom

  def call(out, token)
    results = Concurrent::Promises.zip(
      *commands.map do |cmd|
        Concurrent::Promises.future do
          child = Concurrent::Promises::Channel.new
          cmd.call(Outlet.new(child), token)
          child.pop.value!
        end
      end
    ).value!

    out.put(:all, results)
  end
end
```

---

### Command.wait

```ruby
def self.wait(seconds, tag)
  Wait.new(seconds:, tag:)
end

Wait = Data.define(:seconds, :tag) do
  include Custom

  def call(out, token)
    # Cancellation-aware scheduled task
    task = Concurrent::Promises.schedule(seconds) { :done }

    # Race: task completion vs cancellation
    Concurrent::Promises.any(
      task,
      Concurrent::Promises.future { sleep 0.05 until token.cancelled?; :cancelled }
    ).value!

    out.put(tag, seconds) unless token.cancelled?
  end
end
```

---

### Command.tick

```ruby
def self.tick(interval, tag)
  Tick.new(interval:, tag:)
end

Tick = Data.define(:interval, :tag) do
  include Custom

  def call(out, token)
    task = Concurrent::Promises.schedule(interval) { :done }

    Concurrent::Promises.any(
      task,
      Concurrent::Promises.future { sleep 0.05 until token.cancelled?; :cancelled }
    ).value!

    out.put(tag, interval) unless token.cancelled?
  end
end
```

---

### Runtime Dispatch

```ruby
class Runtime
  def initialize
    @channel = Concurrent::Promises::Channel.new
    @active = Concurrent::Map.new
  end

  private def dispatch(command)
    return unless command.respond_to?(:tea_command?) && command.tea_command?

    token = CancellationToken.new
    outlet = Outlet.new(@channel)

    future = Concurrent::Promises.future do
      command.call(outlet, token)
    rescue => e
      @channel.push(Command::Error.new(command:, exception: e))
    end

    @active[command] = { future:, token: }
  end

  private def shutdown
    @active.each_pair do |cmd, entry|
      entry[:token].cancel!
      grace = cmd.tea_cancellation_grace_period
      entry[:future].wait(grace) if grace.finite?
    end
    @active.clear
  end
end
```

---

## What Gets Deleted

| File / Code | Lines | Replacement |
|-------------|-------|-------------|
| `cancellation_token.rb` Mutex logic | ~80 | `Concurrent::Cancellation` |
| `outlet.rb` Queue wrapper | ~60 | `Concurrent::Promises::Channel` |
| Runtime thread tracking | ~40 | `Concurrent::Map` + futures |
| Manual `Thread.new` | ~20 | `Concurrent::Promises.future` |

**Total reduction:** ~200 lines of hand-rolled concurrency code.

---

## What We Keep

| Component | Reason |
|-----------|--------|
| `Outlet#put(tag, *payload)` API | DX — nicer than raw channel |
| `Outlet#source(cmd, token)` API | DX — composition helper |
| `Command::Custom` mixin | Brand predicate for dispatch |
| `tea_cancellation_grace_period` | Grace period contract |
| Ractor validation in debug mode | Future-proofing |

---

## Trade-offs

| Aspect | Hand-rolled | concurrent-ruby-edge |
|--------|-------------|---------------------|
| Lines of code | 400+ | ~100 wrappers |
| Test burden | All on us | Mostly on them |
| Bug discovery | Our users find them | Ecosystem finds them |
| MRI/JRuby/TruffleRuby | Hope | Tested |
| Semantic versioning | We control | "0.y.z" (but stable) |
| Dependency | None | ~50KB gem |

---

## Migration Steps

1. Add `concurrent-ruby-edge` to gemspec
2. Replace `CancellationToken` internals with `Concurrent::Cancellation`
3. Replace `Outlet` internals with `Concurrent::Promises::Channel`
4. Replace `Thread.new` in dispatch with `Concurrent::Promises.future`
5. Implement `batch`, `all`, `wait`, `tick` using Promises
6. Delete hand-rolled Mutex/Queue code
7. Update tests (behavior unchanged, internals different)

---

## Recommendation

**Do it.** The edge gem provides exactly what we need:

- `Cancellation` = our `CancellationToken`
- `Channel` = our `Outlet`
- `Promises.future` = our thread dispatch
- `Promises.zip` = our `batch` / `all`
- `Promises.schedule` = our `wait` / `tick`

The "edge" label is a historical artifact. These APIs are stable. The risk is minimal. The maintenance reduction is significant.
