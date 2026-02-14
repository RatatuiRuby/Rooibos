<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Fractal Dashboard

Demonstrates **Fractal Architecture** with two Update styles: manual routing
and the declarative `Rooibos::Router` DSL.

## Architecture

```
Dashboard (root)
├── StatsPanel
│   ├── SystemInfo  → Command.system("uname -a", :system_info)
│   └── DiskUsage   → Command.system("df -h", :disk_usage)
├── NetworkPanel
│   ├── Ping        → Command.system("ping -c 1 localhost", :ping)
│   └── Uptime      → Command.system("uptime", :uptime)
└── CustomShellModal
    ├── CustomShellInput   (text input)
    └── CustomShellOutput  (streaming output)
```

## Hotkeys

| Key      | Action                            |
|----------|-----------------------------------|
| `s`      | Fetch system info                 |
| `d`      | Fetch disk usage                  |
| `p`      | Ping localhost                    |
| `u`      | Fetch uptime                      |
| `c`      | Open shell command modal          |
| `q`      | Quit                              |
| `Ctrl+C` | Force quit (works during modal)   |

## Two Update Variants

Both variants produce identical behavior. Only the Update implementation differs.

- **Manual** (`update_manual.rb`) — Explicit pattern matching on `Message::System::Batch`,
  `Message::System::Stream`, and `Message::Routed`. Full control, full boilerplate.
- **Router** (`update_router.rb`) — Declarative `Rooibos::Router` DSL with `route`,
  `forward_events`, `forward`, and `otherwise`. Minimal boilerplate.

## Key Concepts

1. **Fragment isolation**: Each fragment has its own Model, Init, Update, and View.
   It knows nothing about parents.
2. **Message routing**: The Router (or manual code) forwards `Message::System::Batch`
   results and `Message::System::Stream` chunks to the correct child fragment.
3. **Semantic triggers**: Key presses are forwarded as `Message::Routed` envelopes
   (e.g. `:fetch_system_info`), so panels decide how to handle their own triggers.

## Usage

```bash
ruby examples/app_fractal_dashboard/app.rb manual   # Verbose pattern matching
ruby examples/app_fractal_dashboard/app.rb router   # Router DSL
ruby examples/app_fractal_dashboard/app.rb          # Coin flip!
```
