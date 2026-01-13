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

Each child sends its own messages. Supports DWIM arity:

```ruby
# Array syntax
Command.batch([cmd1, cmd2])

# Variadic syntax (equivalent)
Command.batch(cmd1, cmd2)

# Messages arrive independently: [:users, ...], [:posts, ...] (any order)
# On cancellation: emits Command.cancel(self)
# Child errors surface as Command::Error
```

#### Aggregating (all)

Wait for all, return combined. Supports DWIM arity with output format matching input:

```ruby
# Array syntax → nested output: [:dashboard, [user_result, stats_result]]
Command.all(:dashboard, [user_cmd, stats_cmd])

# Variadic syntax → splatted output: [:dashboard, user_result, stats_result]
Command.all(:dashboard, user_cmd, stats_cmd)

# On cancellation: emits Command.cancel(self)
# Child errors surface as Command::Error
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

Run the child command synchronously via the shared `Lifecycle` service. The lifecycle handles timeout, cancellation, grace periods, and force-termination.

```ruby
class Outlet
  # Default timeout for child commands (seconds)
  SOURCE_DEFAULT_TIMEOUT = 30.0

  def initialize(channel, lifecycle:)
    @channel = channel
    @live = lifecycle  # Shared lifecycle manager
  end

  def source(command, token, timeout: SOURCE_DEFAULT_TIMEOUT)
    @live.run_sync(command, token, timeout:)
  end
end
```

### Command::Lifecycle

Internal service shared by Runtime and `Outlet#source`. Manages thread tracking, cancellation, and force-termination. App developers don't interact with this directly.

```ruby
class Lifecycle
  Entry = Data.define(:future, :origin)

  def initialize
    @active = Concurrent::Map.new
  end

  # Synchronous execution with timeout (for Outlet#source)
  def run_sync(command, token, timeout:)
    # 1. Return nil if already cancelled
    # 2. Create child channel + outlet with self as lifecycle
    # 3. Run command in thread
    # 4. Race: result vs cancellation vs timeout
    # 5. If cancelled: wait grace period, Thread#kill if needed
    # 6. Propagate exceptions, return result
  end

  # Async execution with tracking (for Runtime dispatch)
  def run_async(command, channel)
    # 1. Create cancellation token
    # 2. Run in future, push errors as Command::Error
    # 3. Track in @active map
    # 4. Return Entry for future access
  end

  # Cancel a specific command
  def cancel(command)
    # 1. Signal origin
    # 2. Wait grace period
    # 3. Remove from tracking
  end

  # Shutdown all active commands
  def shutdown
    # Signal and wait for each tracked command
  end
end
```

### Command.batch

Multiple commands write to the shared outlet concurrently. `Outlet#put` uses `Channel#push` which is thread-safe.

> [!IMPORTANT]
> **Implementation deviation:** Child errors surface as `Command::Error` (propagated to runtime) instead of `:batch_error` callbacks. This aligns with `Command.all` and the automatic error propagation pattern documented in `commands_and_outlets.md`.

> [!NOTE]
> **DWIM arity:** Accepts either variadic arguments `batch(cmd1, cmd2)` or an array `batch([cmd1, cmd2])`. The constructor normalizes both to an internal commands array.

```ruby
Batch = Data.define(:commands) do
  include Custom

  def self.new(*args)
    # DWIM: batch(cmd1, cmd2) or batch([cmd1, cmd2])
    commands = args.size == 1 && args.first.is_a?(Array) ? args.first : args
    # Validate shareability in debug mode
    super(commands: commands.freeze)
  end

  def call(outlet, token)
    futures = commands.map do |command|
      Concurrent::Promises.future { command.call(outlet, token) }
    end

    all_done = Concurrent::Promises.zip_futures(*futures)
    Concurrent::Promises.any_event(all_done, token.origin).wait

    # Re-raise first child exception for runtime to wrap in Command::Error
    futures.each { |f| raise f.reason if f.rejected? }

    # Emit sentinel on cancellation so app can detect batch was stopped
    outlet.put(Command.cancel(self)) if token.canceled?
  end
end
```

### Command.all

> [!IMPORTANT]
> **Implementation deviation:** Uses a simpler synchronous design instead of nested futures with `pop_op`. Each child command returns its result directly; the futures are zipped to wait for all.

> [!NOTE]
> **DWIM arity + output format:** Array input produces nested output `[:tag, [results]]`; variadic input produces splatted output `[:tag, r1, r2]`. A `nested` field tracks which was used.

```ruby
All = Data.define(:tag, :commands, :nested) do
  include Custom

  def self.new(tag, *args)
    # DWIM: all(:tag, cmd1, cmd2) or all(:tag, [cmd1, cmd2])
    if args.size == 1 && args.first.is_a?(Array)
      commands = args.first
      nested = true
    else
      commands = args
      nested = false
    end
    # Validate shareability in debug mode
    super(tag:, commands: commands.freeze, nested:)
  end

  def call(outlet, token)
    return outlet.put(Command.cancel(self)) if token.canceled?

    futures = commands.map do |command|
      Concurrent::Promises.future do
        child_channel = Concurrent::Promises::Channel.new
        child_outlet = Outlet.new(child_channel)
        command.call(child_outlet, token)
        child_channel.pop  # Blocks until child sends result
      end
    end

    all_done = Concurrent::Promises.zip_futures(*futures)
    Concurrent::Promises.any_event(all_done, token.origin).wait

    return outlet.put(Command.cancel(self)) if token.canceled?

    shareable_results = Ractor.make_shareable(all_done.value!)
    if nested
      outlet.put(tag, shareable_results)
    else
      outlet.put(tag, *shareable_results)
    end
  end
end
```

### Command.wait / Command.tick

Use `Concurrent::Cancellation.timeout` for cleaner timer cancellation. This creates a cancellation that auto-resolves after the given duration. Join it with the parent token to handle both timeout and external cancellation.

> [!NOTE]
> We use `Cancellation.timeout` + `join` instead of `Concurrent::ScheduledTask` because ScheduledTask requires calling `#cancel` (a bang-like mutation method) to stop it. The `Cancellation` pattern is purely declarative: the timer "just happens" when the origin resolves, with no imperative cancellation calls needed.

> [!IMPORTANT]
> **Implementation decision:** When cancelled, these commands emit `Command.cancel(self)` instead of silently returning. This allows the update function to detect and handle cancellation explicitly.

```ruby
Wait = Data.define(:seconds, :tag) do
  include Custom

  def call(outlet, token)
    # Cancellation.timeout creates an auto-cancelling token after N seconds
    timer_cancellation = Concurrent::Cancellation.timeout(seconds)
    combined = token.join(timer_cancellation)

    combined.origin.wait

    if token.canceled?
      # Emit sentinel so app can detect and handle cancellation
      outlet.put(Command.cancel(self))
    elsif timer_cancellation.canceled?
      outlet.put(tag)
    end
  end
end

# Tick is an alias for Wait — the "recurring" behavior comes from
# re-dispatching Command.tick in the update function
Tick = Wait
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

- [x] Implement `Command.wait`
- [x] Implement `Command.tick`
- [x] Test cancellation during wait

### Phase 3: Parallel Commands

- [x] Implement `Command.batch`
- [x] Implement `Command.all`
- [ ] Test mixed command types

### Phase 4: HTTP Command

- [ ] Implement `Command.http` (GET, POST, PUT, DELETE)
- [ ] Handle SSL, timeouts, errors
- [ ] Test with mock server

### Phase 5: Composition

- [x] Implement `Outlet#source`
- [ ] Test sync→parallel→sync flows

### Phase 6: Documentation

- [ ] Document timer patterns (debounce, animation)
- [ ] Document parallel fetch patterns
- [ ] Document response format
- [ ] Document composition patterns
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
