<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# End-to-End PTY Testing for TUI Applications

This document explains how to write end-to-end tests for Rooibos TUI applications
using Ruby's PTY module. These tests verify that `rooibos new` generated apps
can be launched via `rooibos run` and respond correctly to user input.

## Background

Testing TUI applications is challenging because:

1. **TUI apps require a real terminal** - They use raw mode, escape sequences,
   and read from the controlling terminal (`/dev/tty`), not just stdin.
2. **Crossterm reads from the controlling terminal** - Via `isatty()` check on
   stdin, falling back to `/dev/tty` if stdin isn't a tty.
3. **Bundler context matters** - Tests running via `bundle exec` inherit that
   Bundler context, which can interfere with the generated app's own dependencies.

## Key Learnings

### 1. Use `PTY.spawn` for Proper Terminal Emulation

`PTY.spawn` properly establishes a controlling terminal for the child process by:
- Calling `setsid()` to create a new session
- Setting the PTY as the controlling terminal via `TIOCSCTTY`
- Connecting the child's stdin/stdout/stderr to the PTY

```ruby
require "pty"

# Ruby's PTY.spawn returns [r, w, pid] where:
# - r = readable IO (receives child's stdout/stderr)
# - w = writable IO (sends to child's stdin)
# These are the host's view of the PTY - what the child writes, we read from r;
# what we write to w, the child reads from stdin.
pty_out, pty_in, pid = PTY.spawn("rooibos", "run", chdir: app_dir)
```

### 2. Escape the Parent's Bundler Context

When tests run via `bundle exec`, child processes inherit that Bundler context.
For generated apps to use their own `Gemfile`, wrap spawning in:

```ruby
Bundler.with_unbundled_env do
  pty_out, pty_in, pid = PTY.spawn("rooibos", "run", chdir: app_dir)
  # ... all PTY interaction must happen inside this block
end
```

### 3. Drain the PTY Output Buffer

**Critical**: TUI apps write escape sequences and screen content to stdout.
If you don't read from the PTY, the buffer fills up and the app blocks waiting
to write, never reading your input.

Use a background thread to continuously drain output:

```ruby
reader = Thread.new do
  loop do
    pty_out.read_nonblock(4096)
  rescue IO::WaitReadable
    pty_out.wait_readable(0.1)
  rescue EOFError, Errno::EIO
    break
  end
end

# ... send input, wait for exit ...

reader.kill rescue nil
```

### 5. Set the PTY Window Size

**Critical**: Ruby's `PTY.spawn` creates terminals with 0×0 dimensions by default.
TUI apps that query terminal size will get zero and may crash (e.g., negative width
calculations). Set standard 80×24 dimensions after spawning:

```ruby
require "io/console"

pty_out, pty_in, pid = PTY.spawn("rooibos", "run", chdir: app_dir)
pty_out.winsize = [24, 80]  # rows, columns
```

### 6. Send Key Events as Raw Bytes

Ctrl+C is sent as the ETX byte (0x03), not as a signal:

```ruby
pty_in.sync = true       # Disable buffering
pty_in.write("\x03")     # ETX = Ctrl+C
pty_in.flush
```

Crossterm parses bytes 0x01-0x1A as Ctrl+A through Ctrl+Z:

<!-- SPDX-SnippetBegin -->
<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-SnippetCopyrightText: 2019 Timon -->
```rust
// From crossterm/src/event/sys/unix/parse.rs
c @ b'\x01'..=b'\x1A' => KeyEvent::new(
    KeyCode::Char((c - 0x1 + b'a') as char),
    KeyModifiers::CONTROL,
)
```
<!-- SPDX-SnippetEnd -->

### 5. Require Global Gem Installation

Generated apps expect `rooibos` to be installed as a gem. For tests:

```ruby
def require_global_rooibos!
  require "rooibos/version"
  installed = Gem::Specification.find_all_by_name("rooibos", Rooibos::VERSION)
  if installed.empty?
    flunk "Rooibos #{Rooibos::VERSION} not installed globally. Run: rake install:force"
  end
end
```

Run `rake install:force` before tests (CI does this automatically).

## Complete Example

See [test/cli/test_new_integration.rb](../../test/cli/test_new_integration.rb),
specifically the `test_new_app_runs_and_exits_on_ctrl_c` method.

## Common Pitfalls

| Problem | Cause | Solution |
|---------|-------|----------|
| App can't load its own gem | Wrong Bundler context | Use `Bundler.with_unbundled_env` |
| Test hangs forever | PTY buffer full | Add background reader thread |
| `LoadError: cannot load such file` | Gem not installed globally | Run `rake install:force` |
| Ctrl+C doesn't work | Sending SIGINT instead of byte | Write `"\x03"` to PTY |
| `bundle exec rooibos run` fails | Inherits parent's Bundler | Use global `rooibos` command |

## References

- `ruby/ext/pty/pty.c` - How PTY.spawn sets up the controlling terminal
- `crossterm/src/event/sys/unix/parse.rs` - How key events are parsed from raw bytes
- `crossterm/src/terminal/sys/file_descriptor.rs` - How crossterm decides where to read input from

## Want a Helper API?

This pattern isn't currently exposed in `Rooibos::TestHelper` because most
testing needs are met by `with_test_terminal`. However, reach out if you need
PTY-based E2E testing regularly, and you would use a helper like the following.

```ruby
Rooibos::TestHelper.with_pty("rooibos", "run") do |pty_in, pty_out, pid|
  # ...
end
```

If you'd use this, please email the
[~kerrick/ratatui_ruby-discuss](https://lists.sr.ht/~kerrick/ratatui_ruby-discuss)
mailing list to request it as a feature.
