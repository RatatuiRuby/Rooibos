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
├── tutorial/                        # 13 files, ~100KB (Ember-style)
│   ├── index.md                     # Tutorial overview, what you'll build
│   ├── 01_project_setup.md          # Creating a new Rooibos app
│   ├── 02_hello_world.md            # Your first view function
│   ├── 03_adding_state.md           # Introducing Model
│   ├── 04_handling_input.md         # Messages and keyboard events
│   ├── 05_the_update_cycle.md       # Pure update functions
│   ├── 06_organizing_your_code.md   # Extracting reusable fragments
│   ├── 07_your_first_command.md     # Command.wait for async file reads
│   ├── 08_the_preview_pane.md       # Adding a second fragment
│   ├── 09_loading_states.md         # Progress indicators
│   ├── 10_testing_your_app.md       # TestHelper patterns
│   ├── 11_polish_and_refine.md      # Error handling, edge cases
│   └── 12_going_further.md          # Links to advanced topics
│
├── essentials/                      # 8 files, ~80KB (Vue-style concepts)
│   ├── the_elm_architecture.md      # MVU pattern + "Why MVU?"
│   ├── models.md                    # Data.define, state design, immutability
│   ├── messages.md                  # Types, predicates, pattern matching
│   ├── update_functions.md          # Pure functions, case expressions
│   ├── views.md                     # RatatuiRuby integration, fragments
│   ├── commands.md                  # Built-in commands reference
│   ├── the_runtime.md               # The loop, subscriptions, debug mode
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

**File count**: 46 files  
**Target size**: ~370KB (avg ~8KB per file)

---

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

### Tutorial (13 files, ~100KB)

A complete Ember-style tutorial building a **File Browser** using Ruby's `Pathname`/`File`.

| File | Est. KB | Description |
|------|---------|-------------|
| `index.md` | 3 | What you'll build, prerequisites |
| `01_project_setup.md` | 6 | Gemfile, folder structure |
| `02_hello_world.md` | 8 | First view function |
| `03_adding_state.md` | 8 | Introducing Model with Data.define |
| `04_handling_input.md` | 10 | Messages, keyboard events |
| `05_the_update_cycle.md` | 8 | Pure update functions, case expressions |
| `06_organizing_your_code.md` | 10 | Extracting reusable fragments |
| `07_your_first_command.md` | 8 | Command.wait for async file reads |
| `08_the_preview_pane.md` | 10 | Adding a second fragment |
| `09_loading_states.md` | 6 | Progress indicators |
| `10_testing_your_app.md` | 10 | TestHelper patterns |
| `11_polish_and_refine.md` | 8 | Error handling, edge cases |
| `12_going_further.md` | 5 | Links to scaling_up/ and best_practices/ |

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
| `the_runtime.md` | 10 | The loop, debug mode, subscriptions |
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
| **Total size** | ~370KB |
| **Files** | 46 |
| **Avg per file** | ~8KB |
| **Cross-refs per doc** | 3+ |
| **Audience coverage** | Rubyists, Front-end devs, Polyglots |

