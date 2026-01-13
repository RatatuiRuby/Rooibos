<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Custom Commands Design (`ratatui_ruby-tea`)

This document describes the architectural design and guiding principles of custom commands in `ratatui_ruby-tea`. It is intended for contributors, architects, and AI agents working on the codebase.

## Core Abstractions

Custom commands extend Tea with user-defined side effects: WebSockets, gRPC, database polling, background workers. The architecture provides four key components:

| Component | Purpose |
|-----------|---------|
| `Command::Custom` | Mixin for command identification |
| `Command::Outlet` | Messaging gateway for result delivery |
| `Command::CancellationToken` | Cooperative cancellation mechanism |
| `Command.custom { ... }` | Wrapper giving callables unique identity |

---

## Guiding Design Principles

### 1. Messaging Gateway over Raw Queue

Commands produce messages. Those messages cross threads. Without abstraction, queue manipulation scatters across the codebase.

The Outlet wraps the internal queue with a domain-specific API. Commands call `out.put(:tag, data)` instead of managing queue details. Debug mode validates Ractor-shareability automatically—commands cannot accidentally push unshareable data.

| Aspect | Raw Queue | Outlet |
|--------|-----------|--------|
| Ractor safety | Manual | Automatic |
| Error messages | Generic | Contextual |
| API | `queue << Ractor.make_shareable([...])` | `out.put(:tag, data)` |
| Pattern | Implementation detail | **Messaging Gateway** |

This implements the **Messaging Gateway** pattern from Enterprise Integration Patterns. The Outlet is a **Facade** (Gang of Four) over the queue, and acts as a **Channel Adapter** translating command results into update function messages.

### 2. Cooperative Cancellation over Thread Termination

Long-running commands block the event loop. WebSocket listeners, database pollers, and streaming connections run indefinitely until stopped. Stopping them abruptly corrupts state.

`Thread#kill` terminates immediately. Mutexes may deadlock. Resources may leak. Database transactions may abort mid-write.

The `CancellationToken` signals cancellation requests. Commands check `token.cancelled?` periodically and stop at safe points. Cleanup code runs. Resources release. Transactions commit.

| Aspect | `Thread#kill` | CancellationToken |
|--------|---------------|------------------|
| Cleanup | None (immediate termination) | Command controls cleanup |
| Resource safety | May corrupt state | Clean shutdown |
| Mutexes | May deadlock | Released properly |
| Pattern | Forceful | **Cooperative** |

**Configurable grace periods** accommodate different cleanup needs:

- `0.5` seconds — Quick HTTP abort, minimal cleanup
- `2.0` seconds — Default, suitable for most commands
- `5.0` seconds — WebSocket close handshake with remote server
- `Float::INFINITY` — Never force-kill (database transactions)

### 3. Command Identity via Object Reference

The runtime tracks active commands by their object identity. When the update function returns `Command.cancel(handle)`, the runtime looks up that exact object in its registry and signals its token.

Class-based commands get unique identity automatically—each `MyCommand.new` produces a distinct object. Reusable lambdas and procs share identity. Dispatch them twice, and cancellation would affect both.

`Command.custom(callable)` wraps a callable in a unique container. Each call produces a distinct handle. Store it in your model. Cancel it later by returning `Command.cancel(handle)`.

### 4. Automatic Error Propagation

Commands run in threads. Exceptions bubble up silently. The update function never sees them. Backtraces written to STDERR corrupt the TUI display.

The runtime catches unhandled exceptions and pushes `Command::Error` to the queue. This is automatic—commands do not rescue exceptions unless they want custom handling. The update function pattern-matches on `Command::Error` and reacts appropriately.

This mirrors the sentinel pattern used for `Command::Exit` and `Command::Cancel`.

**Error categorization:** We use a single `Command::Error` sentinel for all command exceptions. Distinguishing "framework bugs" vs "user bugs" at the sentinel level adds complexity with marginal benefit. Instead, exception *classes* provide the signal:

| Exception Class | Source |
|-----------------|--------|
| `RatatuiRuby::Error::Invariant` | Framework validation (debug mode) |
| `RatatuiRuby::Error::Internal` | Framework bugs |
| `ArgumentError`, `RuntimeError`, etc. | User code |

The update function can pattern-match on `error_msg.exception.class` if it needs to distinguish sources.

### 5. Ractor Readiness

This design is forward-compatible with Ruby's Ractor-based parallelism.

**What's already shareable:**

| Pattern | Shareable? | Why |
|---------|------------|-----|
| Module-constant lambda | ✅ Yes | `self` is the frozen module |
| Closure-free block | ✅ Yes | No captured variables |
| `Data.define` command | ✅ Yes | Immutable by definition |
| Frozen class instance | ✅ Yes | Deeply frozen |

**Debug mode validation:**

In debug mode, Tea validates Ractor shareability at dispatch time. `Ractor.shareable?(command)` catches most issues. The Outlet's `put` method validates messages before pushing them to the queue.

**Why Thread dispatch is Ractor-safe:**

Commands execute in Threads within the **main Ractor**. Only messages (via Outlet) cross the shareability boundary. The `CancellationToken` stays within its Thread—never shared across Ractors. The `@active_commands` hash is local to the Runtime (main Ractor).

When Ruby evolves to true Ractor parallelism, this design upgrades transparently: commands are already validated as shareable, so they could be sent to worker Ractors without code changes.

---

## Pattern Lineage

This design implements several established patterns from the software architecture literature.

### Design Patterns (Gang of Four)

| Component | Pattern |
|-----------|---------|
| Custom Mixin | **Command** — Encapsulates a request as an object |
| Outlet | **Facade** — Simplified interface to a complex subsystem |
| Runtime | **Mediator** — Coordinates command dispatch and message routing |
| Update Function | **State** — Behavior changes based on internal state |

### Enterprise Integration Patterns (Hohpe & Woolf)

| Component | Pattern |
|-----------|---------|
| Outlet | **Messaging Gateway** — Wraps message channel access |
| Outlet | **Channel Adapter** — Connects applications to messaging systems |
| Queue | **Point-to-Point Channel** — Single consumer receives each message |

### Cancellation Patterns

| Platform | Mechanism | Relationship |
|----------|-----------|--------------|
| **.NET** | `CancellationToken` | Direct inspiration for API design |
| **Go** | `context.Context` | Cooperative cancellation via `ctx.Done()` |
| **JavaScript** | `AbortController` | Web Fetch API cancellation |
| **Java** | `Thread.interrupt()` | Flag-based cooperative cancellation |
| **Kotlin** | `Job.cancel()` | Coroutine cancellation |

---

## Prior Art

### The Elm Architecture (TEA)

| Framework | Language | Notes |
|-----------|----------|-------|
| **Elm** | Elm | Original TEA; `Cmd` + `Sub` primitives |
| **BubbleTea** | Go | TUI implementation; "Subscriptions are Loops" philosophy |
| **Iced** | Rust | GUI TEA with Command + Subscription |
| **Miso** | Haskell | Web TEA with Effect + Sub |
| **Bolero** | F# | Web TEA with Cmd + Sub |

### Redux Ecosystem

| Library | Pattern | Mapping |
|---------|---------|---------|
| **Redux Thunk** | Raw dispatch access | Direct queue access (rejected) |
| **Redux Saga** | `put()` effect dispatches actions | **Outlet#put** ← adopted |
| **Redux Observable** | RxJS Observables | RxRuby (rejected for complexity) |
| **redux-loop** | Elm-style Cmd | Recursive commands |

Redux Saga's `put()` is the direct inspiration for `out.put()`. The Saga pattern—long-running processes that listen for actions and dispatch new ones—maps directly to Tea's custom commands.

### Ruby Ecosystem

| Library | Pattern | Relationship |
|---------|---------|--------------|
| **Observable** (stdlib) | Observer pattern | Similar push semantics, lacks thread-safety |
| **Concurrent Ruby** | Actor, Promises | More complex than needed |
| **Celluloid** | Actor mailboxes | Inspiration for internal terminology |
| **Sidekiq** | Background jobs | Similar "fire command, receive result" model |

---

## Key Influences Summary

| Influence | What We Adopted |
|-----------|-----------------|
| **Elm** | MVU architecture, Cmd/Msg pattern |
| **BubbleTea** | "Subscriptions are Loops" philosophy |
| **Redux Saga** | `put()` for message dispatch |
| **.NET CancellationToken** | Cooperative cancellation with grace periods |
| **EIP Messaging Gateway** | Outlet as infrastructure abstraction |
| **Go context.Context** | Cancellation propagation pattern |

---

## Further Reading

### External Resources

- [Elm Guide](https://guide.elm-lang.org/) — Official Elm documentation covering commands and effects
- [BubbleTea](https://github.com/charmbracelet/bubbletea) — Go TUI framework based on The Elm Architecture
- [Redux Saga](https://redux-saga.js.org/) — Saga pattern and `put()` effect documentation
- [Enterprise Integration Patterns](https://www.enterpriseintegrationpatterns.com/) — Messaging patterns reference by Hohpe & Woolf

### Academic References

1. **Gamma, Helm, Johnson, Vlissides** (1994). *Design Patterns: Elements of Reusable Object-Oriented Software*. Addison-Wesley.
   - Command, Facade, Mediator, State patterns

2. **Fowler, M.** (2002). *Patterns of Enterprise Application Architecture*. Addison-Wesley.
   - Gateway pattern

3. **Hohpe, G. & Woolf, B.** (2003). *Enterprise Integration Patterns*. Addison-Wesley.
   - Messaging Gateway, Message Channel, Point-to-Point Channel, Channel Adapter

4. **Joshi, U.** (2023). *Patterns of Distributed Systems*. Addison-Wesley.
   - Write-Ahead Log, Thread Pool
