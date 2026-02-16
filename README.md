<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->
# rooibos

[![
CI](https://github.com/setdef/Rooibos/actions/workflows/ci.yml/badge.svg)](https://github.com/setdef/Rooibos/actions/workflows/ci.yml) [![
License](https://img.shields.io/badge/License-LGPL-3.0-or-later-a2c93e)](https://spdx.org/licenses/LGPL-3.0-or-later.html) [![
Gem Total Downloads](https://img.shields.io/gem/dt/rooibos)](https://rubygems.org/gems/rooibos) [![
Gem Version](https://img.shields.io/gem/v/rooibos)](https://rubygems.org/gems/rooibos) [![
Discussion](https://img.shields.io/badge/forum-discussion-5865F2.svg?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiNmZmZmZmYiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIiBjbGFzcz0iaWNvbiBpY29uLXRhYmxlciBpY29ucy10YWJsZXItb3V0bGluZSBpY29uLXRhYmxlci1tYWlsIj48cGF0aCBzdHJva2U9Im5vbmUiIGQ9Ik0wIDBoMjR2MjRIMHoiIGZpbGw9Im5vbmUiLz48cGF0aCBkPSJNMyA3YTIgMiAwIDAgMSAyIC0yaDE0YTIgMiAwIDAgMSAyIDJ2MTBhMiAyIDAgMCAxIC0yIDJoLTE0YTIgMiAwIDAgMSAtMiAtMnYtMTB6IiAvPjxwYXRoIGQ9Ik0zIDdsOSA2bDkgLTYiIC8+PC9zdmc+Cg==)](https://forum.setdef.com/tags/c/rooibos/discussion) [![
Bug Reports](https://img.shields.io/badge/forum-bug_reports-4954d5.svg?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiNmZmZmZmYiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIiBjbGFzcz0iaWNvbiBpY29uLXRhYmxlciBpY29ucy10YWJsZXItb3V0bGluZSBpY29uLXRhYmxlci1tYWlsIj48cGF0aCBzdHJva2U9Im5vbmUiIGQ9Ik0wIDBoMjR2MjRIMHoiIGZpbGw9Im5vbmUiLz48cGF0aCBkPSJNMyA3YTIgMiAwIDAgMSAyIC0yaDE0YTIgMiAwIDAgMSAyIDJ2MTBhMiAyIDAgMCAxIC0yIDJoLTE0YTIgMiAwIDAgMSAtMiAtMnYtMTB6IiAvPjxwYXRoIGQ9Ik0zIDdsOSA2bDkgLTYiIC8+PC9zdmc+Cg==)](https://forum.setdef.com/tags/c/rooibos/bug) [![
Announcements](https://img.shields.io/badge/forum-announcements-3b44ac.svg?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiNmZmZmZmYiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIiBjbGFzcz0iaWNvbiBpY29uLXRhYmxlciBpY29ucy10YWJsZXItb3V0bGluZSBpY29uLXRhYmxlci1tYWlsIj48cGF0aCBzdHJva2U9Im5vbmUiIGQ9Ik0wIDBoMjR2MjRIMHoiIGZpbGw9Im5vbmUiLz48cGF0aCBkPSJNMyA3YTIgMiAwIDAgMSAyIC0yaDE0YTIgMiAwIDAgMSAyIDJ2MTBhMiAyIDAgMCAxIC0yIDJoLTE0YTIgMiAwIDAgMSAtMiAtMnYtMTB6IiAvPjxwYXRoIGQ9Ik0zIDdsOSA2bDkgLTYiIC8+PC9zdmc+Cg==)](https://forum.setdef.com/tags/c/rooibos/announcement)


## Introduction

**rooibos** is a gem in the [RatatuiRuby ecosystem](https://www.ratatui-ruby.dev).
**ratatui_ruby** is a community wrapper that is not affiliated with [the Ratatui team](https://github.com/orgs/ratatui/people).

> [!WARNING]
> **rooibos** is currently in **BETA**. The API may change with minor versions.

**[Why RatatuiRuby?](https://www.ratatui-ruby.dev/docs/trunk/doc/getting_started/why_md.html)** — Native Rust performance, zero runtime overhead, and Ruby's expressiveness. [See how we compare](https://www.ratatui-ruby.dev/docs/trunk/doc/getting_started/why_md.html) to CharmRuby, raw Rust, and Go.

Please follow the [announcements](https://forum.setdef.com/tags/c/rooibos/announcement) to stay up-to-date on new releases. See the [`trunk` branch](https://github.com/setdef/Rooibos/tree/trunk) for pre-release updates.

---

## Quick Links

### The Ecosystem

**RatatuiRuby:** [Core engine](https://www.ratatui-ruby.dev)
• **Rooibos:** [MVU architecture](https://www.rooibos.run)
• **Kit:** [Component architecture](https://sr.ht/~kerrick/ratatui_ruby/#chapter-3-the-object-path--kit) (Planned)
• **DSL:** [Glimmer syntax](https://sr.ht/~kerrick/ratatui_ruby/#chapter-4-the-syntax) (Planned)
• **Framework:** [Omakase framework](https://sr.ht/~kerrick/ratatui_ruby/#chapter-5-the-framework) (Planned)
• **UI:** [Polished widgets](https://sr.ht/~kerrick/ratatui_ruby#chapter-6-licensing) (Planned)
• **UI Pro:** [More polished widgets](https://sr.ht/~kerrick/ratatui_ruby#chapter-6-licensing) (Planned)

### For App Developers

**Get Started:** [Quickstart](https://www.ratatui-ruby.dev/docs/trunk/doc/getting_started/quickstart_md.html)
• [Examples](https://www.ratatui-ruby.dev/docs/trunk/examples/app_all_events/README_md.html)
⸺ **Stay Informed:** [Announcements](https://forum.setdef.com/tags/c/rooibos/announcement)
• [FAQ](https://www.ratatui-ruby.dev/docs/trunk/doc/troubleshooting/index_md.html)
⸺ **Reach Out:** [Forum](https://forum.setdef.com/c/rooibos)
• [Bug Tracker](https://forum.setdef.com/tags/c/rooibos/bug)

### For Contributors

**Get Started:** [Contributing Guide](./CONTRIBUTING.md)
• [Code of Conduct](./CODE_OF_CONDUCT.md)
⸺ **Stay Informed:** [Announcements](https://forum.setdef.com/tags/c/rooibos/announcement)
• [FAQ](https://www.ratatui-ruby.dev/docs/trunk/doc/troubleshooting/index_md.html)
⸺ **Reach Out:** [Forum](https://forum.setdef.com/c/rooibos)
• [Bug Tracker](https://forum.setdef.com/tags/c/rooibos/bug)

---

## Compatibility

**rooibos** is designed to run on [everything Ruby does](https://www.ruby-lang.org/en/documentation/installation/), including:

- GNU/Linux, macOS, Windows, OpenBSD, and FreeBSD; and
- x86_64 (AMD, Intel) and ARM (Apple Silicon, Raspberry Pi).

We support the latest minor version of every
[non-eol Ruby version](https://www.ruby-lang.org/en/downloads/branches/),
including Ruby 4.


## Installation

Add this line to your application's Gemfile:

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
gem "rooibos"
```
<!-- SPDX-SnippetEnd -->

And then execute:

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```bash
bundle install
```
<!-- SPDX-SnippetEnd -->

Or install it yourself with:

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```bash
gem install rooibos
```
<!-- SPDX-SnippetEnd -->


## Usage

**rooibos** uses the Model-View-Update (MVU) pattern. You provide an immutable model, a view function, and an update function.

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
<!-- SYNC:START:examples/verify_readme_usage/app.rb:mvu -->
```ruby
Model = Data.define(:text)

Init = -> do
  Model.new(text: "Hello, Ratatui! Press 'q' to quit.")
end

View = -> (model, tui) do
  tui.paragraph(
    text: model.text,
    alignment: :center,
    block: tui.block(
      title: "My Ruby TUI App",
      borders: [:all],
      border_style: { fg: "cyan" }
    )
  )
end

Update = -> (msg, model) do
  if msg.q? || msg.ctrl_c?
    Rooibos::Command.exit
  else
    model
  end
end

def run
  Rooibos.run(VerifyReadmeUsage)
end
```
<!-- SYNC:END -->
<!-- SPDX-SnippetEnd -->

![Hello Ratatui](./doc/images/verify_readme_usage.png)

For a full tutorial, see [the Quickstart](./doc/getting_started/quickstart.md). For an explanation of the application architecture, see [Scaling Up](./doc/scaling_up/index.md).


## Features

_Because this gem is in alpha, it lacks documentation. Please check the source files._


## Documentation

| Resource | Description |
|----------|-------------|
| [Quickstart](./doc/getting_started/quickstart.md) | Get running in 5 minutes |
| [Scaling Up](./doc/scaling_up/index.md) | Patterns for scaling your app |
| [Guides](./doc/index.md) | Tutorials, examples, and more |
| API Reference | To generate full RDoc documentation, run `bundle exec rake rdoc` |
| [Ecosystem](https://www.ratatui-ruby.dev) | Learn more about the RatatuiRuby ecosystem |


## Contributing

The [discussion forum](https://forum.setdef.com/tags/c/rooibos/discussion) is the best place to ask questions, share patches, and get feedback. Report bugs on the [bug tracker](https://forum.setdef.com/tags/c/rooibos/bug). All participants follow the [Code of Conduct](./CODE_OF_CONDUCT.md).


Want to help develop **rooibos**? Check out the [contribution guide](./CONTRIBUTING.md).

**Note**: Active development happens on the `trunk` branch. Use `trunk` if you are a contributor or want the latest cutting-edge features. `stable` is for stable releases only.


## Copyright & License

**rooibos** is copyright 2026, Kerrick Long.

The library is [LGPL-3.0-or-later](./LICENSES/LGPL-3.0-or-later.txt): you can use it in proprietary applications, but you must share changes you make to **rooibos** itself. Documentation snippets and widget examples are [MIT-0](./LICENSES/MIT-0.txt): copy and use them without attribution.

Documentation is [CC-BY-SA-4.0](./LICENSES/CC-BY-SA-4.0.txt). Build tooling and full app examples are [LGPL-3.0-or-later](./LICENSES/LGPL-3.0-or-later.txt). See each file's SPDX comment for specifics.

Some parts of this program are copied from other sources under appropriate reuse licenses, and the copyright belongs to their respective owners. See the [REUSE Specification – Version 3.3](https://reuse.software/spec-3.3/) for details.

This program was created with significant assistance from multiple LLMs. The process was human-controlled through creative prompts, with human contributions to each commit. See commit footers for model attribution. [declare-ai.org](https://declare-ai.org/1.0.0/creative.html)
