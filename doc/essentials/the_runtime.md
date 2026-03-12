<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# The Runtime

After reading this guide, you will know:

- What `Rooibos.run` does when you call it
- In what order the runtime calls Init, View, and Update
- How a command result finds its way back to Update
- How the Rooibos runtime compares to orchestrators in Rails, React, and BubbleTea

---

## Context

You have defined a [Model](./models.md), written an [Update](./update_functions.md), built a [View](./views.md), and learned how to return [Commands](./commands.md). These are the pieces of your application.

## Problem

None of these pieces do anything on their own. Model is data. Update, View, and Init are lambdas. Commands are instructions, not actions. Something has to call Init at startup, call View to render the screen, call Update when the user presses a key, and execute the commands that Update returns.

## Solution

The runtime ties everything together. Pass it your application module and Rooibos does the rest.

```ruby
Rooibos.run(MyApp)
```

### Starting Up

The runtime sets up the terminal, then calls Init. Init returns a model and optionally a command.

### The Loop

After Init, the runtime enters a loop. Each pass has three steps: render, check for events, and check for messages from commands.

The runtime calls View with the current model and renders the widget tree to the terminal. View runs on every pass, whether or not anything has changed.

The runtime checks for [terminal events](https://www.ratatui-ruby.dev/docs/trunk/RatatuiRuby/Event.html). If one has arrived, the runtime calls Update with the event and the current model. The runtime keeps the new model for the next View call and dispatches any returned command in the background.

The runtime also checks for messages from completed commands. If a timer has finished, an HTTP response has arrived, or any other command has produced a message, the runtime calls Update with it. Several messages can arrive between renders, and the runtime calls Update with each one separately. Each call receives the model returned by the previous call, so changes accumulate.

### Stopping

The loop runs until Update returns `Command.exit`. When it does, the runtime asks any background commands to stop, waits briefly for them to finish, restores the terminal, and returns.

---

## If You Know Other Frameworks

Every framework has an orchestrator. You write application code. The orchestrator decides when to call it.

In [Rails](https://rubyonrails.org), the orchestrator is [Rack](https://guides.rubyonrails.org/rails_on_rack.html). It receives an HTTP request and hands it to Rails. [The router](https://guides.rubyonrails.org/routing.html) finds a controller, Rails calls the action, and renders a response. State is rebuilt from the database on every request.

In [React](https://react.dev), the orchestrator is [the render-and-commit cycle](https://react.dev/learn/render-and-commit). React calls your component when props or state change, diffs the virtual DOM, and patches the real DOM. State lives in hooks or a store.

In [Vue](https://vuejs.org), the orchestrator is [the component lifecycle](https://vuejs.org/guide/essentials/lifecycle.html). Vue compiles templates into render functions, mounts them to the DOM, and patches the DOM when reactive state changes. State lives in reactive refs or the Options API.

---

## See Also

- [The Elm Architecture](./the_elm_architecture.md) for the theory behind this design
- [Commands](./commands.md) for the full list of built-in commands
- [Async Patterns](../scaling_up/async_patterns.md) for advanced topics like frame rate, animations, and the render loop internals

---

[**Previous:** Commands](./commands.md) | [**Next:** Shortcuts](./shortcuts.md)
