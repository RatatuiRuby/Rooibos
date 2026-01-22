<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Documentation Stub Audit

Audit of learning objectives against the actual Rooibos codebase.

**Legend:**
- ✅ Grounded, complete, accurate
- ⚠️ Minor issue or suggestion
- ❌ Major issue, needs revision

---

## Essentials

### `the_elm_architecture.md`

**Objectives:**
1. Explain Model-View-Update in your own words
2. Describe how unidirectional data flow prevents bugs
3. Compare MVU to Rails request/response cycle
4. Draw the MVU loop from memory

**Audit:**
- ✅ All objectives are conceptual/educational — appropriate for this foundational doc
- ✅ `Runtime.run` accepts `model:`, `view:`, `update:` kwargs confirming the three pillars
- ✅ Examples use `Model`, `INITIAL`, `VIEW`, `UPDATE` constants
- ⚠️ Consider adding: "Identify the three callables: Init, Update, View" — the codebase uses Init (callable that returns initial model+command) which is the fourth concept beyond MVU

---

### `models.md`

**Objectives:**
1. Design application state with `Data.define`
2. Explain why Rooibos uses immutable structs instead of instance variables
3. Choose between flat and nested state structures
4. Create new state with `.with()` instead of mutation
5. Recognize when your Model is getting too complex

**Audit:**
- ✅ `Data.define` used in all examples (15+ instances across fragments)
- ✅ `.with()` used in UPDATE functions (e.g., `disk_usage.rb:36`: `model.with(output: ...)`)
- ✅ Nested state shown in `stats_panel.rb`: `Model = Data.define(:system_info, :disk_usage)`
- ✅ Flat state shown in `disk_usage.rb`: `Model = Data.define(:output, :loading)`
- ⚠️ Objective 5 ("too complex") is subjective — consider making it actionable: "Split a complex Model into nested fragments"

---

### `messages.md`

**Objectives:**
1. Define message types that describe what happened in your app
2. Use pattern matching (`case/in`) to route messages to handlers
3. Apply predicate helpers (`.key?`, `.q?`) for keyboard events
4. Design a message vocabulary for your domain

**Audit:**
- ✅ `case message` pattern matching used in 12+ UPDATE functions across examples
- ✅ `.q?` predicate used extensively (19 instances in tests/examples)
- ✅ `.key?` predicate defined in RatatuiRuby (`lib/ratatui_ruby/event.rb:85`)
- ⚠️ Messages are RatatuiRuby events or custom hashes — clarify that Rooibos doesn't define a Message type

---

### `update_functions.md`

**Objectives:**
1. Write pure functions that return `[new_model, command]`
2. Explain why side effects are forbidden in UPDATE
3. Use `Command.none` when no async work is needed
4. Structure complex UPDATE logic with helper methods

**Audit:**
- ✅ All examples return `[model, command]` or `[model, nil]` tuples
- ✅ `Runtime.normalize_update_return` enforces the tuple contract
- ❌ **`Command.none` does not exist** — examples use `nil` instead. Either add `Command.none` or change objective to "Return `nil` when no async work is needed"
- ✅ Helper methods shown in `update_manual.rb` (e.g., `delegate_to_child`)

---

### `views.md`

**Objectives:**
1. Explain what a VIEW function returns (RatatuiRuby widgets)
2. Compose layouts using Rect, Constraint, and Layout (see RatatuiRuby docs)
3. Understand that VIEW is called on every render (keep it fast)
4. Know when to link out to RatatuiRuby for widget details

**Audit:**
- ✅ VIEW functions in examples return `tui.paragraph(...)`, `tui.block(...)` etc.
- ✅ Layouts are RatatuiRuby responsibility — correctly deferred
- ⚠️ Consider adding: "VIEW receives `(model, tui)` arguments" — the signature isn't obvious
- ⚠️ Consider adding: "VIEW can accept extra kwargs for fragment composition" (see `View = -> (model, tui, disabled: false)`)

---

### `commands.md`

**Objectives:**
1. Choose the right built-in command (`wait`, `http`, `batch`, `all`, `none`)
2. Explain the command lifecycle: dispatch → execute → message
3. Compare Commands to React useEffect
4. Combine multiple commands with `Command.batch`

**Audit:**
- ✅ `Command.wait` exists (line 468)
- ✅ `Command.http` exists (line 539)
- ✅ `Command.batch` exists (line 488)
- ✅ `Command.all` exists (line 518)
- ❌ **`Command.none` does not exist** — remove from objective or add to codebase
- ✅ `Command.system` exists (line 307) — consider adding to objective
- ⚠️ Consider adding `Command.exit` and `Command.cancel` to the reference

---

### `the_runtime.md`

**Objectives:**
1. Describe how Rooibos orchestrates your Model, Update, and View
2. Enable debug mode to trace message processing
3. Explain when renders happen (after every UPDATE)
4. Use the `Cmd` and `Msg` shorthand aliases
5. Compare the runtime to Rails Rack request cycle

**Audit:**
- ✅ `Runtime.run` orchestrates the loop (`lib/rooibos/runtime.rb`)
- ⚠️ Debug mode: `debug:` parameter exists but only controls Ractor shareability checks (line 313), not message tracing
- ✅ `Cmd` alias exists in `shortcuts.rb:29`
- ❌ **`Msg` alias does not exist** — `shortcuts.rb` only defines `Cmd`. Remove from objective or add to codebase
- ✅ Rails comparison is conceptual — appropriate

---

### `shortcuts.md`

**Objectives:**
1. Use `Cmd` and `Msg` module aliases for concise code
2. Understand the full vs. shorthand forms
3. Know when shorthand improves vs. hurts readability

**Audit:**
- ✅ `Cmd` exists (`lib/rooibos/shortcuts.rb:29`) with `exit`, `sh`, `map` methods
- ❌ **`Msg` does not exist** — remove from objective
- ⚠️ Very thin topic (only 3 methods) — consider merging into `the_runtime.md`

---

## Scaling Up

### `custom_commands.md`

**Objectives:**
1. Write a custom command using the `out` parameter
2. Implement cooperative cancellation with `token`
3. Define the correct call signature for your command
4. Decide when to write a custom command vs. using built-ins

**Audit:**
- ✅ `out` parameter shown in `command/custom.rb:36-47` example
- ✅ `token` parameter with `token.canceled?` loop pattern at line 41
- ✅ Call signature is `def call(out, token)` — documented in example
- ✅ `include Rooibos::Command::Custom` mixin documented
- ⚠️ Consider adding: "Override `rooibos_cancellation_grace_period` for cleanup time"

---

### `command_composition.md`

**Objectives:**
1. Chain dependent operations with `out.source`
2. Run parallel work with `out.standing`
3. Retrieve final results with `out.last`
4. Design multi-step async workflows

**Audit:**
- ✅ `out.source` exists (`command/outlet.rb:127`) — runs child synchronously, blocks until complete
- ✅ `out.standing` exists (`command/outlet.rb:161`) — spawns async streaming command
- ❌ **`out.last` does not exist** — the method is `out.wait` (line 214). Fix objective: "Block until async commands complete with `out.wait`"
- ✅ Multi-step workflows documented in source/standing/wait examples

---

### `fractal_architecture.md`

**Objectives:**
1. Compose child fragments using `Cmd.map`
2. Route parent messages to the correct child
3. Use the Router DSL to simplify complex routing
4. Decide when fractal architecture is worth the complexity

**Audit:**
- ✅ `Command.map` exists (`command.rb:399-423`) — wraps child command with message transformer
- ⚠️ Objective says `Cmd.map` but full form is `Command.map`. `Cmd.map` also exists in `shortcuts.rb:44`
- ✅ `Router` module exists with `route`, `keymap`, `mousemap`, `from_router` DSL (`router.rb`)
- ✅ Fractal architecture examples in `examples/app_fractal_dashboard/`

---

### `message_routing.md`

**Objectives:**
1. Define routes with `Rooibos.route`
2. Delegate messages to child fragments cleanly
3. Handle cross-cutting concerns (logging, analytics) centrally
4. Debug message routing with logging

**Audit:**
- ❌ **`Rooibos.route` does not exist** — the pattern is `include Rooibos::Router` then use `route :prefix, to: ChildModule`. Fix objective.
- ✅ Delegation via `route` DSL exists (`router.rb:72-74`)
- ⚠️ Cross-cutting concerns not explicitly shown in examples — worth adding to docs
- ⚠️ Debug logging for routing not specifically implemented — consider adding

---

### `ractor_safety.md`

**Objectives:**
1. Explain why Rooibos requires shareable state (future-proofing for Ruby 4)
2. Identify what makes an object shareable
3. Use the Callable pattern to capture data safely
4. Debug "not shareable" errors in tests and debug mode

**Audit:**
- ✅ `validate_ractor_shareable!` enforces shareability (`runtime.rb:315-321`)
- ✅ "Callable pattern" documented — lambdas/procs must be shareable (`command.rb:430-431`)
- ✅ Debug mode validates shareability (`command.rb:453-459`)
- ✅ `Ractor.make_shareable` used in examples (e.g., `disk_usage.rb:36`)

---

### `async_patterns.md`

**Objectives:**
1. Handle streaming data from SSE or websockets
2. Implement polling with `Command.wait` and timers
3. Coordinate multiple async sources without race conditions
4. Clean up connections when your app exits

**Audit:**
- ✅ `out.standing` for streaming commands (`outlet.rb:161`)
- ✅ `Command.system(stream: true)` for streaming output (`command.rb:188`)
- ✅ WebSocket example in `command/custom.rb:29-47`
- ✅ Polling pattern with `until token.canceled?` loop shown in examples
- ✅ Cleanup via `rooibos_cancellation_grace_period` (`custom.rb:99-101`)

---

### `testing.md`

**Objectives:**
1. Test UPDATE functions as pure functions (input → output)
2. Mock commands to test async workflows
3. Assert VIEW output using TestHelper
4. Structure test files for maintainability

**Audit:**
- ✅ `Rooibos::TestHelper` exists (`test_helper.rb:15`)
- ✅ `validate_rooibos_command!` validates command protocol (`test_helper.rb:33`)
- ✅ `assert_no_command_errors` assertion (`test_helper.rb:83`)
- ⚠️ No explicit command mocking helpers — tests use real commands with `inject_key`/`inject_sync`
- ⚠️ VIEW testing relies on `RatatuiRuby::TestHelper` — Rooibos adds command validation only

---

## Best Practices

### `modal_dialogs.md`

**Objectives:**
1. Implement a modal overlay that captures focus
2. Route the dialog result (confirm/cancel) back to the parent
3. Handle the "escape to close" pattern
4. Design reusable modal fragments

**Audit:**
- ✅ `CustomShellModal` example shows complete modal pattern (`fragments/custom_shell_modal.rb`)
- ✅ Focus capture via `MODAL_INACTIVE` guard (`update_router.rb:28`)
- ✅ Overlay composition with `tui.overlay` (`dashboard/base.rb:68`)
- ✅ Modal active check: `CustomShellModal.active?(model.shell_modal)`
- ✅ Routes command results before modal intercept (`update_manual.rb:26-28`)

---

### `forms_and_validation.md`

**Objectives:**
1. Collect multi-field user input in your Model
2. Validate input and store error messages
3. Display inline validation feedback
4. Submit form data via Commands

**Audit:**
- ✅ `CustomShellInput` shows text input pattern (`custom_shell_input.rb`)
- ✅ Model tracks input state: `Model = Data.define(:text, :cancelled, :submitted)`
- ✅ Character input, backspace, paste handling (lines 66-75)
- ⚠️ No multi-field form example — only single text input
- ⚠️ No validation error display example — need to add for completeness

---

### `lists_and_tables.md`

**Objectives:**
1. Implement keyboard-navigable scrolling lists
2. Track selection state in your Model
3. Support pagination for large datasets
4. Link to RatatuiRuby List and Table widgets

**Audit:**
- ⚠️ No list/table examples in Rooibos examples — pattern is conceptual
- ⚠️ List/Table widgets are RatatuiRuby responsibility; Rooibos handles state only
- ✅ Objectives are valid patterns — tracking `:selected_index` in Model, up/down keys
- ⚠️ Consider adding a simple list example to `examples/`

---

### `http_workflows.md`

**Objectives:**
1. Model loading/success/error states for HTTP requests
2. Implement retry logic with exponential backoff
3. Cache responses to avoid redundant fetches
4. Handle offline/error states gracefully

**Audit:**
- ✅ Loading states shown: `Model = Data.define(:output, :loading)` in fragment examples
- ✅ `loading: true` → dispatch command → `loading: false` pattern in 10+ places
- ✅ Error handling: `{ stderr: }` pattern, error message in model
- ⚠️ No retry/backoff example — worth adding
- ⚠️ No caching example — worth adding

---

### `streaming_data.md`

**Objectives:**
1. Handle SSE (Server-Sent Events) streams
2. Process websocket messages as they arrive
3. Update UI incrementally without blocking
4. Clean up streaming connections on app exit

**Audit:**
- ✅ Streaming output in `custom_shell_output.rb` — accumulates chunks in Model
- ✅ `chunks` array updated incrementally (lines 66-67, 70-71)
- ✅ `out.standing` for concurrent streams (`outlet.rb:161`)
- ✅ Cleanup via `token.canceled?` loop and grace period
- ⚠️ No SSE/websocket example — only shell output streaming

---

### `orchestration.md`

**Objectives:**
1. Coordinate parallel commands with `Command.all`
2. Sequence dependent operations (A then B then C)
3. Handle partial failures in multi-step workflows
4. Design robust async pipelines

**Audit:**
- ✅ `Command.all` exists (`command.rb:518-537`) — aggregates parallel results
- ✅ `Command.batch` exists (`command.rb:488-516`) — fire-and-forget parallel
- ✅ `out.source` for sequencing (`outlet.rb:127`) — blocks until child completes
- ⚠️ No partial failure handling example
- ⚠️ No multi-step pipeline example in `examples/`

---

## Troubleshooting

### `common_errors.md`

**Objectives:**
1. Recognize the most common Rooibos error messages
2. Identify the root cause for each error
3. Apply the fix and verify it works
4. Know where to ask for help if you are stuck

**Audit:**
- ✅ `Rooibos::Error` base class for exceptions (`error.rb:29`)
- ✅ `Rooibos::Error::Invariant` for contract violations (`error.rb:53`)
- ✅ `Command::Error` message type for failed commands (`command.rb:123-149`) — sent to UPDATE, not raised
- ✅ Common causes documented: conflicting params, return type mismatch
- ⚠️ Need to catalog all error messages from both Rooibos and RatatuiRuby

---

### `debugging.md`

**Objectives:**
1. Enable `debug: true` for verbose runtime output
2. Inspect Model state at any point in execution
3. Use file logging when stdout is unavailable
4. Trace message flow through your app

**Audit:**
- ⚠️ `debug: true` exists via `RatatuiRuby::Debug.enabled?` but only enables Ractor shareability checks and suspicious-command warnings — not verbose output
- ⚠️ No message tracing feature exists in codebase
- ⚠️ No file logging infrastructure — stdout is captured by TUI
- ⚠️ Consider: these features would be valuable additions

---

### `performance.md`

**Objectives:**
1. Identify slow VIEW functions with debug timing
2. Minimize unnecessary widget allocations
3. Avoid redundant renders with smart Model updates
4. Profile your app to find bottlenecks

**Audit:**
- ✅ `fps:` parameter controls render frequency (`runtime.rb:110, 119`)
- ⚠️ No debug timing for VIEW functions — would require instrumentation
- ⚠️ Widget allocation optimization is RatatuiRuby responsibility
- ⚠️ Model updates always trigger re-render — no smart diffing
- ⚠️ Objectives are conceptual best practices, not Rooibos features

---

## Tutorial

### `index.md`

**Objectives:**
1. Build a fully-functional file browser TUI from scratch
2. Apply all core Rooibos concepts (Model, Update, View, Commands)
3. Understand how to structure a real-world Rooibos application
4. Have a working app you can extend and customize

**Audit:**
- ✅ Objectives are high-level educational goals — appropriate for tutorial overview
- ✅ All concepts (Model, Update, View, Commands) exist in codebase
- ⚠️ No file browser example exists yet — this is the tutorial to be written

---

### `01_project_setup.md`

**Objectives:**
1. Create a new Rooibos project with the correct folder structure
2. Configure your Gemfile with required dependencies
3. Run a smoke test to verify your environment works
4. Understand what each file in the project does

**Audit:**
- ✅ Rooibos is a gem — Gemfile setup is standard Ruby pattern
- ✅ `examples/verify_readme_usage/` shows minimal project structure
- ✅ Objectives are pedagogical and grounded in Ruby/gem conventions

---

### `02_hello_world.md`

**Objectives:**
1. Write your first VIEW function that renders text
2. Run your app and see output in the terminal
3. Identify the entry point that starts your application
4. Explain what a VIEW function returns (RatatuiRuby widgets)

**Audit:**
- ✅ **Objective 1:** VIEW is a callable (lambda) `-> (model, tui)` — confirmed in `examples/verify_readme_usage/app.rb:21`
- ✅ **Objective 2:** Running the app is straightforward via `ruby app.rb` pattern
- ✅ **Objective 3:** Entry point is `Rooibos.run(ModuleName)` — confirmed in `app.rb:42`
- ✅ **Objective 4:** VIEW calls `tui.paragraph()` which returns RatatuiRuby widgets — confirmed
- ⚠️ **Clarification needed:** The VIEW is a lambda assigned to a constant, not a "function" — doc should clarify this Callable pattern

---

### `03_adding_state.md`

**Objectives:**
1. Define a Model using `Data.define` to hold your app state
2. Explain why state is stored in a struct, not instance variables
3. Pass the Model to your VIEW function
4. Display dynamic content based on state

**Audit:**
- ✅ **Objective 1:** `Model = Data.define(:...)` confirmed in 12+ examples across `examples/`
- ✅ **Objective 2:** Pedagogical objective — explained by Ractor shareability requirement (frozen Data values)
- ✅ **Objective 3:** VIEW receives `(model, tui)` — confirmed in all VIEW lambdas
- ✅ **Objective 4:** All examples access `model.field` to render dynamic content

---

### `04_handling_input.md`

**Objectives:**
1. Receive keyboard events as messages in your UPDATE function
2. Use pattern matching (`case msg`) to handle different keys
3. Return a new Model from UPDATE (never mutate!)
4. Navigate your file browser with arrow keys

**Audit:**
- ✅ **Objective 1:** Messages arrive in UPDATE as `msg` — keyboard predicates like `.q?`, `.ctrl_c?` confirmed in `verify_readme_usage/app.rb:34`
- ⚠️ **Objective 2:** Examples use `if msg.q?` rather than `case msg` — pattern matching is valid but examples show predicate style
- ✅ **Objective 3:** UPDATE returns `model` (unchanged) or `model.with(...)` — confirmed in all examples
- ⚠️ **Objective 4:** No file browser example exists yet — this objective describes the tutorial goal, not a current example

---

### `05_the_update_cycle.md`

**Objectives:**
1. Trace data flow through the complete MVU cycle
2. Explain why UPDATE must be a pure function (no side effects)
3. Use `model.with(...)` to create updated state immutably
4. Define what a **fragment** is: a self-contained Model + Update + View

**Audit:**
- ✅ **Objective 1:** MVU cycle is core architecture — Init → Model → View → Message → Update → Model
- ✅ **Objective 2:** UPDATE purity is enforced by Ractor model — side effects go through Commands
- ✅ **Objective 3:** `model.with(...)` confirmed in 50+ uses across `examples/`
- ✅ **Objective 4:** "Fragment" pattern confirmed in `app_fractal_dashboard/fragments/` — each has Model, Init, View, Update

---

### `06_organizing_your_code.md`

**Objectives:**
1. Extract a reusable fragment from your app
2. Define the Init callable that creates initial state
3. Compose multiple fragments into one application
4. Decide when to extract vs. keep code inline

**Audit:**
- ✅ **Objective 1:** Fragment extraction confirmed — 8+ fragments in `examples/app_fractal_dashboard/fragments/`
- ✅ **Objective 2:** `Init = ->` callable confirmed in 12 examples; creates and returns initial Model
- ✅ **Objective 3:** Composition confirmed in `dashboard/base.rb` — Init calls child fragment Inits
- ✅ **Objective 4:** Pedagogical decision — examples show extraction once fragments grow complex

---

### `07_your_first_command.md`

**Objectives:**
1. Explain why some operations cannot happen inside UPDATE (I/O, async)
2. Use `Command.wait` to read a file asynchronously
3. Handle the command result as a message
4. Return `[model, command]` tuples from UPDATE

**Audit:**
- ✅ **Objective 1:** Correct — I/O must be in Commands, UPDATE is pure
- ❌ **Objective 2:** **`Command.wait` is a timer, not file I/O** — should be `Command.system("cat file")` or a custom command
- ✅ **Objective 3:** Commands return results via messages — confirmed in `Message::Timer`, `Message::Shell`
- ✅ **Objective 4:** `[model, command]` tuple return confirmed across all examples

---

### `08_the_preview_pane.md`

**Objectives:**
1. Build a second fragment that displays file contents
2. Use RatatuiRuby layouts to arrange two views side-by-side
3. Coordinate state between the tree view and preview pane
4. Route messages from parent to child fragments

**Audit:**
- ⚠️ **Objective 1:** No file browser example yet — this is the tutorial goal
- ✅ **Objective 2:** `tui.layout` confirmed in 5 examples — splits areas with constraints
- ✅ **Objective 3:** State coordination confirmed — parent Model contains child Models
- ✅ **Objective 4:** `Rooibos.route(command, :child)` confirmed in 8 uses in `update_helpers.rb`

---

### `09_loading_states.md`

**Objectives:**
1. Model three states: loading, success, and error
2. Display a spinner or message while data loads
3. Handle errors gracefully with user feedback
4. Avoid rendering stale data during transitions

**Audit:**
- ✅ **Objective 1:** `:loading` field confirmed in 5 fragment Models; success/error implied by output state
- ⚠️ **Objective 2:** No spinner widget shown — examples show "Loading..." text; RatatuiRuby may have spinner from Throbber
- ✅ **Objective 3:** Error handling confirmed — `Message::Shell` has `status` for exit codes, error messages displayed
- ✅ **Objective 4:** `model.with(loading: true)` before command, `loading: false` on result — stale data avoided

---

### `10_testing_your_app.md`

**Objectives:**
1. Set up Rooibos::TestHelper in your test file
2. Write unit tests for UPDATE functions
3. Assert that VIEW renders expected content
4. Simulate keyboard input in tests

**Audit:**
- ✅ **Objective 1:** `include RatatuiRuby::TestHelper` confirmed in 22+ test files — Rooibos extends it
- ✅ **Objective 2:** UPDATE is a pure function — test by calling directly and asserting on returned model/command
- ✅ **Objective 3:** VIEW assertions rely on RatatuiRuby's `with_test_terminal` for snapshots
- ✅ **Objective 4:** Keyboard simulation via `inject_key` and `inject_keys` helpers for testing

---

### `11_polish_and_refine.md`

**Objectives:**
1. Handle edge cases (empty directories, permission errors)
2. Add keyboard shortcuts with a help overlay
3. Improve perceived performance with optimistic updates
4. Apply finishing touches that make your app feel professional

**Audit:**
- ⚠️ **Objective 1:** Edge case handling is application logic — no specific Rooibos helpers for this
- ⚠️ **Objective 2:** Help overlay is application-level UI — no built-in component for this
- ✅ **Objective 3:** Optimistic updates are standard MVU — update model immediately, then issue command
- ✅ **Objective 4:** "Professional feel" is pedagogical — polishing is best-practice guidance

---

### `12_going_further.md`

**Objectives:**
1. Know where to find the Essentials for deeper understanding
2. Identify which Scaling Up topics apply to your next project
3. Find Best Practices for common UI patterns
4. Decide what to build next

**Audit:**
- ✅ **Objective 1-3:** These are navigation/reference objectives — guide users to other docs
- ✅ **Objective 4:** Pedagogical — encourages continued learning
- ⚠️ All objectives are purely meta/navigational — no codebase verification needed

---

## Getting Started

### `why_rooibos.md`

**Objectives:**
1. Explain what a TUI (terminal user interface) is and why you would build one
2. Describe The Elm Architecture in one sentence
3. Compare Rooibos to alternatives (callbacks, threads, BubbleTea, Textual)
4. Articulate why functional state management prevents common bugs

**Audit:**
- ✅ **Objective 1:** Conceptual/pedagogical — TUI definition is domain knowledge
- ✅ **Objective 2:** TEA description is core to Rooibos — grounded in architecture
- ✅ **Objective 3:** Competitive comparison is marketing — BubbleTea/Textual are real alternatives
- ✅ **Objective 4:** Functional state management is the MVU value prop — well-grounded

---

### `install.md`

**Objectives:**
1. Install Ruby on macOS, Linux, or Windows (for non-Rubyists)
2. Create a new Ruby project with Bundler
3. Add Rooibos and RatatuiRuby as dependencies
4. Verify your setup runs a minimal app

**Audit:**
- ✅ **Objective 1:** Standard Ruby installation — external to Rooibos, but necessary onboarding
- ✅ **Objective 2:** Bundler is standard Ruby practice — `bundle init` pattern
- ✅ **Objective 3:** Gems are `rooibos` and `ratatui_ruby` — confirmed in gemspec
- ✅ **Objective 4:** `examples/verify_readme_usage/` provides minimal app verification

---

### `quickstart.md`

**Objectives:**
1. Run your first Rooibos application
2. Identify the three parts of an MVU app (Model, Update, View)
3. Make a change and see it reflected immediately
4. Know where to go next for deeper learning

**Audit:**
- ✅ **Objective 1:** `examples/verify_readme_usage/` is runnable first app
- ✅ **Objective 2:** Model, Update, View are core constants in all examples
- ✅ **Objective 3:** Edit-run cycle is standard Ruby — no special tooling required
- ✅ **Objective 4:** Navigation to Tutorial/Essentials is pedagogical guidance

---

### `for_react_developers.md`

**Objectives:**
1. Map React concepts to Rooibos equivalents (useState → Model, useReducer → Update)
2. Explain how Commands replace useEffect for side effects
3. Understand why Rooibos has no component lifecycle (and why that is simpler)
4. Translate "thinking in components" to "thinking in fragments"
5. Read Ruby syntax confidently after seeing the JS equivalent

**Audit:**
- ✅ **Objective 1:** Model replaces useState, Update replaces useReducer — accurate mapping
- ✅ **Objective 2:** Commands are the side effect mechanism — replaces useEffect pattern
- ✅ **Objective 3:** No lifecycle hooks — MVU is stateless render function
- ✅ **Objective 4:** Fragments are component-like — confirmed in `examples/app_fractal_dashboard/fragments/`
- ✅ **Objective 5:** Syntax comparison is pedagogical — helps JS devs onboard

---

### `for_go_developers.md`

**Objectives:**
1. Translate BubbleTea Model/Update/View to Rooibos equivalents
2. Identify Ruby syntax that differs from Go (blocks, symbols, no explicit types)
3. Understand how Rooibos handles Cmd differently than BubbleTea
4. Run the same counter example in both frameworks side-by-side

**Audit:**
- ✅ **Objective 1:** MVU architecture is shared with BubbleTea — direct mapping
- ✅ **Objective 2:** Syntax comparison is pedagogical — Ruby blocks vs Go explicit returns
- ⚠️ **Objective 3:** Rooibos Cmd pattern differs — uses `Command::Custom` protocol vs BubbleTea's `tea.Cmd` function
- ⚠️ **Objective 4:** No side-by-side counter example exists yet — would be valuable to create

---

### `for_python_developers.md`

**Objectives:**
1. Compare Rooibos to Textual approach (reactive vs. functional)
2. Map Python concepts to Ruby equivalents (decorators → blocks, dataclasses → Data.define)
3. Understand why immutable state simplifies async coordination
4. Identify key syntax differences (indentation vs. end, snake_case conventions)

**Audit:**
- ✅ **Objective 1:** Textual is reactive/OOP, Rooibos is functional MVU — valid comparison
- ✅ **Objective 2:** `Data.define` replaces dataclasses — accurate mapping
- ✅ **Objective 3:** Immutable state + Ractor safety is core value prop
- ✅ **Objective 4:** Syntax comparison is pedagogical — Python and Ruby are similar

---

### `ruby_primer.md`

**Objectives:**
1. Read and write basic Ruby syntax (variables, methods, classes)
2. Explain Ruby object model: everything is an object
3. Distinguish between symbols (`:key`) and strings (`"key"`)
4. Use blocks, procs, and lambdas for callbacks
5. Create immutable structs with `Data.define`
6. Handle nil safely (Ruby equivalent of null/None)
7. Call methods with keyword arguments

**Audit:**
- ✅ **Objective 1-4:** Core Ruby syntax — pedagogical, external to Rooibos
- ✅ **Objective 5:** `Data.define` is central to Rooibos models — well-grounded
- ✅ **Objective 6-7:** Nil safety and kwargs are Ruby fundamentals — helpful for onboarding
- ⚠️ All objectives are Ruby language education — no Rooibos-specific verification needed
