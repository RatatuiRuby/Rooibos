<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# MVU/TEA Decomposition Strategies Analysis

## Decomposition Style Categories

### FRACTAL Style (Recursive MVU Triads)
Each component/module is a complete MVU unit with its own Model, Update, and View. Components nest recursively, parent delegates to children. Child components are self-contained and can be composed.

### SLICE Style (Domain-Segregated State)
State is partitioned by domain/feature, but update/view logic may be centralized or cross-cutting. Each slice typically has Model + Update, with views potentially pulling from multiple slices.

### HYBRID
Combines both patterns - some aspects use fractal composition, others use slice partitioning.

### NO DECOMPOSITION
Framework does not provide explicit support for breaking down complex applications.

---

## Framework Categorization

### 🟢 FRACTAL Decomposition

#### **1. Elm (Original TEA)**
- **Style**: Fractal (historically, with evolution)
- **Terminology**: "Nested TEA", "Modules", "Translator Pattern" / "OutMsg Pattern"
- **Details**:
  - Originally promoted recursive MVU triads (child modules with own Model/Msg/update/view)
  - Parent uses `Html.map` and `Cmd.map` to transform child messages
  - **Evolution**: Elm 0.19 de-emphasized deep nesting due to boilerplate
  - Current recommendation: Shallow nesting, reusable view functions over deep component trees
  - "Translator Pattern" for child-to-parent communication (child returns OutMsg for parent)
- **Composition**: Yes, via `Html.map` / `Cmd.map` and OutMsg pattern

#### **2. Bubble Tea (Go)**
- **Style**: Fractal
- **Terminology**: "Tree of Models", "Nested Models", "Child Components"
- **Details**:
  - Each component has its own `Model` struct with `Init()`, `Update()`, `View()` methods
  - Parent embeds child models as fields
  - Parent routes messages to children based on state (often using session/state enum)
  - View composition combines child view strings
  - Uses "Bubbles" library for pre-built components
- **Composition**: Yes, explicit message routing in parent's Update

#### **3. Iced (Rust)**
- **Style**: Fractal
- **Terminology**: "Nested components", "Message routing", "`.map()` transformation"
- **Details**:
  - Each component can have State + Message enum + update + view
  - Parent's Message enum wraps child Message types
  - Uses `.map()` to transform child messages/commands/elements to parent context
  - `Subscription::batch()` for combining child subscriptions
  - Note: `Component` trait deprecated in 0.13+ (violated single source of truth)
- **Composition**: Yes, via `.map()` transformation

#### **4. Elmish (F#/Fable)**
- **Style**: Fractal
- **Terminology**: "Nested TEA", "Child modules"
- **Details**:
  - Direct port of Elm Architecture to F#
  - Each module has `Model * Cmd<Msg>` init, `update`, `view`
  - Parent maps child messages and commands
  - Used with React for rendering
- **Composition**: Yes, same as Elm

#### **5. Hyperapp (JavaScript)**
- **Style**: Fractal-lite
- **Terminology**: No specific term (minimal framework)
- **Details**:
  - Unified global state, but can be structured recursively
  - Effects can be nested in init array `[state, effect1, effect2]`
  - Very lightweight (1KB), minimal opinions
- **Composition**: Limited, more state-tree focused than component-focused

---

### 🔵 SLICE Decomposition

#### **6. Redux (JavaScript/React)**
- **Style**: PURE SLICE
- **Terminology**: "Slices", "Reducers", "State combination"
- **Details**:
  - `createSlice` creates domain-specific state + reducers
  - Each slice has `name`, `initialState`, `reducers`
  - Slices combined via `configureStore({ reducer: { user: userSlice, posts: postsSlice } })`
  - Views (React components) can access any slice via selectors
  - **NOT strictly MVU** (no built-in effects), but pattern is similar
- **Composition**: Yes, via `combineReducers` / `configureStore`
- **Notable**: Slices have reducers, but no dedicated views - views are separate React components

---

### 🟡 HYBRID Decomposition

#### **7. TCA (Swift - The Composable Architecture)**
- **Style**: HYBRID (Fractal-ish with powerful scoping)
- **Terminology**: "Reducers", "Scoping", "Pullback", "Child features", "Composition"
- **Details**:
  - Each "feature" is a `Reducer` with nested `State` and `Action` types
  - Uses `.scope()` to focus parent state/actions on child domain
  - Can compose reducers horizontally (siblings) or vertically (parent-child)
  - **More sophisticated than pure fractal**: dependency injection, effects management, testing tools
  - Parent doesn't just delegate - uses lenses/scoping to project state
- **Composition**: Yes, via `Reducer` composition operators and scoping

#### **8. Flutter Bloc**
- **Style**: HYBRID
- **Terminology**: "BloC per feature/screen", "Nested BloCs", "BlocProvider", "MultiBlocProvider"
- **Details**:
  - Recommended pattern: one Bloc/Cubit per screen or feature
  - BloCs can be nested via `BlocProvider` (dependency injection)
  - `MultiBlocProvider` for multiple BloCs in widget tree
  - **Not pure fractal**: BloCs don't nest MVU triads, they're separate event-driven state machines
  - **Not pure slice**: Each BloC is feature-specific, views are Flutter widgets
- **Composition**: Yes, via provider pattern (DI), not via direct delegation

#### **9. Android MVI (Kotlin)**
- **Style**: HYBRID
- **Terminology**: "ViewModel per feature", "StateFlow", "Intent channels"
- **Details**:
  - Each ViewModel manages feature state via `StateFlow`
  - Intents sent to ViewModel via `SharedFlow` or `Channel`
  - ViewModels can be scoped to fragments/activities
  - **Not pure fractal**: ViewModels are independent state machines, not nested MVU
  - **Not pure slice**: Each ViewModel is feature-bound
- **Composition**: Limited, mostly via ViewModel scoping and shared state

#### **10. Meiosis (JavaScript)**
- **Style**: HYBRID
- **Terminology**: "Services", "Nested components" (optional), "Initial model composition"
- **Details**:
  - Flexible pattern, not opinionated
  - Can compose via `initialModel` merging
  - "meiosis-setup" library helps with nested components and services
  - View-library agnostic
- **Composition**: Yes, but flexible/manual

---

### ⚫ NO EXPLICIT DECOMPOSITION

#### **11. SAM Pattern (JavaScript)**
- **Style**: No explicit decomposition support
- **Terminology**: N/A
- **Details**:
  - Single Model (state tree)
  - Single State Representation function
  - Actions propose mutations
  - Based on TLA+ formalism
  - **Philosophical**: Focused on temporal logic and correctness, less on composition
- **Composition**: Not a focus

---

### 🟣 OTHER / MINIMAL DOCUMENTATION

#### **12-16. .NET Implementations**
- **Fabulous (F#/MAUI)**: Likely **FRACTAL** (F# MVU port, similar to Elmish)
- **BlazorMVU (C#/Blazor)**: Likely **FRACTAL** (Elm-inspired)
- **MauiReactor (C#/MAUI)**: Likely **FRACTAL** (MVU for .NET MAUI)
- **MVUX (.NET/Uno)**: **HYBRID** (Model-View-Update eXtended, data binding focus)
- **ngx-mvu (Angular)**: Likely **HYBRID** (Angular + MVU concepts)

---

## Summary Table

| Framework | Style | Terminology |
|-----------|-------|-------------|
| **Elm** | Fractal (evolved) | Nested TEA, Modules, Translator/OutMsg Pattern |
| **Bubble Tea** | Fractal | Tree of Models, Nested Models, Child Components |
| **Iced** | Fractal | Nested components, Message routing, `.map()` |
| **Elmish** | Fractal | Nested TEA, Child modules |
| **Hyperapp** | Fractal-lite | (minimal framework, no specific term) |
| **Redux** | **SLICE** | **Slices**, Reducers, State combination |
| **TCA** | **HYBRID** | Reducers, Scoping, Pullback, Child features |
| **Flutter Bloc** | **HYBRID** | BloC per feature, Nested BloCs, Providers |
| **Android MVI** | **HYBRID** | ViewModel per feature, StateFlow, Intents |
| **Meiosis** | **HYBRID** | Services, Nested components (optional) |
| **SAM** | None | N/A (TLA+ formalism focus) |
| Fabulous | Fractal (likely) | (F# MVU) |
| BlazorMVU | Fractal (likely) | (Elm-inspired) |
| MauiReactor | Fractal (likely) | (MVU for MAUI) |
| MVUX | Hybrid (likely) | (Extended MVU, data binding) |
| ngx-mvu | Hybrid (likely) | (Angular + MVU) |

---

## Key Insights

### Fractal Pattern Characteristics:
1. ✅ **Complete MVU triads** for each component
2. ✅ **Recursive composition** (components contain components)
3. ✅ **Message delegation** (parent forwards to child)
4. ✅ **View composition** (parent combines child views)
5. ❌ **High boilerplate** (Elm community moved away from deep nesting)

**Examples**: Elm (original), Bubble Tea, Iced, Elmish

### Slice Pattern Characteristics:
1. ✅ **Domain-partitioned state** (slices by feature)
2. ✅ **Flat composition** (slices are siblings, not nested)
3. ✅ **Centralized view** (views pull from multiple slices)
4. ✅ **Low boilerplate** (slices are simple)
5. ❌ **No per-slice views** (views are separate layer)

**Example**: Redux (pure slice pattern)

### Hybrid Pattern Characteristics:
1. ✅ **Feature-scoped state** (like slices)
2. ✅ **Independent update logic** (like fractal)
3. ✅ **Flexible composition** (dependency injection, scoping)
4. ✅ **Reduced boilerplate** (compared to pure fractal)
5. ⚠️ **Framework-specific** (each does it differently)

**Examples**: TCA (scoping/pullback), Flutter Bloc (providers), Android MVI (ViewModels)

---

## Where Does RatatuiRuby-TEA Fit?

### Current State: **FRACTAL**
- Fragments have `Model`, `INITIAL`, `UPDATE`, `VIEW`
- Parents delegate to children via `Tea.delegate`
- Message routing via `Tea.route`
- Router DSL for declarative composition

### With Init Callable: **ENHANCED FRACTAL**
Your `Init` proposal strengthens the fractal pattern by:
1. ✅ Enabling **parameterized initialization** (like Iced's `flags`)
2. ✅ Supporting **initial commands** (like Elm's `(Model, Cmd)`)
3. ✅ Allowing **parent-to-child props** (React-style, but fractal)
4. ✅ Maintaining **complete MVU triads** (Model, Init, Update, View)

This is **closer to Iced** (Rust) than Elm, as Iced explicitly supports flags for initialization and has evolved beyond Elm's original design.

---

## Recommendation

RatatuiRuby-TEA should **embrace the modern fractal pattern** with:
- **Complete MVU triads per fragment**: `Model`, `Init`, `Update`, `View`
- **Parameterized initialization**: `Init` accepts flags/props
- **Explicit composition**: Parent calls child `Init`, routes messages, composes views

This positions RatatuiRuby-TEA as:
- **Functional** (like Elm/Elmish/Iced)
- **Composable** (fractal pattern)
- **Modern** (Init callable, not static constants)
- **Parameterizable** (flags/props support)

**NOT** like Redux (slice pattern) or TCA/Bloc (OOP/hybrid patterns).
