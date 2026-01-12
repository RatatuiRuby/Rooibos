<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Concurrent-Ruby Foundation Proposal

This document proposes replacing hand-rolled concurrency primitives with `concurrent-ruby` wrappers, preserving the Outlet/Command DX while eliminating maintenance burden.

---

## Problem Statement

We maintain 400+ lines of concurrency code:

| Component | Lines | Concern |
|-----------|-------|---------|
| `CancellationToken` | 136 | Mutex, null object, thread-safety |
| `Outlet` | 128 | Queue wrapper, Ractor validation |
| `Runtime dispatch` | ~80 | Thread tracking, graceful shutdown |
| Proposed `batch/all/wait/tick/http` | ~300 | More thread coordination |

This code:
- Must be tested across MRI, JRuby, TruffleRuby
- Contains subtle race condition risks
- Duplicates battle-tested concurrent-ruby functionality

---

## Proposal: Wrap concurrent-ruby

Keep the **Outlet DX** (developer experience) but delegate to concurrent-ruby internals.

### Dependency

```ruby
# ratatui_ruby-tea.gemspec
spec.add_dependency "concurrent-ruby", "~> 1.3"
```

Already a transitive dependency via other gems in the Gemfile.lock.

---

## Mapping

| Current / Proposed | concurrent-ruby Equivalent |
|--------------------|---------------------------|
| `CancellationToken` | `Concurrent::Cancellation` (edge) |
| `Outlet` queue | `Concurrent::Promises::Channel` |
| `Command.batch` threads | `Concurrent::Promises.zip` |
| `Command.all` aggregation | `Concurrent::Promises.zip(...).value!` |
| `Command.wait` | `Concurrent::ScheduledTask` |
| `Command.tick` | `Concurrent::TimerTask` |
| Thread pool | `Concurrent::FixedThreadPool` |

---

## Refactored Primitives

### CancellationToken → Concurrent::Cancellation

```ruby
# Before (hand-rolled)
class CancellationToken
  def initialize
    @mutex = Mutex.new
    @cancelled = false
  end
  def cancel! = @mutex.synchronize { @cancelled = true }
  def cancelled? = @mutex.synchronize { @cancelled }
end

# After (wrapper)
require "concurrent-ruby-edge"

class CancellationToken
  def initialize
    @origin, @cancellation = Concurrent::Cancellation.new
  end

  def cancel! = @origin.resolve
  def cancelled? = @cancellation.canceled?

  # Null object compatibility
  NONE = Class.new do
    def cancel! = nil
    def cancelled? = false
  end.new.freeze
end
```

**Benefit:** Concurrent::Cancellation is thread-safe, tested, supports chaining.

---

### Outlet → Channel Wrapper

```ruby
require "concurrent-ruby-edge"

class Outlet
  def initialize(channel = Concurrent::Promises::Channel.new)
    @channel = channel
  end

  def put(tag, *payload)
    message = [tag, *payload]
    validate_ractor_shareable!(message) if RatatuiRuby::Debug.enabled?
    @channel.push(message)
  end

  def source(command, token)
    child_channel = Concurrent::Promises::Channel.new
    child_outlet = Outlet.new(child_channel)
    command.call(child_outlet, token)
    child_channel.pop.value!
  end

  private

  def validate_ractor_shareable!(message)
    return if Ractor.shareable?(message)
    raise RatatuiRuby::Error::Invariant, "Message not Ractor-shareable: #{message.inspect}"
  end
end
```

**Benefit:** Channel handles backpressure, blocking, thread-safety.

---

### Command.batch → Promises.zip

```ruby
def self.batch(commands)
  BatchCommand.new(commands: commands.freeze)
end

BatchCommand = Data.define(:commands) do
  include Command::Custom

  def call(out, token)
    # Each command runs as a future, all dispatch to same outlet
    futures = commands.map do |cmd|
      Concurrent::Promises.future { cmd.call(out, token) }
    end
    # Wait for all to complete
    Concurrent::Promises.zip(*futures).wait
  end
end
```

---

### Command.all → Promises.zip with Aggregation

```ruby
def self.all(commands)
  AllCommand.new(commands: commands.freeze)
end

AllCommand = Data.define(:commands) do
  include Command::Custom

  def call(out, token)
    futures = commands.map do |cmd|
      Concurrent::Promises.future do
        child_channel = Concurrent::Promises::Channel.new
        child_outlet = Outlet.new(child_channel)
        cmd.call(child_outlet, token)
        child_channel.pop.value!
      end
    end

    results = Concurrent::Promises.zip(*futures).value!
    out.put(:all, Ractor.make_shareable(results))
  end
end
```

---

### Command.wait → ScheduledTask

```ruby
def self.wait(seconds, tag)
  WaitCommand.new(seconds:, tag:)
end

WaitCommand = Data.define(:seconds, :tag) do
  include Command::Custom

  def call(out, token)
    task = Concurrent::ScheduledTask.execute(seconds) { :done }

    # Poll for cancellation
    until task.complete?
      return if token.cancelled?
      sleep 0.05
    end

    out.put(tag, seconds) unless token.cancelled?
  end
end
```

---

### Command.tick → TimerTask

```ruby
def self.tick(interval, tag)
  TickCommand.new(interval:, tag:)
end

TickCommand = Data.define(:interval, :tag) do
  include Command::Custom

  def call(out, token)
    # Single tick, then done (update function re-dispatches for loop)
    task = Concurrent::ScheduledTask.execute(interval) { :done }

    until task.complete?
      return if token.cancelled?
      sleep 0.05
    end

    out.put(tag, interval) unless token.cancelled?
  end
end
```

---

### Runtime Dispatch → Thread Pool

```ruby
class Runtime
  def initialize
    @pool = Concurrent::FixedThreadPool.new(10)
    @active_commands = Concurrent::Map.new  # Thread-safe hash
  end

  private def dispatch(command, queue, active_commands)
    return unless command.respond_to?(:tea_command?) && command.tea_command?

    token = CancellationToken.new
    outlet = Outlet.new(queue)

    future = Concurrent::Promises.future_on(@pool) do
      command.call(outlet, token)
    rescue => e
      queue.push(Command::Error.new(command:, exception: e))
    end

    active_commands[command] = { future:, token: }
    future
  end
end
```

---

## What We Keep

| Component | Status |
|-----------|--------|
| `Outlet#put` API | **Keep** — DX layer |
| `Outlet#source` API | **Keep** — DX layer |
| `Command::Custom` mixin | **Keep** — Brand predicate |
| `tea_cancellation_grace_period` | **Keep** — Grace period contract |
| Ractor validation in debug mode | **Keep** — Future-proofing |

---

## What We Remove

| Component | Replaced By |
|-----------|-------------|
| Hand-rolled `Mutex` in CancellationToken | `Concurrent::Cancellation` |
| `Thread.new` everywhere | `Concurrent::Promises.future_on(pool)` |
| Manual thread tracking | Pool + `Concurrent::Map` |
| `pending_threads` array | Futures automatically tracked |

---

## Trade-offs

### Pros

| Benefit | Impact |
|---------|--------|
| Less code to maintain | ~400 lines removed |
| Battle-tested | 10+ years of production use |
| Cross-platform | MRI, JRuby, TruffleRuby tested |
| Thread pool | Better resource management |
| Future chaining | Cleaner composition |

### Cons

| Concern | Mitigation |
|---------|------------|
| Edge gem required | `Cancellation` is in edge; could use stable subset |
| Learning curve | Team must learn concurrent-ruby API |
| Dependency size | Already a transitive dependency |
| API mismatch | Wrapped by our DX layer |

---

## Migration Path

1. **Add dependency** — `concurrent-ruby` (already present), `concurrent-ruby-edge`
2. **Refactor CancellationToken** — Wrap `Concurrent::Cancellation`
3. **Refactor Outlet** — Use `Channel` internally, keep `put`/`source` API
4. **Refactor Runtime dispatch** — Use thread pool + futures
5. **Implement batch/all/wait/tick** — Using `Promises`, `ScheduledTask`
6. **Remove hand-rolled code** — Delete Mutex, manual thread tracking
7. **Update tests** — Verify same behavior

---

## Open Questions

### 1. Edge gem acceptable?

`Concurrent::Cancellation` is in `concurrent-ruby-edge`. Options:

- Accept edge dependency (it's stable, just not "1.0")
- Keep our CancellationToken (it's simple enough)
- Use `Concurrent::AtomicBoolean` for cancellation flag (stable gem)

### 2. Channel vs Queue?

`Concurrent::Promises::Channel` is in edge. Could use:
- `Thread::Queue` (stdlib, current approach)
- `Concurrent::Array` for simple cases
- `Channel` if edge is acceptable

### 3. Pool sizing?

Fixed pool of 10? Cached pool? Configurable? Need benchmarks.

---

## Recommendation

**Hybrid approach:**

| Component | Use |
|-----------|-----|
| Cancellation | Keep ours (simple, 50 lines) |
| Thread dispatch | `Concurrent::Promises.future` (stable gem) |
| Thread pool | `Concurrent::FixedThreadPool` (stable gem) |
| Queue | `Thread::Queue` (stdlib) |
| Timers | `Concurrent::ScheduledTask` (stable gem) |

This uses only the **stable** `concurrent-ruby` gem (no edge), while still gaining:
- Futures for cleaner async
- Thread pool for resource management
- ScheduledTask for timers
- Battle-tested synchronization

We keep our simple CancellationToken and Outlet DX layer.
