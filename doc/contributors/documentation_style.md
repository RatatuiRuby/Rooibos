<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Documentation Style Guide

This guide defines how to write Rooibos user documentation. It applies to all markdown files in `doc/` (except `doc/contributors/`, which follows its own standards).

**All docs must be reviewed against this guide before merging.**

---

## Document Types

Rooibos has three distinct document types. Each follows different patterns:

| Type | Location | Pattern | Purpose |
|------|----------|---------|---------|
| **Tutorial** | `tutorial/` | Progressive build | Hands-on learning |
| **Concept** | `essentials/`, `scaling_up/`, `best_practices/` | Context-Problem-Solution | Understanding why |
| **Troubleshooting** | `troubleshooting/` | Error → Cause → Fix | Solving problems |

---

## Tutorial Chapters

Tutorials teach through action. Readers learn by doing, then understanding.

### Structure

1. **Chapter title** — What you'll accomplish
2. **Learning objectives** — What you'll know by the end (bulleted list)
3. **Prerequisites** — What you should have completed first
4. **Steps** — Numbered actions: "Type this → Run this → See this"
5. **Explanation** — Why it works (after the reader has seen it work)
6. **Summary** — What you learned

### Example

```markdown
# Adding State to Your App

By the end of this chapter, you will:
- Understand what a Model is
- Create your first `Data.define` struct
- See how state flows through the MVU loop

## Prerequisites

Complete [Your First View](02_hello_world.md) before starting.

## Step 1: Define Your Model

Create a new file called `model.rb`:

    Model = Data.define(:current_path, :entries)

Run your app:

    ruby app.rb

You should see...

## Why This Works

The `Model` holds all of your application state...
```

### Guidelines

- **Do first, explain after** — Show the code, let them run it, then explain
- **Small steps** — Each step should produce a visible result
- **No surprises** — If something can go wrong, warn them first
- **Screenshots** — Show what success looks like

---

## Concept Documents

Concept docs explain ideas. They answer "why" questions.

### Structure: Context-Problem-Solution (Alexandrian Form)

Every concept doc follows this pattern:

1. **Title** — The concept name
2. **Learning objectives** — "After reading this guide, you will know:" (Rails pattern)
3. **Context** — Set the scene. What situation is the reader in?
4. **Problem** — What difficulty or pain exists without this?
5. **Solution** — How Rooibos solves it
6. **Deep dive** — Detailed explanation with examples
7. **See also** — Cross-references to related docs

### Example

```markdown
# The Elm Architecture

After reading this guide, you will know:
- What Model-View-Update means
- Why unidirectional data flow prevents bugs
- How the runtime coordinates your app

---

## Context

Applications have state. A counter has a count. A file browser has a current directory. A chat app has messages.

State changes over time. Users click. Servers respond. Timers fire.

## Problem

Coordinating state changes is hard. Callbacks create spaghetti. Shared mutable state causes race conditions. Event emitters become untraceable.

## Solution

The Elm Architecture solves this with **unidirectional data flow**:

1. **Model** — A single source of truth for state
2. **Update** — A pure function that computes the next state
3. **View** — A function that renders the model

...
```

### Guidelines

- **Start with why** — Don't explain what a Command is; explain why Commands exist
- **Use diagrams** — ASCII or mermaid for data flow
- **Show bad then good** — Contrast the painful way with the elegant way
- **Link out to RatatuiRuby** — Don't re-document widgets; link to their guides

---

## Callouts

Use callouts to highlight important information. Standard types:

### Syntax

```markdown
> **Note**: Background context that's helpful but not critical.

> **Tip**: A shortcut, best practice, or efficiency suggestion.

> **Warning**: Something that could cause confusion or bugs if ignored.

> **Caution**: High-risk actions that could cause data loss or crashes.
```

### When to Use

| Callout | Use for |
|---------|---------|
| **Note** | "By the way..." — Additional context |
| **Tip** | "Pro tip..." — Efficiency improvements |
| **Warning** | "Watch out..." — Common mistakes |
| **Caution** | "Danger..." — Breaking changes, data loss |

---

## Cross-References

Every document should have **3+ cross-references** to related docs.

### Related Topic Links

```markdown
See [The Elm Architecture](../essentials/the_elm_architecture.md) for background.

For advanced patterns, see [Fractal Architecture](../scaling_up/fractal_architecture.md).

Related: [Commands](commands.md) | [Messages](messages.md) | [The Runtime](the_runtime.md)
```

### Next/Previous Navigation

Tutorial chapters and sequential docs should end with navigation links:

```markdown
---

← Previous: [Handling Input](04_handling_input.md) | Next: [Organizing Your Code](06_organizing_your_code.md) →
```

### Link to RatatuiRuby

Rooibos docs focus on architecture. Link to RatatuiRuby for rendering:

```markdown
For widget details, see the [RatatuiRuby List docs](https://ratatui-ruby.dev/docs).
```

---

## Prose Style

Based on Zinsser's *On Writing Well* and Plain Language Guidelines.

### Do

- **Use active voice** — "The runtime dispatches messages" not "Messages are dispatched"
- **Use short sentences** — One idea per sentence
- **Address the reader** — "You" not "the developer"
- **Use imperative mood** — "Create a model" not "You should create a model"

### Avoid

| Avoid | Use instead |
|-------|-------------|
| "allows you to" | (just state what happens) |
| "provides functionality for" | (state what it does) |
| "in order to" | "to" |
| "utilize" | "use" |
| "prior to" | "before" |
| "You must" / "You need to" | (imperative: "Do X") |

### Examples

**Bad:**
> The Command module provides functionality that allows the user to perform asynchronous operations.

**Good:**
> Commands run async work. Use them to fetch data, wait for timers, or perform I/O.

---

## Code Examples

### Format

Use fenced code blocks with language identifier:

    ```ruby
    Model = Data.define(:count)
    ```

### Guidelines

- **Complete and runnable** — Every example should work if copy-pasted
- **Show output** — Include comments showing what prints or renders
- **Progressive complexity** — Start simple, add complexity gradually
- **Highlight changes** — When building on previous code, comment new lines

---

## Learning Objectives (Rails Pattern)

Every concept doc starts with learning objectives:

```markdown
After reading this guide, you will know:

- How to define a Model using `Data.define`
- Why immutability matters in MVU
- When to use nested structs vs. flat state
```

This pattern comes from Rails Guides and sets reader expectations.

---

## Checklist

Before submitting documentation, verify:

- [ ] **Type identified** — Is this a tutorial, concept, or troubleshooting doc?
- [ ] **Pattern followed** — Does it follow the correct structure for its type?
- [ ] **Learning objectives** — Does it start with what the reader will learn?
- [ ] **Cross-references** — Are there 3+ links to related docs?
- [ ] **Code examples** — Are all examples complete and runnable?
- [ ] **Prose style** — Active voice? Short sentences? No "allows you to"?
- [ ] **RatatuiRuby links** — Did you link out for widget/layout details?
