<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Adding State


By the end of this guide, you will:

- Define a Model using `Data.define` to hold your app state
- Explain why state is stored in a struct, not instance variables
- Pass the Model to your VIEW function
- Display dynamic content based on state
- Use `model.with(...)` to create updated state immutably
- Use predicate helpers (`.up?`, `.down?`, `.j?`, `.k?`) for key checks
- Use pattern matching (`case message`) for complex message handling
- Return a new Model from UPDATE with state changes
- Navigate your file browser with arrow keys and vim keys
- Understand when to use predicates vs pattern matching

> ⚠️ **This page is a stub.** Help us write it! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).

---

[**Previous:** Hello World](./02_hello_world.md) | [**Next:** Organizing Your Code](./06_organizing_your_code.md)
