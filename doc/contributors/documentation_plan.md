<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Rooibos Documentation Complete Overhaul Proposal

## Executive Summary

**Goal**: Defeat BubbleTea in the marketplace for TUI frameworks. Make Ruby the language people learn to build TUIs.

Rooibos has **excellent** contributor-facing design documentation but **incomplete** user-facing guides. This proposal restructures the `doc/` directory into a Rails Guides–style information architecture—comprehensive enough to onboard developers who have never written Ruby.

---

## Strategic Context

### The Competitive Landscape

| Framework | Language | Docs Scale | Target Audience |
|-----------|----------|------------|------------------|
| **BubbleTea** | Go | ~50KB + examples | Go developers |
| **Iced** | Rust | ~30KB + examples | Rust developers |
| **textual** | Python | ~200KB | Python developers |
| **Rooibos** | Ruby | **~370KB (target)** | **Everyone** |

Rooibos should be the Rails of TUI frameworks: the one that makes people *want* to learn Ruby.

### Target Audiences

Unlike Ember/Vue (JS-only), Rooibos targets **three distinct audiences**:

#### 1. Rubyists
- **Know**: Ruby syntax, OOP, Rails/Hanami patterns
- **Don't know**: Functional programming, long-lived stateful apps (Rails is request/response)
- **Need**: Conceptual bridge from stateless web to stateful TUI, MVU mental model

#### 2. Front-End Developers
- **Know**: JavaScript, React (passive MVU exposure via Redux), have used TUIs (lazygit, etc.)
- **Don't know**: Ruby, terminal programming, architecture
- **Need**: Ruby crash course, explicit connection to React/Redux patterns they already know

#### 3. Polyglots / Newcomers
- **Know**: Varies—could be Go, Rust, Python, or nothing
- **Don't know**: Potentially everything
- **Need**: Complete onboarding from zero, language-agnostic conceptual explanations

### Implications for Documentation

| Audience | Rails does this | Rooibos should do this |
|----------|-----------------|------------------------|
| Rubyists | Assumes Ruby knowledge | Same |
| Non-Rubyists | "Learn Ruby first" | **Teach Ruby inline** (like Rails' Getting Started) |
| Architecture-naive | Explains MVC from scratch | **Explain MVU from scratch** |
| Polyglots | Links to Ruby docs | **Provide comparison tables** ("If you know Go...") |

### Documentation Scope: Rooibos vs. RatatuiRuby

Rooibos and RatatuiRuby have **complementary responsibilities**. Avoid duplicating widget/rendering docs.

| Topic | Rooibos docs teach | RatatuiRuby docs (link to) |
|-------|-------------------|----------------------------|
| **Architecture** | MVU loop, functional runtime | — |
| **State management** | Model design, Data.define | — |
| **Messages** | Types, predicates, routing | *Event handling* (predicates) |
| **Commands** | Built-in + custom commands, async | — |
| **Views** | *What a view function is*, returning layouts | Widgets, styling, layout APIs |
| **Widgets** | — | Paragraph, Table, List, Block, etc. |
| **Layouts** | — | Rect, Constraint, Layout engine |
| **Testing** | TestHelper, update testing | Buffer assertions, view testing |
| **Debugging** | Runtime debug mode | Terminal debugging, buffer inspection |

**Strategy**: Rooibos `views.md` explains the *contract* (what a view function returns) and links out to RatatuiRuby for the actual widget catalog. The tutorial teaches *just enough* widgets to build the app, with "See RatatuiRuby docs for more" links.

---


## Current State Analysis

### RatatuiRuby Documentation (The Gold Standard)

| Section | Files | Total Size | Quality |
|---------|-------|------------|---------|
| **Getting Started** | 2 | ~18KB | Complete tutorials with screenshots |
| **Concepts** | 7 | ~49KB | Full C-P-S pattern, comprehensive examples |
| **Troubleshooting** | 3 | ~11KB | Dedicated problem-solving guides |
| **Index** | 1 | ~1.4KB | Clear navigation with section headers |

**Structure:**
```
doc/
├── index.md                 # Navigation hub
├── getting_started/
│   ├── why.md               # Philosophy and comparisons
│   └── quickstart.md        # 292 lines, 3 tutorials, examples gallery
├── concepts/
│   ├── application_architecture.md  # 322 lines, lifecycle patterns
│   ├── application_testing.md       # 194 lines, test helpers
│   ├── async.md                     # 191 lines, background work
│   ├── custom_widgets.md            # 248 lines, escape hatch
│   ├── debugging.md                 # 402 lines, remote debugging
│   ├── event_handling.md            # 163 lines, predicates + patterns
│   └── interactive_design.md        # 147 lines, cached layout
├── troubleshooting/
│   ├── async.md
│   ├── terminal_limitations.md
│   └── tui_output.md
└── contributors/
    └── ... (15 files)
```

### Rooibos Documentation (Current State)

| Section | Files | Total Size | Quality |
|---------|-------|------------|---------|
| **Getting Started** | 1 | ~2KB | Placeholder stubs |
| **Concepts** | 5 | ~27KB | Mixed: 2 good, 3 incomplete |
| **Troubleshooting** | 0 | 0 | Missing entirely |
| **Index** | 1 | ~0.8KB | Minimal navigation |

**Structure:**
```
doc/
├── index.md                 # Minimal, links 2 concept docs
├── getting_started/
│   └── quickstart.md        # 57 lines, ALL placeholders
├── concepts/
│   ├── application_architecture.md  # 198 lines, incomplete Core Concepts
│   ├── application_testing.md       # 50 lines, placeholder
│   ├── async_work.md                # 165 lines, solid C-P-S
│   ├── commands.md                  # 531 lines, EXCELLENT
│   └── message_processing.md        # 52 lines, minimal
└── contributors/
    ├── design/
    │   ├── commands_and_outlets.md  # 215 lines, rich pattern lineage
    │   └── mvu_tea_implementations_research.md  # 374 lines, thorough
    └── WIP/
        └── ...
```

### The Inversion Problem

Rooibos has **inverted documentation priority**:

- **User concepts**: 5 docs, 3 incomplete, ~27KB
- **Contributor design**: 2 docs, both thorough, ~20KB

Users hit `doc/concepts/` first. They don't discover the rich pattern documentation until they're already contributors.

---

## Proposed Information Architecture

### Research: Rails Guides, Vue.js Docs, and Ember Guides

I examined the actual source files for all three frameworks. Here's what I found:

---

#### Rails Guides (`~/Developer/rails/guides/source/`)

**Scale**: 80 markdown files, ~2.5MB total

**ToC Structure** (`documents.yaml`):
```
Start Here
  └── Getting Started with Rails (100KB, 3221 lines!)
  └── Install Ruby on Rails
Models (7 guides)
  └── Active Record Basics
  └── Migrations, Validations, Callbacks, Associations, Querying, Active Model
Views (4 guides)
Controllers (3 guides)
Other Components (7 guides)
Digging Deeper (11 guides)
Going to Production (4 guides)
Advanced Active Record (4 guides)
Extending Rails (5 guides)
Contributing (4 guides)
Policies
Release Notes (19 versions!)
```

**Key Patterns**:
1. **Massive "Getting Started"**: 3221 lines, covers everything from install to deployment
2. **Each guide has a header**: "After reading this guide, you will know:" (learning objectives)
3. **Progressive complexity**: Models → Views → Controllers → Other → Digging Deeper → Production
4. **Real-world project**: Builds "store" e-commerce app throughout

---

#### Vue.js Docs (`~/Developer/docs/src/guide/`)

**Scale**: 8 subdirectories, ~70 files

**Directory Structure**:
```
introduction.md (12KB)
quick-start.md (15KB)
essentials/ (13 files, ~144KB)
  └── reactivity-fundamentals.md (20KB)
  └── template-syntax.md, computed.md, class-and-style.md...
components/ (9 files, ~103KB)
  └── props.md (20KB), slots.md (24KB), v-model.md (19KB)...
reusability/ (4 files)
built-ins/ (18 files)
scaling-up/ (6 files)
typescript/ (3 files)
best-practices/ (4 files)
extras/ (15 files)
```

**Key Patterns**:
1. **API Preference Toggle**: Every page has Options API vs Composition API versions
2. **Deep outline**: Uses `outline: deep` frontmatter for rich ToC
3. **Interactive examples**: "Try it in the Playground" links throughout
4. **Progressive disclosure**: essentials → components → reusability → scaling-up → best-practices
5. **"Why" sections**: "Why Refs?" explains design decisions

---

#### Ember Guides (`~/Developer/guides-source/guides/release/`)

**Scale**: 23 sections, ~150 files, `pages.yml` defines structure

**ToC Structure** (`pages.yml`):
```yaml
Introduction
  └── Guides and Tutorials
Getting Started (7 pages)
  └── How To Use The Guides, Quick Start, Anatomy of an Ember App
Tutorial (2 parts, 15 pages)
  └── Part 1: Orientation → Building Pages → Testing → Components
  └── Part 2: Route Params → Service Injection → EmberData
--- Core Concepts ---
Components (11 pages)
Routing (11 pages)
Services (1 page)
EmberData (9 pages)
In-Depth Topics (6 pages)
--- Application Development ---
Application Concerns (5 pages, all marked "isAdvanced")
Accessibility (6 pages)
Configuration (10 pages)
Testing (10 pages)
TypeScript (16 pages)
--- Developer Tools ---
Build Tooling, Ember Inspector (12 pages), Code Editors
--- Additional Resources ---
Upgrading, Contributing, Glossary
```

**Key Patterns**:
1. **Section headings** in ToC: `is_heading: true` creates visual groupings
2. **isAdvanced flag**: Marks optional/advanced content
3. **Tutorial-driven**: Full 15-page tutorial building a complete app
4. **Component-centric structure**: Components section has 11 deep pages
5. **Mascot callouts**: "Zoey says..." and "Tomster says..." for tips

---

### Synthesis: Key Patterns from Deep Research

From reading **12 docs** across all three frameworks (Vue's quick-start, watchers, component-basics, props, render-function; Rails' testing, association_basics; Ember's reusable-components tutorial, native-classes-in-depth):

#### Content Patterns

| Pattern | Example | Apply to Rooibos |
|---------|---------|------------------|
| **Learning objectives header** | Rails: "After reading this guide, you will know:" | Top of every doc |
| **Dual API presentation** | Vue shows Options API + Composition API side-by-side | Show `Data.define` + Struct alternatives |
| **Massive reference tables** | Rails testing.md: 30+ assertion methods in a table | Commands reference table |
| **TIP/NOTE/WARNING callouts** | All three use these extensively | Use consistently |
| **Playground links** | Vue: "Try it in the Playground" after every example | Link to example apps |
| **Mascot callouts** | Ember: "Zoey says..." tips | Consider a Rooibos mascot |
| **Version badges** | Vue: `<sup class="vt-badge" data-text="3.5+">` | Mark new v1.0 features |

#### Structural Patterns

| Pattern | Example | Apply to Rooibos |
|---------|---------|------------------|
| **Tutorial builds real app** | Ember: 15-part tutorial building "Super Rentals" | Build a TODO or chat app |
| **Progressive disclosure** | Vue: essentials → components → extras | essentials → in_depth → patterns |
| **Exhaustive method lists** | Rails: every association method documented | Every Command method documented |
| **isAdvanced flags** | Ember: marks optional advanced content | Mark Ractor safety, parallel streaming |
| **Cross-references** | All: "See also [X]" links throughout | Required in every doc |

#### Scale Comparison (Corrected)

| Framework | User docs | Total size |
|-----------|-----------|------------|
| Rails | 75 files | ~2.5MB |
| Vue | 52 files | ~400KB |
| Ember | 125 files | ~500KB |
| RatatuiRuby | 12 files | ~80KB |
| **Rooibos (current)** | **6 files** | **~29KB** |
| **Rooibos (target)** | **40+ files** | **~370KB** |

> The target scale is ~13x larger than current, matching Ember-scale ambition.

### Fresh Start: Delete All Current Docs

> [!CAUTION]
> **Delete all existing user-facing documentation** (`doc/` except `doc/contributors/`).
> We are starting from scratch with a completely new information architecture.

### Proposed Structure (46 files, ~370KB total)

```
doc/
├── index.md                         # Navigation hub with audience paths (~5KB)
│
├── getting_started/                 # 8 files, ~55KB
│   ├── index.md                     # "Choose your path" (audience routing)
│   ├── why_rooibos.md               # Philosophy, BubbleTea comparison
│   ├── install.md                   # Ruby + gem installation (for non-Rubyists)
│   ├── quickstart.md                # 500+ lines, Hello World → HTTP app
│   ├── for_react_developers.md      # "If you know Redux..." bridge
│   ├── for_go_developers.md         # BubbleTea → Rooibos translation guide
│   ├── for_python_developers.md     # Textual → Rooibos translation guide
│   └── ruby_primer.md               # Ruby basics for polyglots
│
├── tutorial/                        # 31 files, ~240KB (TDD-first, one concept per step)
│   ├── index.md                     # Tutorial overview, what you'll build
│   ├── 01_project_setup.md          # Story -4: Creating project structure
│   ├── 02_hello_world.md            # Story -3: VIEW, UPDATE, quit
│   ├── 03_static_file_list.md       # Story -2: MODEL, INIT, testing intro ⭐
│   ├── 04_arrow_navigation.md       # Story -1: State updates, more tests
│   ├── 05_real_files.md             # Story 0: Tests break, learn mocking ⭐⭐⭐
│   ├── 06_safe_refactoring.md       # Story 4a: Extract fragment, tests protect ⭐
│   ├── 07_red_first_tdd.md          # Story 4b: Build second fragment via TDD ⭐
│   ├── 08_file_metadata.md          # Story 5: Pre-calculation pattern
│   ├── 09_text_preview.md           # Story 6: File reading, scrolling
│   ├── 10_directory_tree.md         # Story 7: Recursive data structures
│   ├── 11_pane_focus.md             # Story 8: Message routing
│   ├── 12_sorting.md                # Story 9: Pre-calculation (sort in UPDATE)
│   ├── 13_filtering.md              # Story 10: Manual text input (cursor state)
│   ├── 14_toggle_hidden.md          # Story 11: Conditional rendering
│   ├── 15_text_input_widget.md      # Story 12: Cancellation tokens ⭐
│   ├── 16_rename_files.md           # Story 13: Pre-populated input
│   ├── 17_confirmation_dialogs.md   # Story 14: Modal UI state
│   ├── 18_progress_indicators.md    # Story 15: Long-running with progress ⭐
│   ├── 19_atomic_operations.md      # Story 16: Fallback strategies
│   ├── 20_external_editor.md        # Story 17: Suspend/resume
│   ├── 21_modal_overlays.md         # Story 18: Help overlay pattern
│   ├── 22_error_handling.md         # Story 19: Auto-dismiss timers
│   ├── 23_terminal_capabilities.md  # Story 23: NO_COLOR, fallbacks ⭐
│   ├── 24_mouse_events.md           # Story 20: Optional input handling
│   ├── 25_resize_events.md          # Story 21: Responsive layouts
│   ├── 26_loading_states.md         # Story 22: Tri-state models
│   ├── 27_performance.md            # Story 24: Profiling, optimization
│   ├── 28_color_schemes.md          # Story 26: Theme system
│   ├── 29_configuration.md          # Story 27: Config files
│   └── 30_going_further.md          # Links to advanced topics
│
├── essentials/                      # 8 files, ~80KB (Vue-style concepts)
│   ├── the_elm_architecture.md      # MVU pattern + "Why MVU?"
│   ├── models.md                    # Data.define, state design, immutability
│   ├── messages.md                  # Types, predicates, pattern matching
│   ├── update_functions.md          # Pure functions, case expressions
│   ├── views.md                     # RatatuiRuby integration, fragments
│   ├── commands.md                  # Built-in commands reference
│   ├── the_runtime.md               # The loop, debug mode
│   └── shortcuts.md                 # Cmd, Msg module aliases
│
├── scaling_up/                      # 7 files, ~70KB (Vue-inspired)
│   ├── custom_commands.md           # out, token, call signature
│   ├── command_composition.md       # out.source, out.standing, out.last
│   ├── fractal_architecture.md      # Cmd.map, nested fragments
│   ├── message_routing.md           # Router DSL, Rooibos.route
│   ├── ractor_safety.md             # Shareability, freezing, Callable pattern
│   ├── async_patterns.md            # Streaming, polling, websockets
│   └── testing.md                   # Comprehensive testing guide
│
├── best_practices/                  # 6 files, ~50KB
│   ├── modal_dialogs.md             # Result routing patterns
│   ├── forms_and_validation.md      # Input handling, error display
│   ├── lists_and_tables.md          # Scrolling, selection, pagination
│   ├── http_workflows.md            # Loading states, retries, caching
│   ├── streaming_data.md            # SSE, websockets, log tailing
│   └── orchestration.md             # Command.all, sequential flows
│
├── troubleshooting/                 # 3 files, ~15KB
│   ├── common_errors.md             # Table of errors → fixes
│   ├── debugging.md                 # Logging, inspection, debug: true
│   └── performance.md               # Render optimization
│
└── contributors/                    # KEEP existing excellent docs
    └── ...
```

**File count**: 64 files  
**Target size**: ~510KB (avg ~8KB per file)

---

## Pedagogical Innovation: TDD-First Tutorial

### The Step 3 → Step 5 Teaching Arc

Our tutorial introduces a **controlled failure** that teaches professional testing practices:

**Step 3: Static File List + Testing Introduction**
- Introduce `Rooibos::TestHelper`
- Write first snapshot tests with hardcoded data
- Tests PASS ✅ - students feel successful
- **Teaches:** Testing is easy, tests build confidence

**Step 4: Arrow Navigation + More Tests**
- Test state transitions in UPDATE
- Tests PASS ✅ - confidence grows
- **Teaches:** Testing UPDATE functions, building test habits

**Step 5: Real Files - Tests Break! 💥**
- Student changes INIT to use `Dir.children(".")`
- Runs tests → ❌ SNAPSHOT MISMATCH
- **The Teaching Moment:** "Your tests broke! Why? The filesystem is non-deterministic."
- Introduce mocking with `Dir.stub`
- Tests PASS ✅ - relief and understanding
- **Teaches:** Why mocking matters (determinism, speed, isolation)

**Step 6: Safe Refactoring with Tests**
- Extract first fragment (file list) from monolithic app
- Run snapshot tests → still pass ✅
- **Teaches:** Tests enable fearless refactoring, fragments are just modules

**Step 7: Red-First TDD**
- Build second fragment (directory tree) via **red-first TDD**:
  - Write failing test for TreeFragment.view ❌ (red)
  - Implement TreeFragment.view ✅ (green)
  - Write failing test for TreeFragment.update ❌ (red)
  - Implement TreeFragment.update ✅ (green)
  - Refactor both fragments, tests keep passing ✅
- **Teaches:** Red-Green-Refactor cycle, unit testing fragments, TDD workflow

### Why This Beats the Competition

| Framework | Testing in Tutorial? | When? | Approach |
|-----------|---------------------|-------|----------|
| **BubbleTea** | ❌ No | N/A | No testing guidance |
| **Iced** | ❌ No | N/A | No testing guidance |
| **textual** | ✅ Yes | After features | Testing as afterthought |
| **Rails** | ✅ Yes | Chapter 10/12 | Testing comes late |
| **Ember** | ✅ Yes | Throughout | Integrated testing |
| **Rooibos** | ✅ Yes | **Step 3/25** | **TDD from the start** ⭐ |

**Our advantages:**
1. **Earlier than Rails** - Testing at Step 3, not Step 10
2. **Integrated like Ember** - Every step includes tests
3. **Better than BubbleTea/Iced** - They have no testing guidance at all
4. **Experiential learning** - Students experience the pain (broken tests) then learn the solution (mocking)
5. **Professional practices** - Mocking, snapshot testing, TDD mindset from the beginning

### Alignment with Documentation Style Guide

From `documentation_style.md`:

> **Do first, explain after** — Show the code, let them run it, then explain

Our Step 5 approach:
1. **Do:** Change INIT to use real files
2. **See:** Tests fail ❌
3. **Experience:** "What happened? Why did they break?"
4. **Do:** Add Dir.stub mocking
5. **See:** Tests pass ✅
6. **Understand:** "Why mocking matters for deterministic tests"

This is **experiential learning** - the student discovers WHY through controlled failure, not lecture.


## Detailed Content Plan

> All content is **new**. We're starting fresh — no annotations like [NEW]/[REWRITE].

### Getting Started (8 files, ~55KB)

| File | Est. KB | Description |
|------|---------|-------------|
| `index.md` | 3 | "Choose your path" audience routing |
| `why_rooibos.md` | 8 | TEA philosophy, BubbleTea comparison table |
| `install.md` | 5 | Ruby install for non-Rubyists, gem setup |
| `quickstart.md` | 15 | 500+ lines: Hello World → HTTP app |
| `for_react_developers.md` | 8 | Redux → MVU mental model bridge |
| `for_go_developers.md` | 6 | BubbleTea → Rooibos translation |
| `for_python_developers.md` | 6 | Textual → Rooibos translation |
| `ruby_primer.md` | 5 | Ruby basics for polyglots |

### Tutorial (31 files, ~240KB)

A comprehensive TDD-first tutorial building a **File Browser** using Ruby's `Pathname`/`File`.

**Key Innovation:** Testing introduced at Step 3, with controlled failure at Step 5 teaching why mocking matters.

| File | Est. KB | Stories | Description |
|------|---------|---------|-------------|
| `index.md` | 3 | — | What you'll build, prerequisites |
| `01_project_setup.md` | 6 | -4 | Gemfile, folder structure |
| `02_hello_world.md` | 8 | -3 | VIEW, UPDATE, Messages, Command.exit |
| `03_static_file_list.md` | 10 | -2 | MODEL, INIT, **testing intro** ⭐ |
| `04_arrow_navigation.md` | 8 | -1 | State updates (.with), more tests |
| `05_real_files.md` | 12 | 0 | **Tests break, learn mocking** ⭐⭐⭐ |
| `06_safe_refactoring.md` | 8 | 4a | **Extract fragment, tests protect** ⭐ |
| `07_red_first_tdd.md` | 10 | 4b | **Build via red-first TDD** ⭐ |
| `08_file_metadata.md` | 8 | 5 | Pre-calculation pattern (sort in UPDATE) |
| `09_text_preview.md` | 8 | 6 | File reading, text detection, scrolling |
| `10_directory_tree.md` | 10 | 7 | Recursive data structures in Model |
| `11_pane_focus.md` | 8 | 8 | Message routing, context-sensitive keys |
| `12_sorting.md` | 8 | 9 | **Pre-calculation (no VIEW computation!)** |
| `13_filtering.md` | 8 | 10 | **Manual text input (cursor state)** |
| `14_toggle_hidden.md` | 6 | 11 | Conditional rendering, visual styling |
| `15_text_input_widget.md` | 10 | 12 | **Cancellation tokens, Command.cancel** ⭐ |
| `16_rename_files.md` | 8 | 13 | Pre-populated input, validation |
| `17_confirmation_dialogs.md` | 8 | 14 | Modal UI state, Y/N handling |
| `18_progress_indicators.md` | 8 | 15 | **Long-running with progress** ⭐ |
| `19_atomic_operations.md` | 8 | 16 | **Fallback strategies, error recovery** |
| `20_external_editor.md` | 8 | 17 | Suspend/resume, process spawning |
| `21_modal_overlays.md` | 8 | 18 | Help overlay pattern |
| `22_error_handling.md` | 8 | 19 | Auto-dismiss timers (Command.wait) |
| `23_terminal_capabilities.md` | 10 | 23 | **NO_COLOR, ANSI/ASCII fallbacks** ⭐ |
| `24_mouse_events.md` | 8 | 20 | **Optional input, capability detection** |
| `25_resize_events.md` | 8 | 21 | **Responsive layouts, degradation** |
| `26_loading_states.md` | 8 | 22 | Tri-state models, cancellable Commands |
| `27_performance.md` | 8 | 24 | Profiling, optimization, caching |
| `28_color_schemes.md` | 8 | 26 | **Theme system, validation** |
| `29_configuration.md` | 8 | 27 | **YAML parsing, config files** |
| `30_going_further.md` | 5 | — | Links to scaling_up/ and best_practices/ |

**Tutorial Philosophy:**

1. **TDD from Step 3** - Tests are not optional, they're fundamental
2. **Controlled failure at Step 5** - Tests break when adding real files, teaching why mocking matters
3. **Every step includes tests** - Build confidence through green → green → red → green
4. **One pedagogical moment per step** - Each step teaches ONE concept clearly
5. **30 steps total** - Comprehensive coverage of all file browser stories

### Essentials (8 files, ~80KB)

Vue-style conceptual docs. Each follows **Context-Problem-Solution**.

| File | Est. KB | Description |
|------|---------|-------------|
| `the_elm_architecture.md` | 12 | MVU pattern + "Why MVU?" |
| `models.md` | 10 | Data.define, immutability, state design |
| `messages.md` | 10 | Types, predicates, pattern matching |
| `update_functions.md` | 8 | Pure functions, case expressions, Command returns |
| `views.md` | 8 | View function contract, links to RatatuiRuby widgets |
| `commands.md` | 15 | Built-in commands reference (wait, http, batch, all) |
| `the_runtime.md` | 10 | The loop, debug mode |
| `shortcuts.md` | 5 | Cmd, Msg module aliases |

### Scaling Up (7 files, ~70KB)

Advanced architecture topics.

| File | Est. KB | Description |
|------|---------|-------------|
| `custom_commands.md` | 12 | out, token, call signature |
| `command_composition.md` | 12 | out.source, out.standing, out.last |
| `fractal_architecture.md` | 12 | Cmd.map, nested fragments, Router DSL |
| `message_routing.md` | 10 | Rooibos.route, delegate patterns |
| `ractor_safety.md` | 8 | Shareability, freezing, Callable pattern |
| `async_patterns.md` | 10 | Streaming, polling, websockets |
| `testing.md` | 10 | Comprehensive TestHelper guide |

### Best Practices (6 files, ~50KB)

Pattern cookbook for common scenarios.

| File | Est. KB | Description |
|------|---------|-------------|
| `modal_dialogs.md` | 8 | Result routing, dialog patterns |
| `forms_and_validation.md` | 10 | Input handling, error display |
| `lists_and_tables.md` | 8 | Scrolling, selection, pagination |
| `http_workflows.md` | 10 | Loading states, retries, caching |
| `streaming_data.md` | 8 | SSE, websockets, log tailing |
| `orchestration.md` | 8 | Command.all, sequential flows |

### Troubleshooting (3 files, ~15KB)

| File | Est. KB | Description |
|------|---------|-------------|
| `common_errors.md` | 6 | Table: error message → cause → fix |
| `debugging.md` | 5 | Logging, inspection, debug: true |
| `performance.md` | 4 | Render optimization |

---

## Style Guide

**Concept docs** (Essentials, Scaling Up, Best Practices) follow the [Alexandrian form](file:///Users/kerrick/Developer/ratatui_ruby/doc/contributors/documentation_style.md):
- **Context-Problem-Solution** structure
- Active voice, short sentences
- Comprehensive examples with headers
- Cross-references to related docs (3+ per file)
- Links to RatatuiRuby for widget/layout details

**Tutorial chapters** follow a **progressive build** pedagogy:
- Do this → see that → now understand why
- Hands-on first, explanation after
- Each chapter builds on the previous

---

## Metrics for Success

| Metric | Target |
|--------|--------|
| **Total size** | ~510KB |
| **Files** | 64 |
| **Avg per file** | ~8KB |
| **Tutorial steps** | 30 (TDD from Step 3) |
| **Cross-refs per doc** | 3+ |
| **Audience coverage** | Rubyists, Front-end devs, Polyglots |
| **Testing introduced** | Step 3 (earlier than all competitors) |
| **Pedagogical moments** | One per step (clear, focused learning) |

