<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Static File List


By the end of this guide, you will:

- Define a Model using `Data.define` to hold your application state
- Understand why state is immutable (Data objects, not instance variables)
- Write an INIT callable that returns your initial model
- Display a static list of example files in your VIEW
- Write your first test using `Rooibos::TestHelper`
- Use `assert_snapshots` to verify your VIEW renders correctly
- Understand why tests with static data are fast and reliable

> ⚠️ **This page is a stub.** Help us write it! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).

## User Stories

## Story -2: Static File List

**As a** terminal user  
**I want to** see a list of example files displayed  
**So that** I can understand the basic file browser interface

### Acceptance Criteria
- Application displays a list of example filenames
- One file is visually highlighted
- Application can be quit with 'q'

### Notes
- Uses hardcoded example data ("README.md", "Gemfile", "lib/", "test/")
- No navigation yet - always highlights first item

---



---

[**Previous:** Hello World](./02_hello_world.md) | [**Next:** Arrow Navigation](./04_arrow_navigation.md)
