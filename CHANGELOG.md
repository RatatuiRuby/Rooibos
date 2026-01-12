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

- **Command.uncancellable Factory**: Creates a fresh `Concurrent::Cancellation` that never fires. Use for commands wrapping non-cancellable blocking I/O (e.g., `Net::HTTP` requests).

- **Dependencies**: Added `concurrent-ruby` (~> 1.3) and `concurrent-ruby-edge` (~> 0.7) for robust concurrency primitives.

### Changed

- **CancellationToken Replaced (Breaking)**: Custom commands now receive `Concurrent::Cancellation` instead of `CancellationToken`. The method to check cancellation changes from `token.cancelled?` (British) to `token.canceled?` (American).

- **Outlet Accepts Channel (Breaking)**: `Outlet.new` now accepts a `Concurrent::Promises::Channel` instead of `Thread::Queue`.

### Fixed

### Removed

- **CancellationToken Class**: Removed in favor of `Concurrent::Cancellation` from concurrent-ruby-edge.
- **CancellationToken::NONE**: Removed. Use `Command.uncancellable` factory instead.

## [0.3.1] - 2026-01-11

### Added

- **CancellationToken**: Cooperative cancellation mechanism for long-running custom commands. Commands check `cancelled?` periodically and stop gracefully when `cancel!` is called. Includes `CancellationToken::NONE` null object for commands that ignore cancellation.

- **Command::Custom Mixin**: Include in your class to mark it as a custom command. Provides `tea_command?` brand predicate and `tea_cancellation_grace_period` (default 2.0 seconds) for configuring cleanup time after cancellation.

- **Command::Outlet**: Messaging gateway for custom commands. Use `put(tag, *payload)` to send results back to the update function. Validates Ractor-shareability in debug mode.

- **Custom Command Dispatch**: Runtime now dispatches custom commands (objects with `tea_command?` returning true) in background threads. Commands receive an `Outlet` for messaging and a `CancellationToken` for cooperative shutdown.

- **Command.custom Factory**: Wraps lambdas/procs to give them unique identity for dispatch tracking. Each `Command.custom(callable)` call produces a distinct wrapper, enabling targeted cancellation. Accepts optional `grace_period:` to override the default 2.0 second cleanup window.

- **Command.cancel Factory**: Request cancellation of a running command. Returns a `Command::Cancel` sentinel that the runtime routes to the appropriate command's CancellationToken.

- **Runtime Cancellation Dispatch**: The runtime now handles `Command::Cancel` by signaling the target command's `CancellationToken`, enabling cooperative cancellation of long-running commands. Respects `tea_cancellation_grace_period`: waits for the grace period, then force-kills unresponsive threads. Use `Float::INFINITY` to never force-kill.

- **Graceful Shutdown**: On exit, runtime signals all active commands then respects each command's grace period. Commands with `Float::INFINITY` grace are waited on indefinitely (user has SIGKILL). Final queue messages are processed before returning.

- **Automatic Error Propagation**: Custom commands that raise unhandled exceptions now produce a `Command::Error` message instead of corrupting the TUI display. The runtime catches exceptions and pushes `Command::Error.new(command:, exception:)` to the queue. Pattern match on `Command::Error` in your update function to handle failures uniformly. Factory method `Command.error(command, exception)` is available for testing.

- **Command::System Cancellation**: Streaming shell commands now respect cooperative cancellation. When cancelled, sends `SIGTERM` for graceful shutdown, then `SIGKILL` if the child process doesn't exit. Prevents orphaned child processes from lingering after app exit.

### Changed

### Fixed

- **Ractor Enforcement is Debug-Only**: The Ractor-shareability check now only runs in debug mode (and automated tests). Production skips this check for performance, matching the original specification. Previously, the check ran unconditionally.

### Removed

## [0.3.0] - 2026-01-08

### Added

- **Router DSL**: New `Tea::Router` module provides declarative routing for Fractal Architecture:
  - `route :prefix, to: ChildBag` — declares a child bag route
  - `keymap { key "q", -> { Command.exit } }` — declares keyboard handlers
  - `keymap { key "x", handler, when: -> (m) { m.ready? } }` — guards (also: `if:`, `only:`, `guard:`, `unless:`, `except:`, `skip:`)
  - `keymap { only when: guard do ... end }` — nested guard blocks apply to all keys within (also: `skip when: ...`)
  - `mousemap { click -> (x, y) { ... } }` — declares mouse handlers
  - `action :name, handler` — declares reusable actions for key/mouse handlers
  - `from_router` — generates an UPDATE lambda from routes and handlers

- **Composition Helpers**: New helper methods for Fractal Architecture reduce boilerplate:
  - `Tea.route(command, :prefix)` — wraps a command to route results to a child bag
  - `Tea.delegate(message, :prefix, child_update, child_model)` — dispatches prefixed messages to child bags

- **Command Mapping**: `Command.map(inner_command, &mapper)` wraps a child command and transforms its result message. Essential for parent bags routing child command results.

- **Shortcuts Module**: `require "ratatui_ruby/tea/shortcuts"` and `include Tea::Shortcuts` for short aliases:
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

- **The Elm Architecture (TEA)**: Implemented the core Model-View-Update (MVU) runtime. Use `RatatuiRuby::Tea.run(model, view: ..., update: ...)` to start an interactive application with predictable state management.
- **Async Command System**: Side effects (database, HTTP, shell) are executed asynchronously in a thread pool. Results are dispatched back to the main loop as messages, ensuring the UI never freezes.
- **Ractor Safety Enforcement**: The runtime strictly enforces that all `Model` and `Message` objects are Ractor-shareable (deeply frozen). This guarantees thread safety by design and prepares for future parallelism.
- **Flexible Update Returns**: The `update` function supports multiple return signatures for developer ergonomics:
  - `[Model, Cmd]` — Standard tuple.
  - `Model` — Implicitly `[Model, Cmd::None]`.
  - `Cmd` — Implicitly `[CurrentModel, Cmd]`.
- **Startup Commands**: `RatatuiRuby::Tea.run` accepts an `init:` parameter to dispatch an initial command immediately after startup, useful for loading initial data without blocking the first render.
- **View Validation**: The `view` function must return a valid widget. Returning `nil` raises `RatatuiRuby::Error::Invariant` to catch bugs early.


## [0.1.0] - 2026-01-07

### Added

- **First Release**: Empty release of `ratatui_ruby-tea`, a Ruby implementation of The Elm Architecture (TEA) for `ratatui_ruby`. Scaffolding generated by `ratatui_ruby-devtools`.

[Unreleased]: https://git.sr.ht/~kerrick/ratatui_ruby-tea/refs/HEAD
[0.3.1]: https://git.sr.ht/~kerrick/ratatui_ruby-tea/refs/v0.3.1
[0.3.0]: https://git.sr.ht/~kerrick/ratatui_ruby-tea/refs/v0.3.0
[0.2.0]: https://git.sr.ht/~kerrick/ratatui_ruby-tea/refs/v0.2.0
[0.2.0]: https://git.sr.ht/~kerrick/ratatui_ruby-tea/refs/v0.2.0
[0.1.0]: https://git.sr.ht/~kerrick/ratatui_ruby-tea/refs/v0.1.0