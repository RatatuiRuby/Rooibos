<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Command Composition Design (`ratatui_ruby-tea`)

This document specifies the architecture for built-in command combinators in `ratatui_ruby-tea`. These primitives enable common patterns without requiring custom command classes.

---

## Executive Summary

Applications need more than single fire-and-forget commands. They need parallelism, aggregation, timers, and HTTP. The design provides:

1. **`Command.batch([...])`** — Execute multiple commands concurrently; each sends own messages (fire-and-forget)
2. **`Command.all([...])`** — Execute multiple commands concurrently; wait and aggregate results
3. **`Command.wait(seconds, tag)`** — One-shot timer
4. **`Command.tick(interval, tag)`** — Recurring timer (subscription pattern)
5. **`Command.http(method, url, tag, **options)`** — HTTP requests via `Net::HTTP`
6. **`Outlet#source(command, token)`** — Synchronously compose commands inside custom commands

All primitives are implemented as custom commands using the existing `Outlet` and `CancellationToken` infrastructure. No runtime changes required.

---

## Core Abstractions

### Command.batch

Dispatches multiple commands concurrently. Each command produces its own messages independently.

```ruby
Command::Batch = Data.define(:commands) do
  include Command::Custom

  def tea_command? = true
  def tea_cancellation_grace_period = 2.0

  def call(out, token)
    threads = commands.map do |cmd|
      Thread.new { cmd.call(out, token) }
    end
    threads.each(&:join)
  end
end

def self.batch(commands)
  Batch.new(commands: commands.freeze)
end
```

**Usage:**

```ruby
# Dispatch three independent HTTP requests in parallel
[model, Command.batch([
  Command.http(:get, "/users", :users),
  Command.http(:get, "/posts", :posts),
  Command.http(:get, "/comments", :comments)
])]

# Update receives three separate messages:
# [:users, {...}], [:posts, {...}], [:comments, {...}]
```

**Key design decisions:**

| Decision | Rationale |
|----------|-----------|
| Each command gets same outlet | Messages are independent; order is non-deterministic |
| Each command gets same token | Cancelling batch cancels all children |
| Fire-and-forget | Use `Command.all` when you need aggregated results |

---

### Command.all

Executes multiple commands concurrently and aggregates results. Waits for all to complete before sending a single message.

```ruby
Command::All = Data.define(:commands) do
  include Command::Custom

  def tea_command? = true
  def tea_cancellation_grace_period = 2.0

  def call(out, token)
    results = commands.map do |cmd|
      Thread.new do
        child_queue = Thread::Queue.new
        child_outlet = Outlet.new(child_queue)
        cmd.call(child_outlet, token)
        child_queue.pop
      end
    end.map(&:value)

    out.put(:all, Ractor.make_shareable(results))
  end
end

def self.all(commands)
  All.new(commands: commands.freeze)
end
```

**Usage (from update function):**

```ruby
# Dispatch and wait for all; receive one aggregated message
[model, Command.all([
  Command.http(:get, "/users", :_),
  Command.http(:get, "/posts", :_)
])]

# Update receives: [:all, [users_result, posts_result]]
```

**When to use which:**

| Primitive | Behavior | Use when... |
|-----------|----------|-------------|
| `batch` | Each command sends own message | Handling responses independently |
| `all` | Wait for all, send one aggregated message | Need all results before proceeding |

---

### Outlet#source

Synchronously execute a command inside another command. Enables composing reusable command building blocks.

```ruby
class Outlet
  # Outsource work to another command and return its result.
  #
  # Creates a child queue, executes the command, and returns the result
  # synchronously. Use this to compose commands inside custom commands.
  #
  # [command] Any command (built-in or custom)
  # [token] CancellationToken for cooperative cancellation
  #
  # === Example
  #
  #   def call(out, token)
  #     user = out.source(FetchUserCommand.new(user_id), token)
  #     orders = out.source(FetchOrdersCommand.new(user[:id]), token)
  #     out.put(:done, user:, orders:)
  #   end
  def source(command, token)
    child_queue = Thread::Queue.new
    child_outlet = Outlet.new(child_queue)
    command.call(child_outlet, token)
    child_queue.pop
  end
end
```

**Complex composition (sync → parallel → sync):**

```ruby
class DashboardDataCommand
  include Tea::Command::Custom

  def initialize(user_id)
    @user_id = user_id
  end

  def call(out, token)
    # Step 1: Sync — fetch user first (needed by subsequent steps)
    user = out.source(FetchUserCommand.new(@user_id), token)

    # Step 2: Parallel — fetch 3 things that depend on user but not each other
    results = out.source(
      Command.all([
        FetchOrdersCommand.new(user[:id]),
        FetchNotificationsCommand.new(user[:id]),
        FetchRecommendationsCommand.new(user[:preferences])
      ]),
      token
    )
    orders, notifications, recommendations = results[1]  # Unwrap :all tuple

    # Step 3: Sync — generate report using all data
    report = out.source(
      GenerateReportCommand.new(user:, orders:, notifications:),
      token
    )

    out.put(:dashboard_ready, report:)
  end
end
```

This pattern enables:
- **Reusable building blocks** — Small commands compose into larger workflows
- **Explicit control flow** — Sync and parallel steps are visually distinct  
- **No runtime changes** — Built entirely on existing Outlet/Token infrastructure

---

### Command.wait

One-shot timer. Sleeps for the specified duration, then sends a message.

```ruby
Command::Wait = Data.define(:seconds, :tag) do
  include Command::Custom

  def tea_command? = true
  def tea_cancellation_grace_period = 0.1

  def call(out, token)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # Interruptible sleep
    remaining = seconds
    while remaining > 0 && !token.cancelled?
      sleep [remaining, 0.1].min
      remaining = seconds - (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start)
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    out.put(tag, elapsed) unless token.cancelled?
  end
end

def self.wait(seconds, tag)
  Wait.new(seconds:, tag:)
end
```

**Usage:**

```ruby
# Show success message, dismiss after 2 seconds
def update(msg, model)
  case msg
  in :save_clicked
    [model.with(message: "Saved!"), Command.wait(2.0, :dismiss_message)]
  in [:dismiss_message, _elapsed]
    [model.with(message: nil), nil]
  end
end
```

---

### Command.tick

Recurring timer. The command produces a message after each interval. To continue, the update function returns the same tick command again. To stop, return `nil` or a different command.

This implements the "Subscriptions are Loops" philosophy from BubbleTea.

```ruby
Command::Tick = Data.define(:interval, :tag) do
  include Command::Custom

  def tea_command? = true
  def tea_cancellation_grace_period = 0.1

  def call(out, token)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # Interruptible sleep
    remaining = interval
    while remaining > 0 && !token.cancelled?
      sleep [remaining, 0.1].min
      remaining = interval - (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start)
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    out.put(tag, elapsed) unless token.cancelled?
  end
end

def self.tick(interval, tag)
  Tick.new(interval:, tag:)
end
```

**Usage:**

```ruby
# Animate a spinner at 100ms intervals
def update(msg, model)
  case msg
  in [:tick, _elapsed]
    next_frame = (model.spinner_frame + 1) % SPINNER_FRAMES.size
    [model.with(spinner_frame: next_frame), Command.tick(0.1, :tick)]
  in :loading_complete
    [model.with(loading: false), nil]  # Stop ticking
  end
end

# Start the loop
[model.with(loading: true), Command.tick(0.1, :tick)]
```

---

### Command.http

HTTP requests using Ruby's standard library `Net::HTTP`. No external dependencies.

```ruby
Command::Http = Data.define(:method, :url, :tag, :headers, :body, :timeout) do
  include Command::Custom

  def tea_command? = true
  def tea_cancellation_grace_period = 1.0

  def call(out, token)
    require "net/http"
    require "uri"

    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = timeout || 30
    http.read_timeout = timeout || 30

    request = build_request(uri)
    headers&.each { |k, v| request[k] = v }
    request.body = body if body

    response = http.request(request)

    out.put(tag, Ractor.make_shareable({
      status: response.code.to_i,
      body: response.body.freeze,
      headers: response.to_hash.freeze
    }))
  rescue => e
    out.put(tag, Ractor.make_shareable({
      error: e.message.freeze,
      status: nil
    }))
  end

  private

  def build_request(uri)
    case method
    when :get    then Net::HTTP::Get.new(uri)
    when :post   then Net::HTTP::Post.new(uri)
    when :put    then Net::HTTP::Put.new(uri)
    when :patch  then Net::HTTP::Patch.new(uri)
    when :delete then Net::HTTP::Delete.new(uri)
    when :head   then Net::HTTP::Head.new(uri)
    else raise ArgumentError, "Unknown HTTP method: #{method}"
    end
  end
end

def self.http(method, url, tag, headers: nil, body: nil, timeout: nil)
  Http.new(method:, url:, tag:, headers: headers&.freeze, body: body&.freeze, timeout:)
end
```

**Usage:**

```ruby
# GET request
[model, Command.http(:get, "https://api.example.com/users", :users)]

# POST with body and headers
[model, Command.http(
  :post,
  "https://api.example.com/users",
  :create_user,
  headers: { "Content-Type" => "application/json" },
  body: '{"name": "Alice"}'
)]

# Handle response
def update(msg, model)
  case msg
  in [:users, {status: 200, body:}]
    [model.with(users: JSON.parse(body)), nil]
  in [:users, {error:}]
    [model.with(error: error), nil]
  end
end
```

---

## Open Questions

### 1. HTTP cancellation mid-request?

`Net::HTTP` with timeouts doesn't support mid-request cancellation. The token can prevent *sending* a request, but once `http.request` is called, it blocks until completion or timeout.

**Options:**

- Accept the limitation (timeouts are sufficient)
- Use `Timeout.timeout` wrapper (risks thread safety)
- Document that HTTP commands aren't interruptible mid-request

**Decision:** Accept the limitation. Document it. HTTP requests should have reasonable timeouts anyway.

---

## Pattern Lineage

### Command Combinators

| Library | Pattern | Mapping |
|---------|---------|---------|
| **Elm** | `Cmd.batch`, `Cmd.none` | `Command.batch` |
| **BubbleTea** | `tea.Batch` | `Command.batch` |
| **JavaScript** | `Promise.all`, `Promise.race` | `Command.all` |

### Timer Patterns

| Pattern | Implementation |
|---------|----------------|
| **One-shot** | `Command.wait` — fires once, stops |
| **Recurring** | `Command.tick` — fires repeatedly via update loop |
| **Debounce** | `wait` + model tracking (user-space) |
| **Throttle** | `tick` + model tracking (user-space) |

---

## Implementation Roadmap

Each command can be implemented independently. Order reflects increasing complexity.

### Unit 1: Command.wait

| Criteria | Assessment |
|----------|------------|
| Self-contained | ✅ No dependencies on other new commands |
| Independently testable | ✅ Verify message after sleep |
| Complexity | Low — interruptible sleep only |
| Surface area | 1 factory method, 1 Data.define |

**Test cases:**

- Timer fires after specified duration
- Timer respects cancellation token
- Elapsed time is accurate (within tolerance)

---

### Unit 2: Command.tick

| Criteria | Assessment |
|----------|------------|
| Self-contained | ✅ Same pattern as `wait` |
| Independently testable | ✅ Verify message after interval |
| Complexity | Low — identical to `wait` |
| Surface area | 1 factory method, 1 Data.define |

**Test cases:**

- Tick fires after interval
- Tick respects cancellation
- Update can "continue" by returning another tick
- Update can "stop" by returning nil

---

### Unit 3: Command.batch

| Criteria | Assessment |
|----------|------------|
| Self-contained | ✅ Wraps existing commands |
| Independently testable | ✅ Verify all commands dispatch |
| Complexity | Medium — thread coordination |
| Surface area | 1 factory method, 1 Data.define |

**Test cases:**

- All commands in batch execute
- Batch respects cancellation (all children stop)
- Messages arrive in non-deterministic order
- Empty batch produces no messages

---

### Unit 4: Command.http

| Criteria | Assessment |
|----------|------------|
| Self-contained | ✅ Uses only stdlib |
| Independently testable | ✅ Mock server or WebMock |
| Complexity | Medium — HTTP edge cases |
| Surface area | 1 factory method, 1 Data.define |

**Test cases:**

- GET request returns status, body, headers
- POST request sends body
- Network error produces error message (not exception)
- Timeout produces error message
- HTTPS works

---

### Unit 5: Command.all

| Criteria | Assessment |
|----------|------------|
| Depends on | Unit 3 (batch pattern) |
| Independently testable | ✅ Verify aggregation |
| Complexity | Medium — child queues + thread coordination |
| Surface area | 1 factory method, 1 Data.define |

**Test cases:**

- All commands execute in parallel
- Results aggregated in order
- Respects cancellation
- Works with `out.source` composition

---

### Unit 6: Outlet#source

| Criteria | Assessment |
|----------|------------|
| Depends on | Outlet class (already exists) |
| Independently testable | ✅ Mock command, verify return |
| Complexity | Low — child queue + single call |
| Surface area | 1 new method on Outlet |

**Test cases:**

- Returns command's result synchronously
- Passes token to child command
- Works with any command type (built-in, custom, batch, all)
- Enables complex composition flows

---

## Rejected Alternatives

### Command.sequence

**What it would do:** Execute commands serially, optionally passing results between steps.

**Why rejected:**

1. **Data passing is awkward.** Each step only receives the previous result. Multi-step pipelines that need data from earlier steps require accumulator patterns or closures (which break Ractor safety).

2. **Shell chains don't need it.** The canonical example (`mkdir` → `touch` → `chmod`) is better served by `&&` in a single `Command.system` call.

3. **Custom commands solve the hard cases.** Complex pipelines with data dependencies are cleaner as custom command classes with explicit control flow.

4. **No valid use case remains.** After eliminating shell chains and data-dependent pipelines, there's nothing left that `sequence` uniquely solves.

---

## Appendix: Shortcuts Module Extension

The existing `Tea::Shortcuts` module should be extended:

```ruby
module RatatuiRuby::Tea::Shortcuts
  module Cmd
    def self.batch(...) = Command.batch(...)
    def self.all(...) = Command.all(...)
    def self.wait(...) = Command.wait(...)
    def self.tick(...) = Command.tick(...)
    def self.http(...) = Command.http(...)
    def self.get(url, tag, **opts) = Command.http(:get, url, tag, **opts)
    def self.post(url, tag, **opts) = Command.http(:post, url, tag, **opts)
  end
end
```
