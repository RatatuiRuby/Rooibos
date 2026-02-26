<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]

### Added

### Changed

### Fixed

### Removed

## [0.7.3] - 2026-02-26

### Added

### Changed

### Fixed

- `forward_instances_of` now works inside `route_to` blocks

### Removed

## [0.7.2] - 2026-02-20

### Added

### Changed

### Fixed

- **Nested `only when:` guards are Ractor-shareable**: `only when: OuterGuard do ... otherwise route_to: :child, when: InnerGuard ... end` raised `Ractor::IsolationError` at startup because `Guard.apply_scope` combined guards with a lambda that captured block variables from `inject`.

### Removed

## [0.7.1] - 2026-02-20

### Added

### Changed

### Fixed

- **Welcome screen shows app-specific file paths**: The built-in welcome screen now detects the gem name of the app that required it and displays the correct `lib/<app>.rb` and `test/test_<app>.rb` paths. Previously it hardcoded stale prototype paths that did not exist in any scaffolded app.

### Removed

## [0.7.0] - 2026-02-18

### Added

- **Curated RuboCop config shipped with gem**: Rooibos now includes a curated RuboCop configuration at `lib/rooibos/rubocop.yml`. Use `inherit_gem: { rooibos: lib/rooibos/rubocop.yml }` in your `.rubocop.yml` to adopt it.

- **`Message::Predicates` new predicates**: Added `milestone?` and `custom?` predicate methods. Use `message.milestone?` to check for milestone messages (e.g., completion signals) and `message.custom?` to check for custom user-defined message types.

- **`Command.deliver(message)`**: New built-in command for sending structured messages to Update. Wraps any message and delivers it via the runtime. Works with pattern matching and predicates.

- **`Command.bubble(message)`**: New command for outward message propagation through the fragment hierarchy. Unlike `Command.deliver` (which goes directly to the root), `Command.bubble` flows through each fragment level, giving each outer fragment an opportunity to observe or intercept the message before it reaches the next level. Use with the Router DSL (`observe`, `intercept`) or handle manually by checking for `Command::Bubble` and extracting the message.

- **`Message::Bubbled`**: New message type wrapping bubbled messages in the fragment hierarchy. Provides `bubbled?` predicate for identification.

- **Router `receive` DSL**: New handlers for accepting and processing messages, replacing the `keymap` and `mousemap` DSLs. Five forms available, each stops further receive/forward/otherwise processing on match:
    - `receive_events :q, handler` — match by key/event symbol (also accepts arrays: `receive_events [:q, :ctrl_c], handler`)
    - `receive_routed :envelope, handler` — match by `Message::Routed` envelope
    - `receive_instances_of SomeClass, handler` — match by message class
    - `receive_all handler` — match any message
    - `receive predicate, handler` — match by custom predicate lambda: `receive -> (msg, model) { msg.key? && model[:mode] == :insert }, handler`
    - All forms accept `when:` and `unless:` guard keywords
    - ALL forms aliased as `intercept`

- **Router `observe` DSL**: Non-stopping message observation. Same five forms as `receive`: `observe`, `observe_events`, `observe_instances_of`, `observe_routed`, `observe_all`. Observers run before receive/intercept/forward, allow model updates and command accumulation, and pass the message through to subsequent handlers. Multiple observers run in declaration order and accumulate model and command changes.

- **Router `forward` DSL**: Forward messages to nested fragments. Five forms:
    - `forward_events :enter, to: :panel, as: :action_name` — forward key events with envelope renaming
    - `forward_instances_of SomeClass, to: :panel` — forward by message class
    - `forward_routed :envelope, to: :panel, as: :new_envelope` — forward by routed envelope
    - `forward_all to: :panel` — forward all messages
    - `forward predicate, to: :panel` — forward by custom predicate lambda
    - Supports `broadcast: true` to send to all routes, and `when:`/`unless:` guards
    - Destination can be a symbol (`:panel`), a Fragment (`PanelFragment`), or a captured Route object

- **Router `route_to` blocks**: Scoped forwarding that infers the destination for all `forward` declarations within the block, reducing repetition. Accepts a route name, Fragment, or captured Route.

- **Router `otherwise` guards**: `otherwise` now supports `when:` and `unless:` guard keywords and multiple clauses with first-match semantics. Also resolves destinations by Fragment or captured Route.

- **Router `only`/`skip` guard blocks**: Scoped guard blocks apply a shared condition to all handlers declared within. `only` passes when the guard is true; `skip` passes when it is false. Blocks nest and combine (all guards must pass).

- **Router `route` returns Route objects**: `route` now returns a `Route` data object. Capture it to disambiguate when multiple routes target the same fragment Module.

- **Router unnamed routes**: Routes can omit the symbol prefix when using `read:`/`write:` callable accessors for custom model extraction. Combine with a captured Route object for forwarding.
### Changed

- **`rooibos new` generates curated RuboCop config**: Scaffolded applications now get a `.rubocop.yml` that inherits the Rooibos curated cop profile via `inherit_gem`, replacing the bare defaults that `bundle gem --linter=rubocop` produces.

- **BREAKING: `keymap` DSL removed**: The `keymap do |map|` / `map.key` DSL is removed. Use `receive_events` for handling events and `forward_events` for routing to nested fragments. Migrate:
  - `keymap { |map| map.key :q, -> { Command.exit } }` becomes `receive_events :q, -> (_msg, _model) { Command.exit }`
  - `keymap { |map| map.key :j, :move_down }` becomes `receive_events :j, :move_down`
  - Guards move to keyword args: `receive_events :q, handler, when: -> (_msg, model) { model[:active] }`

- **BREAKING: `mousemap` DSL removed**: The `mousemap do |map|` / `map.scroll` / `map.click` DSL is removed. Use `receive_events` with event symbols. Migrate:
  - `mousemap { |map| map.scroll :up, handler }` becomes `receive_events :scroll_up, handler`

- **BREAKING: `action` inline keybinding options removed**: The `keymap:`, `keys:`, `key:`, and `mousemap:` keyword arguments on `action` declarations are removed. Bind keys separately with `receive_events`:
  - Before: `action quit: -> { Command.exit }, keymap: %i[ctrl_c q]`
  - After: `action :quit, -> { Command.exit }` + `receive_events [:q, :ctrl_c], :quit`

- **BREAKING: Runtime validates Init, View, and Update for Ractor shareability**: At startup, the runtime now checks that all three fragment callables can be made Ractor-shareable. Fragments using lambdas that capture mutable state or are defined in non-shareable scopes will fail validation. Convert to module-level callables, use classes, or use `Ractor.make_shareable`.

### Fixed

- **Gem Size**: Reduced gem size from 812KB to 116KB by excluding doc/, examples/, and other development files.

- **Batch cancellation reliably delivers children's `Message::Canceled`**: When a `Command.batch` was cancelled, the batch itself responded instantly but children's cancellation messages could arrive after the runtime had already moved on. Now the lifecycle waits for children spawned via `Outlet#standing` to complete before resolving the batch's future, so all `Message::Canceled` messages arrive before the next Update cycle.

- **`Command::Cancel` no longer includes `Message::Predicates`**: Commands should only include `Command::Custom`, not message mixins. `Cancel` is a sentinel command intercepted by the runtime before dispatch — it is never sent to Update as a message. Removed the buggy (for non-messages) behavior introduced by `include Message::Predicates`.

- **Message::Predicates `deconstruct_keys`**: Now calls `super` to preserve Data.define fields. Previously, including `Predicates` in a `Data.define` class would shadow all fields, returning only `{ type: ... }`. Now correctly returns `{ type: :my_message, envelope:, ...all_fields }`.

- **Message::Predicates type-based predicates**: Predicates like `message.user_fetched?` now return `true` when the predicate matches the message's `:type`. Previously all unknown predicates returned `false`, even when they matched the type.

- **Message::Predicates envelope-based predicates**: Predicates like `message.profile?` now return `true` when the predicate matches the message's `:envelope`. This enables convenient checks like `if message.profile?` alongside type checks.

### Removed

- **`Rooibos.route` helper**: Removed. Use the Router DSL (`forward`, `forward_events`, `forward_routed`) instead of manual command prefix wrapping.
- **`Rooibos.delegate` helper**: Removed. Use the Router DSL (`receive`, `observe`, `forward`) instead of manual message prefix dispatch.

## [0.6.2] - 2026-01-27

### Added

- **Router `action` DSL Enhancements**: Multiple syntax forms for declaring actions with inline keybindings:
  - Positional: `action :quit, -> { Command.exit }` (original)
  - Keyword: `action quit: -> { Command.exit }` (cleaner)
  - Inline keymap: `action quit: -> { Command.exit }, keymap: %i[ctrl_c q]`
  - `key:` singular alias: `action go_home: FileList, key: :~`
  - `keys:` plural alias: `action move_down: FileList, keys: %i[down j]`
  - Anonymous: `action -> { Command.exit }, keymap: %i[ctrl_c q]` (no name, just binding)
  - `mousemap:` for scroll bindings: `action scroll_up: ..., mousemap: %i[scroll_up]`

- **Routed Actions**: Actions can now target child fragments. When the value is a `Module`, the Router synthesizes a `Message::Routed` and dispatches to the child's Update:
  - `action move_down: FileList` — declares `FileList` as target
  - Key presses trigger `Message::Routed.new(envelope: :move_down, event: key_event)`

- **Message::Routed**: New message type for routed actions between parent and child fragments:
  - `deconstruct_keys` returns `{ type: :routed, envelope:, event: }`
  - Predicate methods via `method_missing`: `msg.move_down?`, `msg.go_back?`
  - Carries original event for full context in child Update

- **Keymap `key` DSL Enhancements**: Multiple syntax forms for declaring key handlers:
  - Variadic keys: `key :down, :j, action: :move_down` (multiple keys, one action)
  - `action:` keyword: `key :q, action: :quit` (explicit action reference)
  - Keyword syntax: `key q: -> { Command.exit }` (hash-style)
  - Multi-keyword: `keys ctrl_c: -> { ... }, q: -> { ... }` (multiple bindings)
  - Hash metaprogramming: `key(exit_bindings)` where `exit_bindings = { q: ..., esc: ... }`
  - `keys` alias: `alias_method :keys, :key` for readability

### Changed

### Fixed

### Removed

## [0.6.1] - 2026-01-26

### Added

### Changed

### Fixed

### Removed

## [0.6.0] - 2026-01-25

### Added

- **rooibos CLI**: New command-line interface installed as executable when you install the gem. Provides `rooibos new APP_NAME` to scaffold a complete Rooibos application using `bundle gem` conventions, and `rooibos run` to launch the application. The scaffolded app includes a working TUI that displays "Hello, Rooibos!" and exits on q or Ctrl+C, plus a passing test demonstrating `Rooibos::TestHelper` patterns.

- **Rooibos::Welcome**: Built-in welcome screen fragment available via `require "rooibos/welcome"`. Provides `Model`, `View`, `Update`, and `Init` constants that scaffolded apps delegate to. Features keyboard Tab/Shift+Tab focus cycling, mouse hover states, and clickable buttons for visiting the website or exiting. Use as a starting point or reference for building your own fragments.

- **Command::Custom#deconstruct_keys**: Default pattern matching support for custom commands. Introspects public query methods and returns a hash with `:type` as a snake_case discriminator. Data.define members are included automatically. Respects the `keys` argument for performance optimization. Override for hot paths or metaprogrammed methods.

- **Rooibos::TestHelper#assert_no_errors**: Test assertion to fail fast when `Message::Error` is unexpectedly present in collected messages. Works with Minitest (via `flunk`) and RSpec (via `raise`). Include via `include Rooibos::TestHelper`.

- **Message::Error**: New message type for command errors. Includes `error?` predicate and `deconstruct_keys` for pattern matching with `{ type: :error, command:, exception: }`.

- **Message::Canceled**: New message type for canceled commands. Includes `canceled?` predicate (with `cancelled?` alias for British spelling) and `deconstruct_keys` for pattern matching with `{ type: :canceled, command: }`. Custom command authors should emit this when `token.canceled?` is true.

- **Message Symbol Comparison**: All `Message::*` types now support symbol comparison via `to_sym` and `==`, similar to RatatuiRuby events. Symbols use the `message_` prefix to avoid collision with event types: `msg == :message_timer`, `msg == :message_http`, `msg == :message_error`. `Message::Predicates` also provides a smart-default `deconstruct_keys` that derives `:type` from the class name.

- **Rooibos::Message.=== for case/when dispatch**: The `Rooibos::Message` module now implements `===` for use in case/when statements. Matches only built-in framework message types (classes under `Rooibos::Message::`), rejecting key events and user-defined message classes. Enables Update functions to distinguish framework responses from user input.

- **Command.open**: Opens a file or URL with the system's default application. Cross-platform: uses `open` on macOS, `xdg-open` on Linux, `start` on Windows. Sends `Message::Open` on success (exit 0) or `Message::Error` on failure.

### Changed

- **BREAKING: Rooibos::TestHelper Include Pattern**: `Rooibos::TestHelper` now includes `RatatuiRuby::TestHelper` instead of the other way around. Previously, requiring `rooibos/test_helper` would inject Rooibos assertions into `RatatuiRuby::TestHelper`. Now, use `include Rooibos::TestHelper` to get both Rooibos assertions and RatatuiRuby test terminal helpers. Update your test classes from `include RatatuiRuby::TestHelper` to `include Rooibos::TestHelper`.

- **BREAKING: Rooibos.delegate Message Format**: `Rooibos.delegate` now passes `message[1]` (single value) to child UPDATEs instead of `message[1..]` (array slice). This aligns child fragments with the universal `{ type:, envelope: }` pattern. Update pattern matches from `in [{ type: :system, ... }]` to `in { type: :system, ... }`.

- **BREAKING: Command::Error → Message::Error**: Moved `Command::Error` to `Message::Error`. Commands flow *out* from Update; Messages flow *in* to Update. Error was always sent *to* Update so it belongs in the Message module. Includes `error?` predicate and `deconstruct_keys` for pattern matching with `{ type: :error, command:, exception: }`. Update pattern matches from `Command::Error` to `Message::Error`.

- **BREAKING: Timer/Batch Cancellation → Message::Canceled**: When `Command.wait`, `Command.tick`, `Command.all`, or `Command.batch` are canceled, they now send `Message::Canceled` instead of `Command.cancel(self)`. Custom command authors should do the same: when `token.canceled?`, emit `Message::Canceled.new(command: self)`. Update pattern matches from `in Command::Cancel` to `in Message::Canceled` or `in { type: :canceled, command: }`.

- **Dependency Update**: Now requires `ratatui_ruby ~> 1.2.0` (was `~> 1.0.0.beta.3`). This stable release adds inline sync mode for deterministic event ordering in tests.

### Fixed

- **Init runs after terminal initialization**: `Init` callables now run after the terminal is initialized, enabling them to call `RatatuiRuby.terminal_size`, compute layout areas, or perform other terminal-dependent initialization. Previously Init ran before the terminal was ready, causing "Terminal is not initialized" errors.

- **FPS timeout uses float division**: The runtime now uses `1.0 / fps` instead of `1 / fps` for poll timeout calculation. Integer division caused `1 / 60` to yield 0, resulting in busy-wait CPU spinning at 100%.

### Removed

- **BREAKING: Command::Error class**: Removed. Use `Message::Error` instead.
- **BREAKING: Command.error factory**: Removed. Use `Message::Error.new(command:, exception:)` instead.

## [0.5.0] - 2026-01-16

### Added

### Changed

- **BREAKING: Rebrand to Rooibos**: The gem is now named `rooibos` and the module is top-level `Rooibos` instead of `RatatuiRuby::Tea`. Update your code, including:
  - `require "ratatui_ruby/tea"` → `require "rooibos"`
  - `RatatuiRuby::Tea::*` → `Rooibos::*`
  - If you need a full migration guide, reach out to [the forum](https://forum.setdef.com/c/ratatui-ruby/6)

### Fixed

### Removed

## [0.4.0] - 2026-01-16

### Added

- **Timer Commands**: `Command.wait(seconds, tag)` and `Command.tick(seconds, tag)` for timed events. After the duration, sends `tag` to the update function. Responds to cancellation cooperatively — sends `Command.cancel(self)` when cancelled so you can handle it. Uses `Concurrent::Cancellation.timeout` internally. `Command.tick` is an alias for `Command.wait`; the "recurring tick" pattern is achieved by re-dispatching in the update function.

- **Command.uncancellable Factory**: Creates a fresh `Concurrent::Cancellation` that never fires. Use for commands wrapping non-cancellable blocking I/O (e.g., `Net::HTTP` requests).

- **Command.batch**: Fire-and-forget parallel execution. `Command.batch(cmd1, cmd2)` or `Command.batch([cmds])` runs children in parallel; each child sends its own messages independently. On cancellation, emits `Command.cancel(self)` so you can detect the batch was stopped. Child errors surface as `Command::Error` so you can handle failures in your update function. One failing child does not stop the others. Requires all child commands to be Ractor-shareable.

- **Command.all**: Aggregating parallel execution. `Command.all(:tag, cmd1, cmd2)` or `Command.all(:tag, [cmds])` runs children in parallel and waits for all to complete, then sends a single aggregated message. Array syntax produces `[:tag, [results]]`; variadic syntax splats results as `[:tag, result1, result2]`. On cancellation, emits `Command.cancel(self)`. Child errors surface as `Command::Error`. Requires all child commands to be Ractor-shareable.

- **Outlet#source**: Command composition for multi-step workflows. `out.source(child_command, token, timeout: 30.0)` runs a child command synchronously within a custom command, returning its result (or `nil` if cancelled/timed out). Exceptions from failed children propagate to the caller. Use this to orchestrate sequential API calls, conditional fetches, or any workflow that needs one result before starting the next.

- **Command.http**: Native HTTP client for API calls. Supports GET, POST, PUT, PATCH, DELETE with DWIM syntax: `Command.http(get: 'url')`, `Command.http(:get, 'url', :tag)`, etc. Returns hash-based `HttpResponse` with `deconstruct_keys` for pattern matching: `{ type: :http, envelope:, status:, body:, headers: }` or `{ type: :http, envelope:, error: }`. Optional `parser:` keyword invokes a callable on the response body for JSON, YAML, CSV, or custom parsing. SSL, default 10s timeout, and cancellation-before-request are supported. Parsers and parsed results must be Ractor-shareable.

- **Streaming Command Data Loss Fix**: Fixed race condition in `Command.system(stream: true)` where fast commands could lose stdout/stderr data. Reader threads now `join` instead of `kill` to ensure all output is processed before completion.

- **Message::Predicates Mixin**: Include in custom message types for safe predicate calls. Returns `false` for any unknown predicate method (ending in `?`). Enables pattern matching workflows where messages can respond to predicates like `msg.http?` or `msg.timer?` without raising `NoMethodError`. Includes `respond_to_missing?` for introspection parity.

- **Message::Timer**: Predicate-rich response type for timer commands (`Command.wait`, `Command.tick`). Includes `timer?` predicate and `deconstruct_keys` for pattern matching with `type: :timer` discriminator. Contains `envelope` (routing symbol) and `elapsed` (actual wait time in seconds).

- **Message::HttpResponse**: Moved from `Command::HttpResponse` to `Message::HttpResponse` with added predicates. Includes `http?`, `success?`, and `error?` predicates. Implements `deconstruct_keys` for pattern matching with `type: :http` discriminator.

- **Message::System::Batch**: Response type for `Command.system` (batch mode). Includes `system?`, `success?` (exit 0), and `error?` (non-zero exit) predicates. Contains `envelope`, `stdout`, `stderr`, and `status`. Implements `deconstruct_keys` for pattern matching.

- **Message::System::Stream**: Response type for `Command.system(..., stream: true)`. Includes `system?`, `stdout?`, `stderr?`, and `complete?` predicates. Contains `envelope`, `stream` type (`:stdout`, `:stderr`, `:complete`), `content` (for output lines), and `status` (for completion). Implements conditional `deconstruct_keys` based on stream type.

- **Message::All**: Response type for `Command.all` aggregating parallel execution. Includes `all?` predicate. Contains `envelope`, `results` array, and `nested` boolean. Implements `deconstruct_keys` for pattern matching.

- **Command Parameter Rename**: Renamed `tag` parameter to `envelope` across all commands for consistency: `Command.wait`, `Command.tick`, `Command.system`, and `Command.all`. These now use `envelope:` in their data definitions. Messages emit with `envelope:` for pattern matching.

- **Dependencies**: Added `concurrent-ruby` (~> 1.3) and `concurrent-ruby-edge` (~> 0.7) for robust concurrency primitives.

- **Rooibos.normalize_init Helper**: New `Rooibos.normalize_init(result)` normalizes Init callable returns. Accepts the output of a `Fragment.Init` callable and always returns `[model, command]`. Use when composing child fragment initialization in parent fragments.

### Changed

- **Terminology: "Bag" → "Fragment"**: Renamed Fractal Architecture units from "bags" to "fragments" throughout the codebase. A fragment is a module containing `Model`, `INITIAL`, `UPDATE`, and `VIEW` constants. Parent fragments compose child fragments via routing. The `examples/app_fractal_dashboard/bags/` directory is now `examples/app_fractal_dashboard/fragments/`. All API documentation, code comments, and examples updated to reflect this terminology change.

- **Runtime API Signature (Breaking)**: `Rooibos.run` signature changed:
  - Fragment parameter is now **positional** instead of keyword: `Rooibos.run(MyApp)` instead of `Rooibos.run(fragment: MyApp)`
  - Removed `argv:` and `env:` parameters - Runtime now automatically uses `ARGV` and `ENV` globals
  - Added `fps:` parameter (default 60) for configurable frame rate
  - Renamed `init:` parameter to `command:` in explicit parameters API for clarity

- **Fragment Convention Rename (Breaking)**: Fragment constants have new naming conventions:
  - `INITIAL` constant → `Init` callable. The runtime calls `Init.()` to get the initial model.
  - `UPDATE` constant → `Update` callable (capitalized).
  - `VIEW` constant → `View` callable (capitalized).
  - Init is now a lambda/callable instead of a frozen constant. This enables parameterized initialization and returning `[model, command]` tuples for initial commands.

- **Internal Method Rename (Breaking)**: `Runtime.normalize_update_result` renamed to `Runtime.normalize_update_return` for clarity. Only affects code calling private Runtime internals.

- **Command.custom Ractor Validation (Breaking)**: `Command.custom(callable)` now validates in debug mode that the callable is Ractor-shareable. Callables that capture mutable state will raise `Invariant`. Define callables at module level or use `Ractor.make_shareable`.

- **Model Validation Timing (Breaking)**: Runtime now validates model Ractor-shareability **immediately after Init returns**, not just during the Update cycle. This catches mutable models earlier, enforcing immutability at startup. Models must be frozen (`.freeze`) or use immutable data structures (`Data.define`). This is a good breaking change that prevents subtle concurrency bugs.

- **CancellationToken Replaced (Breaking)**: Custom commands now receive `Concurrent::Cancellation` instead of `CancellationToken`. The method to check cancellation changes from `token.cancelled?` (British) to `token.canceled?` (American).

- **Outlet Accepts Channel (Breaking)**: `Outlet.new` now accepts a `Concurrent::Promises::Channel` instead of `Thread::Queue`.

- **Outlet#put (Breaking)**: `out.put(msg)`, the common case now sends `msg` directly instead of `[msg]`; `out.put(a, b, c)` sends `[a, b, c]`. Previously all calls wrapped arguments in an array. Update functions that matched `when Array` may need adjustment.

- **Command.all Output (Breaking)**: `Command.all` now emits `Message::All` objects instead of raw arrays. Previously emitted `[:tag, [results]]` (nested) or `[:tag, result1, result2]` (variadic). Now emits `Message::All` with `envelope`, `results`, and `nested` fields. Use hash pattern matching: `in { type: :all, envelope:, results:, nested: }`.

### Fixed

- **Streaming Command Data Loss**: Fixed race condition where fast commands (e.g., `echo hello`) could lose stdout/stderr messages. The streaming reader threads were being killed immediately after the child process exited, before they could finish reading buffered output. Now the runtime joins the reader threads to ensure all data is processed before sending `:complete`.

### Removed

- **CancellationToken Class**: Removed in favor of `Concurrent::Cancellation` from concurrent-ruby-edge.
- **CancellationToken::NONE**: Removed. Use `Command.uncancellable` factory instead.

## [0.3.1] - 2026-01-11

### Added

- **CancellationToken**: Cooperative cancellation mechanism for long-running custom commands. Commands check `cancelled?` periodically and stop gracefully when `cancel!` is called. Includes `CancellationToken::NONE` null object for commands that ignore cancellation.

- **Command::Custom Mixin**: Include in your class to mark it as a custom command. Provides `rooibos_command?` brand predicate and `rooibos_cancellation_grace_period` (default 2.0 seconds) for configuring cleanup time after cancellation.

- **Command::Outlet**: Messaging gateway for custom commands. Use `put(tag, *payload)` to send results back to the update function. Validates Ractor-shareability in debug mode.

- **Custom Command Dispatch**: Runtime now dispatches custom commands (objects with `rooibos_command?` returning true) in background threads. Commands receive an `Outlet` for messaging and a `CancellationToken` for cooperative shutdown.

- **Command.custom Factory**: Wraps lambdas/procs to give them unique identity for dispatch tracking. Each `Command.custom(callable)` call produces a distinct wrapper, enabling targeted cancellation. Accepts optional `grace_period:` to override the default 2.0 second cleanup window.

- **Command.cancel Factory**: Request cancellation of a running command. Returns a `Command::Cancel` sentinel that the runtime routes to the appropriate command's CancellationToken.

- **Runtime Cancellation Dispatch**: The runtime now handles `Command::Cancel` by signaling the target command's `CancellationToken`, enabling cooperative cancellation of long-running commands. Respects `rooibos_cancellation_grace_period`: waits for the grace period, then orphans unresponsive threads. Use `Float::INFINITY` to wait indefinitely for cooperative exit.

- **Graceful Shutdown**: On exit, runtime signals all active commands then respects each command's grace period. Commands with `Float::INFINITY` grace are waited on indefinitely (user has SIGKILL). Final queue messages are processed before returning.

- **Automatic Error Propagation**: Custom commands that raise unhandled exceptions now produce a `Command::Error` message instead of corrupting the TUI display. The runtime catches exceptions and pushes `Command::Error.new(command:, exception:)` to the queue. Pattern match on `Command::Error` in your update function to handle failures uniformly. Factory method `Command.error(command, exception)` is available for testing.

- **Command::System Cancellation**: Streaming shell commands now respect cooperative cancellation. When cancelled, sends `SIGTERM` for graceful shutdown, then `SIGKILL` if the child process doesn't exit. Prevents orphaned child processes from lingering after app exit.

### Changed

### Fixed

- **Ractor Enforcement is Debug-Only**: The Ractor-shareability check now only runs in debug mode (and automated tests). Production skips this check for performance, matching the original specification. Previously, the check ran unconditionally.

### Removed

## [0.3.0] - 2026-01-08

### Added

- **Router DSL**: New `Rooibos::Router` module provides declarative routing for Fractal Architecture:
  - `route :prefix, to: ChildBag` — declares a child bag route
  - `keymap { key "q", -> { Command.exit } }` — declares keyboard handlers
  - `keymap { key "x", handler, when: -> (m) { m.ready? } }` — guards (also: `if:`, `only:`, `guard:`, `unless:`, `except:`, `skip:`)
  - `keymap { only when: guard do ... end }` — nested guard blocks apply to all keys within (also: `skip when: ...`)
  - `mousemap { click -> (x, y) { ... } }` — declares mouse handlers
  - `action :name, handler` — declares reusable actions for key/mouse handlers
  - `from_router` — generates an UPDATE lambda from routes and handlers

- **Composition Helpers**: New helper methods for Fractal Architecture reduce boilerplate:
  - `Rooibos.route(command, :prefix)` — wraps a command to route results to a child bag
  - `Rooibos.delegate(message, :prefix, child_update, child_model)` — dispatches prefixed messages to child bags

- **Command Mapping**: `Command.map(inner_command, &mapper)` wraps a child command and transforms its result message. Essential for parent bags routing child command results.

- **Shortcuts Module**: `require "rooibos/shortcuts"` and `include Rooibos::Shortcuts` for short aliases:
  - `Cmd.exit` — alias for `Command.exit`
  - `Cmd.sh(command, tag)` — alias for `Command.system`
  - `Cmd.map(command, &block)` — alias for `Command.map`

- **Sync Event Integration**: Runtime now handles `Event::Sync` from `RatatuiRuby::SyntheticEvents`. When a Sync event is received, the runtime waits for all pending async threads and processes their results before continuing. Use `inject_sync` in tests for deterministic async verification.

- **Streaming Command Output**: `Command.system` now accepts a `stream:` keyword argument. When `stream: true`, the runtime sends incremental messages (`[:tag, :stdout, line]`, `[:tag, :stderr, line]`) as output arrives, followed by `[:tag, :complete, {status:}]` when the command finishes. Invalid commands send `[:tag, :error, {message:}]`. Default behavior (`stream: false`) remains unchanged.

- **Custom Shell Modal Example**: Added `examples/app_fractal_dashboard/bags/custom_shell_modal.rb` demonstrating a 3-bag fractal architecture for a modal that runs arbitrary shell commands with streaming output. Features interleaved stdout/stderr, exit status indication, and Ractor-safe implementation using `tui.overlay` for opaque rendering.

### Changed

- **Command Module Rename (Breaking)**: The `Cmd` module is now `Command` with Rubyish naming:
  - `Cmd::Quit` → `Command::Exit` (use `Command.exit` factory)
  - `Cmd::Exec` → `Command::System` (use `Command.system(cmd, tag)` factory)

### Fixed

### Removed

## [0.2.0] - 2026-01-08

### Added

- **The Elm Architecture (TEA)**: Implemented the core Model-View-Update (MVU) runtime. Use `Rooibos.run(model, view: ..., update: ...)` to start an interactive application with predictable state management.
- **Async Command System**: Side effects (database, HTTP, shell) are executed asynchronously in a thread pool. Results are dispatched back to the main loop as messages, ensuring the UI never freezes.
- **Ractor Safety Enforcement**: The runtime strictly enforces that all `Model` and `Message` objects are Ractor-shareable (deeply frozen). This guarantees thread safety by design and prepares for future parallelism.
- **Flexible Update Returns**: The `update` function supports multiple return signatures for developer ergonomics:
  - `[Model, Cmd]` — Standard tuple.
  - `Model` — Implicitly `[Model, Cmd::None]`.
  - `Cmd` — Implicitly `[CurrentModel, Cmd]`.
- **Startup Commands**: `Rooibos.run` accepts an `init:` parameter to dispatch an initial command immediately after startup, useful for loading initial data without blocking the first render.
- **View Validation**: The `view` function must return a valid widget. Returning `nil` raises `RatatuiRuby::Error::Invariant` to catch bugs early.


## [0.1.0] - 2026-01-07

### Added

- **First Release**: Empty release of `rooibos`, a Ruby implementation of The Elm Architecture (TEA) for `ratatui_ruby`. Scaffolding generated by `ratatui_ruby-devtools`.

[Unreleased]: https://github.com/setdef/Rooibos/releases/tag/HEAD
[0.6.2]: https://github.com/setdef/Rooibos/releases/tag/v0.6.2
[0.6.1]: https://github.com/setdef/Rooibos/releases/tag/v0.6.1
[0.6.0]: https://github.com/setdef/Rooibos/releases/tag/v0.6.0
[0.5.0]: https://github.com/setdef/Rooibos/releases/tag/v0.5.0
[0.4.0]: https://github.com/setdef/Rooibos/releases/tag/v0.4.0
[0.3.1]: https://github.com/setdef/Rooibos/releases/tag/v0.3.1
[0.3.0]: https://github.com/setdef/Rooibos/releases/tag/v0.3.0
[0.2.0]: https://github.com/setdef/Rooibos/releases/tag/v0.2.0
[0.1.0]: https://github.com/setdef/Rooibos/releases/tag/v0.1.0