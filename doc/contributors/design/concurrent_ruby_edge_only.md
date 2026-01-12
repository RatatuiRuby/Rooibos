<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Concurrent-Ruby Edge Only

No wrappers. No Outlet. No CancellationToken. App developers use concurrent-ruby-edge directly.

---

## The Radical Proposal

Drop all abstractions. Tea exposes concurrent-ruby-edge directly:

```ruby
# Commands receive Channel and Cancellation, not Outlet and Token
class FetchUserCommand
  include Tea::Command::Custom

  def call(channel, cancellation)
    user = API.fetch_user(@id)
    channel.push([:user_fetched, user:])
  end
end
```

---

## What Gets Deleted

| Component | Status |
|-----------|--------|
| `Command::Outlet` | **Deleted** — use `Concurrent::Promises::Channel` |
| `Command::CancellationToken` | **Deleted** — use `Concurrent::Cancellation` |
| `Outlet#put(tag, *payload)` | **Deleted** — use `channel.push([tag, *payload])` |
| `Outlet#source(cmd, token)` | **Deleted** — inline pattern |
| Ractor validation | **Deleted** — not our problem |

---

## The New Command Interface

```ruby
module Tea::Command
  module Custom
    def tea_command? = true
    def tea_cancellation_grace_period = 2.0
  end
end

# sig/command.rbs
interface _Command
  def tea_command?: () -> true
  def tea_cancellation_grace_period: () -> Float
  def call: (Concurrent::Promises::Channel, Concurrent::Cancellation) -> void
end
```

---

## App Developer Code

### Before (with Outlet)

```ruby
class FetchUserCommand
  include Tea::Command::Custom

  def call(out, token)
    return if token.cancelled?
    user = API.fetch_user(@id)
    out.put(:user_fetched, user:)
  end
end
```

### After (raw concurrent-ruby-edge)

```ruby
class FetchUserCommand
  include Tea::Command::Custom

  def call(channel, cancellation)
    return if cancellation.canceled?
    user = API.fetch_user(@id)
    channel.push([:user_fetched, { user: }])
  end
end
```

**Differences:**
- `token.cancelled?` → `cancellation.canceled?`
- `out.put(:tag, data)` → `channel.push([:tag, { data: }])`

---

## Composition (Without Outlet#source)

### Before

```ruby
def call(out, token)
  user = out.source(FetchUserCommand.new(@id), token)
  orders = out.source(FetchOrdersCommand.new(user[:id]), token)
  out.put(:done, user:, orders:)
end
```

### After

```ruby
def call(channel, cancellation)
  # Inline the pattern — no helper
  user_ch = Concurrent::Promises::Channel.new
  FetchUserCommand.new(@id).call(user_ch, cancellation)
  user = user_ch.pop.value![1]

  orders_ch = Concurrent::Promises::Channel.new
  FetchOrdersCommand.new(user[:id]).call(orders_ch, cancellation)
  orders = orders_ch.pop.value![1]

  channel.push([:done, { user:, orders: }])
end
```

Or extract a helper locally:

```ruby
def call(channel, cancellation)
  user = run(FetchUserCommand.new(@id), cancellation)[1]
  orders = run(FetchOrdersCommand.new(user[:id]), cancellation)[1]
  channel.push([:done, { user:, orders: }])
end

private def run(cmd, cancellation)
  ch = Concurrent::Promises::Channel.new
  cmd.call(ch, cancellation)
  ch.pop.value!
end
```

---

## Runtime Changes

```ruby
class Runtime
  private def dispatch(command)
    return unless command.respond_to?(:tea_command?) && command.tea_command?

    _origin, cancellation = Concurrent::Cancellation.new

    Concurrent::Promises.future do
      command.call(@channel, cancellation)
    rescue => e
      @channel.push(Command::Error.new(command:, exception: e))
    end
  end
end
```

---

## Built-In Commands

### Command.batch

```ruby
def self.batch(commands)
  Batch.new(commands: commands.freeze)
end

Batch = Data.define(:commands) do
  include Custom

  def call(channel, cancellation)
    Concurrent::Promises.zip(
      *commands.map { |cmd| Concurrent::Promises.future { cmd.call(channel, cancellation) } }
    ).wait
  end
end
```

### Command.all

```ruby
All = Data.define(:commands) do
  include Custom

  def call(channel, cancellation)
    results = Concurrent::Promises.zip(
      *commands.map do |cmd|
        Concurrent::Promises.future do
          ch = Concurrent::Promises::Channel.new
          cmd.call(ch, cancellation)
          ch.pop.value!
        end
      end
    ).value!

    channel.push([:all, results])
  end
end
```

### Command.wait / Command.tick

```ruby
Wait = Data.define(:seconds, :tag) do
  include Custom

  def call(channel, cancellation)
    Concurrent::Promises.schedule(seconds) { :done }.wait
    channel.push([tag, seconds]) unless cancellation.canceled?
  end
end
```

---

## Trade-offs

### Pros

| Benefit | Impact |
|---------|--------|
| Zero wrapper code | Nothing to maintain |
| Consistent with ecosystem | Developers already know concurrent-ruby |
| No abstraction leaks | Users see exactly what they're using |
| Full concurrent-ruby power | All features available, not just what we wrap |

### Cons

| Cost | Impact |
|------|--------|
| Longer method calls | `channel.push([:tag, data])` vs `out.put(:tag, data)` |
| Less discoverable | Users must learn concurrent-ruby |
| Breaking change | All existing custom commands must update |
| No Ractor validation | Debug mode check is gone |
| Composition is verbose | No `source` helper |

---

## Breaking Changes

| From | To |
|------|------|
| `def call(out, token)` | `def call(channel, cancellation)` |
| `token.cancelled?` | `cancellation.canceled?` |
| `out.put(:tag, data)` | `channel.push([:tag, { data: }])` |
| `out.source(cmd, token)` | Inline pattern or local helper |

---

## Documentation Burden

We'd need to teach concurrent-ruby-edge in our docs:

- What's a Channel?
- What's a Cancellation?
- How to use Promises for composition?
- Error handling patterns?

Essentially, our docs become a concurrent-ruby tutorial for command authors.

---

## Recommendation

**Don't do this.**

The "thin layer of nothing" isn't nothing — it's:

1. **Consistent API** — `put(tag, data)` vs `push([tag, { data: }])`
2. **Composition helper** — `source` is 5 lines but saves 5 lines everywhere
3. **Ractor validation** — Future-proofing we'd lose
4. **Discoverability** — RDoc on our classes vs "go read concurrent-ruby"
5. **Insulation** — If concurrent-ruby API changes, we absorb it

The wrapper isn't overhead — it's **deliberate API design**.

Compare to ActiveSupport, which wraps stdlib extensively. Nobody says "just use Time.now" — they say "use 1.day.ago" because the API is better.

---

## Alternative Recommendation

If the goal is reducing maintenance, use **concurrent_ruby_with_edge_foundation.md**:

- Use concurrent-ruby-edge internally
- Keep slim Outlet/CancellationToken wrappers
- Best of both worlds
