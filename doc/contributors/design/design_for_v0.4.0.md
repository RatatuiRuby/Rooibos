<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Tea v0.4.0 Design

This document maps the path to v0.4.0: concurrent-ruby-edge internals with slim wrappers, plus the command primitives needed for moderately complex apps.

---

## Part 1: What Exists Today

### Core Architecture

```
Tea.run(model:, view:, update:, init:)
           ↓
  RatatuiRuby.run { |tui| loop { ... } }
```

- **model** — Immutable state (`Data.define` or frozen Hash)
- **view** — `^(model, tui) -> Widget`
- **update** — `^(message, model) -> [new_model, command?]`
- **init** — Optional startup message generator

### Existing Commands

| Command | Purpose |
|---------|---------|
| `Command.exit` | Sentinel to terminate the runtime |
| `Command.cancel(handle)` | Request cancellation of a running command |
| `Command.system(command, tag, stream:)` | Shell execution (batch or streaming) |
| `Command.map(command) { \|r\| [...] }` | Transform child command results (fractal routing) |
| `Command.custom(callable)` | Wrap a lambda as a cancellable command |

### Custom Command Protocol

```ruby
class MyCommand
  include Tea::Command::Custom

  def call(out, token)
    # out.put(:tag, data) — send message to runtime
    # token.canceled? — check for cancellation
  end

  def tea_cancellation_grace_period = 2.0  # Optional override
end
```

### Fractal Architecture (Bags)

A **bag** is a module with `Model`, `INITIAL`, `UPDATE`, `VIEW` constants:

```ruby
module SystemInfo
  Model = Data.define(:output, :loading)
  INITIAL = Model.new(output: "Press 's'", loading: false)

  VIEW = ->(model, tui, **) { tui.paragraph(text: model.output, ...) }

  UPDATE = ->(message, model) {
    case message
    in [:system_info, { stdout:, status: 0 }]
      [model.with(output: stdout.strip, loading: false), nil]
    else
      [model, nil]
    end
  }

  def self.fetch_command
    Command.system("uname -a", :system_info)
  end
end
```

### Routing Helpers

```ruby
# Wrap child command result with prefix
Tea.route(child_command, :stats)
# Equivalent to: Command.map(child_command) { |r| [:stats, *r] }

# Delegate prefixed message to child UPDATE
Tea.delegate(message, :stats, StatsPanel::UPDATE, model.stats)
# Returns [new_child_model, wrapped_command] or nil
```

### Router DSL

```ruby
module Dashboard
  include Tea::Router

  route :stats, to: StatsPanel
  route :network, to: NetworkPanel

  keymap do
    key :ctrl_c, -> { Command.exit }
    only when: MODAL_INACTIVE do
      key :q, -> { Command.exit }
      key :s, -> { SystemInfo.fetch_command }, route: :stats
    end
  end

  UPDATE = from_router  # Generates UPDATE lambda
end
```

---

## Part 2: What's Missing for Moderately Complex Apps

### Timer Commands

**Use case:** Spinner animation, debounced search, auto-refresh.

```ruby
# One-shot delay
[model.with(notification: "Saved!"), Command.wait(3.0, :dismiss)]

# Recurring tick (re-dispatch from update to continue)
[model.with(frame: next_frame), Command.tick(0.1, :animate)]
```

### HTTP Commands

**Use case:** API calls without shelling out to curl.

```ruby
[model.with(loading: true), Command.http(:get, "/api/users", :users)]

# Response arrives as:
[:users, { status: 200, body: "...", headers: {...} }]
# or
[:users, { error: "Connection refused" }]
```

### Parallel Commands

**Use case:** Multiple independent fetches.

#### Fire-and-Forget (batch)

Each child sends its own messages:

```ruby
Command.batch([
  Command.http(:get, "/users", :users),
  Command.http(:get, "/posts", :posts),
])
# Messages arrive independently: [:users, ...], [:posts, ...] (any order)
```

#### Aggregating (all)

Wait for all, return combined:

```ruby
Command.all([
  Command.http(:get, "/users", :_),
  Command.http(:get, "/stats", :_),
])
# Single message: [:all, [user_result, stats_result]]
```

### Command Composition (source)

**Use case:** Custom commands that orchestrate multiple steps.

```ruby
class LoadDashboard
  include Tea::Command::Custom

  def call(out, token)
    # Step 1: Fetch user (sync within command)
    user_result = out.source(Command.http(:get, "/me", :_), token)
    return if token.canceled?
    user = JSON.parse(user_result[1][:body])

    # Step 2: Parallel fetch based on user
    all_result = out.source(Command.all([
      Command.http(:get, "/orders?user=#{user["id"]}", :_),
      Command.http(:get, "/notifications", :_),
    ]), token)
    return if token.canceled?

    orders, notifs = all_result[1].map { JSON.parse(_1[1][:body]) }

    # Step 3: Send final result
    out.put(:dashboard_ready, user:, orders:, notifications: notifs)
  end
end
```

---

## Part 3: Library-Level Design

### External Changes

Replace SCREAMING_SNAKE_CASE with PascalCase for required Bag members.

| Current | v0.4.0 |
|---------|---------|
| `Model` | `Model` |
| `INITIAL` | `Initial` |
| `UPDATE` | `Update` |
| `VIEW` | `View` |

### Internal Changes (Invisible to users of Built-in Commands)

Replace hand-rolled thread management with concurrent-ruby-edge:

| Current | Refactored |
|---------|------------|
| `CancellationToken` class | `Concurrent::Cancellation` (direct) |
| `Thread::Queue` in `Outlet` | `Concurrent::Promises::Channel` |
| `Thread.new` in dispatch | `Concurrent::Promises.future` |

**Breaking change:** Command signature is now `call(out, token)` where `token` is a `Concurrent::Cancellation`. Use `token.canceled?` (not `cancelled?`) and `token.origin` for racing.

### New File Structure

```
lib/ratatui_ruby/tea/command/
├── wait.rb        # Command.wait(seconds, tag)
├── tick.rb        # Command.tick(interval, tag)
├── batch.rb       # Command.batch([...])
├── all.rb         # Command.all([...])
└── http.rb        # Command.http(method, url, tag, ...)
```

### Uncancellable Commands

For commands that don't check cancellation, provide a factory that creates a fresh never-resolved cancellation each time. A singleton would be unsafe — if any code path accidentally resolves the shared origin, all commands using it become cancelled.

> [!IMPORTANT]
> This replaces `CancellationToken::NONE`. The old constant was safe because `NoneToken#cancel!` was a no-op. With `Concurrent::Cancellation`, each instance's origin is resolvable, so we **must** use a factory method.

```ruby
module Command
  # Factory: creates a new Cancellation each time (safe)
  # NEVER cache this as a constant — each command needs its own instance
  def self.uncancellable
    Concurrent::Cancellation.new(Concurrent::Promises.resolvable_event)
  end
end
```

### Outlet#source

Run the child command asynchronously. Use `MVar` as a simpler single-element blocking container instead of Channel+race. **Add a grace period timeout backstop** to prevent hung commands from blocking indefinitely. **Propagate exceptions from failed commands** — don't swallow them.

```ruby
class Outlet
  # Default grace period for child commands (seconds)
  SOURCE_GRACE_PERIOD = 30.0

  def source(command, token, grace_period: SOURCE_GRACE_PERIOD)
    result_slot = Concurrent::MVar.new
    child_outlet = SourceOutlet.new(result_slot)

    # Run command asynchronously
    command_future = Concurrent::Promises.future do
      command.call(child_outlet, token)
    end

    # Wait for result with grace period as a definitive backstop
    result = result_slot.take(grace_period)

    return nil if token.canceled?
    return nil if result == Concurrent::MVar::TIMEOUT

    # Propagate exceptions from failed commands — don't swallow errors
    if command_future.rejected?
      raise command_future.reason
    end

    result
  end

  # Internal outlet for #source that writes to MVar instead of Queue
  class SourceOutlet
    def initialize(mvar)
      @mvar = mvar
    end

    def put(tag, *payload)
      message = [tag, *payload].freeze
      @mvar.put(message)  # Overwrites if already set (last message wins)
    end
  end
  private_constant :SourceOutlet
end
```

### Command.batch

Multiple commands write to the shared outlet concurrently. `Outlet#put` uses `Channel#push` which is thread-safe. Report errors for any rejected futures **using callbacks** so errors are captured even if cancellation fires early.

```ruby
Batch = Data.define(:commands) do
  include Custom

  def call(outlet, token)
    futures = commands.map do |command|
      Concurrent::Promises.future { command.call(outlet, token) }
        .rescue do |e|
          # Report errors via callback — guaranteed to run even after cancellation
          outlet.put(:batch_error, Ractor.make_shareable({ error: e.message }))
        end
    end

    all_done = Concurrent::Promises.zip_futures(*futures)

    # Race: all complete vs cancellation token
    Concurrent::Promises.any_event(all_done, token.origin).wait
    # No output on success — each child sends its own messages
    # Errors already reported via rescue callbacks above
  end
end
```

### Command.all

Use non-blocking `pop_op` and **race against the command future** to avoid thread pool exhaustion. This handles both clean exits (command completes) and hung commands (grace period timeout).

```ruby
All = Data.define(:commands) do
  include Custom

  def call(outlet, token)
    futures = commands.map do |command|
      Concurrent::Promises.future do
        child_channel = Concurrent::Promises::Channel.new
        child_outlet = Outlet.new(child_channel)

        # Run command and race against its completion
        command_future = Concurrent::Promises.future do
          command.call(child_outlet, token)
        end

        pop_op = child_channel.pop_op

        # Race: got result vs command finished vs cancelled
        Concurrent::Promises.any_event(pop_op, command_future, token.origin).wait

        # Propagate errors from failed child commands
        raise command_future.reason if command_future.rejected?

        # Return result if available, nil otherwise
        pop_op.resolved? ? pop_op.value : nil
      end
    end

    all_done = Concurrent::Promises.zip_futures(*futures)

    # Race: all complete vs cancellation token
    Concurrent::Promises.any_event(all_done, token.origin).wait
    return if token.canceled?

    outlet.put(:all, Ractor.make_shareable(all_done.value!))
  end
end
```

### Command.wait / Command.tick

Use `Concurrent::Cancellation.timeout` for cleaner timer cancellation. This creates a cancellation that auto-resolves after the given duration. Join it with the parent token to handle both timeout and external cancellation.

> [!NOTE]
> We use `Cancellation.timeout` + `join` instead of `Concurrent::ScheduledTask` because ScheduledTask requires calling `#cancel` (a bang-like mutation method) to stop it. The `Cancellation` pattern is purely declarative: the timer "just happens" when the origin resolves, with no imperative cancellation calls needed.

```ruby
Wait = Data.define(:seconds, :tag) do
  include Custom

  def call(outlet, token)
    # Cancellation.timeout creates an auto-cancelling token after N seconds
    timer_cancellation = Concurrent::Cancellation.timeout(seconds)
    combined = token.join(timer_cancellation)

    combined.origin.wait

    # Send message only if timer expired (not external cancellation)
    outlet.put(tag, seconds) if timer_cancellation.canceled? && !token.canceled?
  end
end

Tick = Data.define(:interval, :tag) do
  include Custom

  def call(outlet, token)
    timer_cancellation = Concurrent::Cancellation.timeout(interval)
    combined = token.join(timer_cancellation)

    combined.origin.wait

    outlet.put(tag, interval) if timer_cancellation.canceled? && !token.canceled?
  end
end
```

### RecurringTick (Continuous Animation) — App Developer Pattern

> [!NOTE]
> This is **not a built-in command**. It's documented as a pattern for app developers who need continuous background ticks without re-dispatching from `update`.

#### When to Use This vs `Command.tick`

| Feature | `Command.tick` (re-dispatch) | `RecurringTick` (long-running) |
|---------|------------------------------|--------------------------------|
| **Control** | Update function decides each tick | Command runs independently |
| **Model access** | ✅ Yes (update sees current model) | ❌ No (command can't see model) |
| **Dynamic interval** | ❌ Fixed at creation | ✅ Can change each iteration |
| **Cancellation** | Implicit (just don't re-dispatch) | Explicit (token + shutdown) |
| **Use case** | Spinners, animations | Heartbeats, background sync, clocks |

**Use `Command.tick`** for UI animations where each frame might depend on current state.

**Use `RecurringTick`** for background tasks that run "forever" at a fixed or dynamic interval.

#### Basic Implementation

```ruby
RecurringTick = Data.define(:interval, :tag) do
  include Tea::Command::Custom

  def call(outlet, token)
    timer_task = Concurrent::TimerTask.new(execution_interval: interval) do
      outlet.put(tag, Time.now.to_f) unless token.canceled?
    end
    timer_task.execute

    # Block until external cancellation
    token.origin.wait
    timer_task.shutdown
  end
end
```

#### Dynamic Interval Example

`TimerTask` passes itself to the block, enabling dynamic interval changes:

```ruby
AdaptiveHeartbeat = Data.define(:initial_interval, :tag) do
  include Tea::Command::Custom

  def call(outlet, token)
    timer_task = Concurrent::TimerTask.new(execution_interval: initial_interval) do |task|
      # Send heartbeat
      outlet.put(tag, Time.now.to_f)

      # Adapt interval based on conditions (e.g., slow down over time)
      task.execution_interval = [task.execution_interval * 1.1, 60.0].min
    end
    timer_task.execute

    token.origin.wait
    timer_task.shutdown
  end
end
```

#### Fixed Rate vs Fixed Delay

`TimerTask` supports two interval modes:

- **`:fixed_delay`** (default): Wait N seconds *after* task completes before next run
- **`:fixed_rate`**: Try to maintain N seconds *between starts* (compensates for task duration)

```ruby
Concurrent::TimerTask.new(
  execution_interval: 1.0,
  interval_type: :fixed_rate  # or :fixed_delay
) { ... }
```

For UI animations, `:fixed_rate` provides smoother timing even if work takes variable time.

### Command.http

> [!NOTE]
> `Net::HTTP` doesn't support mid-request cancellation. The timeout settings provide a ceiling, but
> once a request starts, it will complete or timeout. Cancellation token is checked before and after.

```ruby
Http = Data.define(:method, :url, :tag, :headers, :body, :timeout) do
  include Custom

  def call(out, token)
    require "net/http"
    return if token.canceled?

    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = timeout || 10
    http.read_timeout = timeout || 10

    request = build_request(uri)
    response = http.request(request)
    
    return if token.canceled?  # Don't send result if cancelled during request

    out.put(tag, Ractor.make_shareable({
      status: response.code.to_i,
      body: response.body.freeze,
      headers: response.each_header.to_h.freeze,
    }))
  rescue => e
    out.put(tag, Ractor.make_shareable({ error: e.message.freeze })) unless token.canceled?
  end

  private def build_request(uri)
    # Capture body in local variable to avoid cross-thread closure issues
    request_body = body
    
    case self.method
    when :get    then Net::HTTP::Get.new(uri)
    when :post   then Net::HTTP::Post.new(uri).tap { |r| r.body = request_body }
    when :put    then Net::HTTP::Put.new(uri).tap { |r| r.body = request_body }
    when :delete then Net::HTTP::Delete.new(uri)
    end.tap do |request|
      headers&.each do |key, value|
        request[key] = value
      end
    end
  end
end
```

---

## Part 4: User Experience Examples

### Simple Counter (No Commands)

```ruby
Tea.run(
  model: { count: 0 }.freeze,
  view:  ->(m, tui) { tui.paragraph(text: "Count: #{m[:count]}") },
  update: ->(msg, m) {
    if msg.up? then m.with(count: m[:count] + 1)
    elsif msg.down? then m.with(count: m[:count] - 1)
    elsif msg.q? then Command.exit
    else m
    end
  }
)
```

### Spinner Animation (tick)

```ruby
SPINNER = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze

update = ->(msg, model) {
  case msg
  in [:tick, _]
    frame = (model.frame + 1) % SPINNER.size
    [model.with(frame:), Command.tick(0.1, :tick)]
  in _ if msg.q?
    Command.exit
  else
    model
  end
}
```

### API Fetch (http)

```ruby
update = ->(msg, model) {
  case msg
  in :fetch
    [model.with(loading: true), Command.http(:get, API_URL, :data)]
  in [:data, { status: 200, body: }]
    [model.with(loading: false, items: JSON.parse(body)), nil]
  in [:data, { error: }]
    [model.with(loading: false, error:), nil]
  else
    model
  end
}
```

### Complex Dashboard (fractal + composition)

```ruby
module Dashboard
  include Tea::Router

  route :stats, to: StatsPanel
  route :network, to: NetworkPanel

  keymap do
    key :q, -> { Command.exit }
    key :r, -> { LoadDashboard.new }  # Custom composed command
  end

  Update = from_router
end
```

---

## Part 5: Dependencies

```ruby
# ratatui_ruby-tea.gemspec
spec.add_dependency "ratatui_ruby", "~> 0.10"
spec.add_dependency "concurrent-ruby", "~> 1.3"
spec.add_dependency "concurrent-ruby-edge", "~> 0.7"
```

---

## Part 6: Implementation Roadmap

### Phase 1: concurrent-ruby-edge Foundation ✅

- [x] Add concurrent-ruby-edge dependency
- [x] Remove `CancellationToken` class — use `Concurrent::Cancellation` directly
- [x] Replace `CancellationToken::NONE` constant with `Command.uncancellable` factory method
- [x] Update command signature to `call(out, token)` (token has a new interface)
- [x] Refactor `Outlet` internals to use Channel
- [x] Refactor runtime dispatch to use `Concurrent::Promises.future`
- [x] Replace `active_commands = {}` with `Concurrent::Map.new` for thread-safe command tracking
- [x] All existing tests pass (with updated signatures)

### Phase 2: Timer Commands

- [ ] Implement `Command.wait`
- [ ] Implement `Command.tick`
- [ ] Test cancellation during wait
- [ ] Document patterns (debounce, animation)

### Phase 3: Parallel Commands

- [ ] Implement `Command.batch`
- [ ] Implement `Command.all`
- [ ] Test mixed command types
- [ ] Document parallel fetch patterns

### Phase 4: HTTP Command

- [ ] Implement `Command.http` (GET, POST, PUT, DELETE)
- [ ] Handle SSL, timeouts, errors
- [ ] Test with mock server
- [ ] Document response format

### Phase 5: Composition

- [ ] Implement `Outlet#source`
- [ ] Test sync→parallel→sync flows
- [ ] Document composition patterns

### Phase 6: Documentation

- [ ] Quickstart guide
- [ ] Custom commands guide
- [ ] Fractal architecture guide
- [ ] Migration notes (internal changes, no breaking API)
- [ ] **Concurrency Patterns Guide** for app developers:
  - Rate-limiting with `Concurrent::Throttle` (for heavy HTTP usage)
  - Continuous animation with `Concurrent::TimerTask` (dynamic intervals, heartbeats)

---

## Part 7: Breaking Changes

**Breaking change for custom command authors:** Command signature changes from `call(out, token)` where `token` is a `CancellationToken` to `call(out, token)` where `token` is a `Concurrent::Cancellation`. Use `cancellation.canceled?` (American spelling) instead of `token.cancelled?` (British spelling).

Built-in commands and the runtime API are unchanged.
