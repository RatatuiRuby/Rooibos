<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->
# Custom Commands

## Context

Your application needs to do work in the background. Fetch data from APIs. Query databases. Read files. Process images. These operations block. Running them on the main thread freezes the UI.

## Problem

Callbacks create race conditions. Threads scatter state across the codebase. Managing concurrency manually is error-prone. Your update function needs to stay pure and deterministic.

## Solution

Commands wrap background work in a protocol. The runtime dispatches them in threads. They send messages back to your update function. Your logic stays pure. The framework handles concurrency.

Use commands for HTTP requests, database queries, file I/O, or any asynchronous work.

## Three Patterns

### Pattern 1: Procs for One-Off Tasks

Define a lambda. Pass it to <tt>Command.custom</tt>:

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
fetch_data = -> (out, token) {
  response = HTTParty.get("https://api.example.com/users")
  out.put(:users_loaded, response.parsed_response)
}

[model, Command.custom(fetch_data)]
```
<!-- SPDX-SnippetEnd -->

The lambda receives two arguments:

- <tt>out</tt>: An outlet to send messages back to update
- <tt>token</tt>: A cancellation token to check if work should stop

### Pattern 2: Classes for Reusable Commands

Define a class. Include <tt>Command::Custom</tt>. Implement <tt>call</tt>:

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
class FetchUsers < Data.define(:url, :tag)
  include RatatuiRuby::Tea::Command::Custom

  def call(out, token)
    response = HTTParty.get(url)
    out.put(tag, response.parsed_response)
  end
end

# Dispatch it
[model, FetchUsers.new(
  url: "https://api.example.com/users",
  tag: :users_loaded
)]
```
<!-- SPDX-SnippetEnd -->

The <tt>Data.define</tt> base class makes your command immutable and thread-safe.

### Pattern 3: Composition for Multi-Step Workflows

Use <tt>out.source</tt> to run child commands synchronously. Fetch one result. Use it to compose the next command:

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
class FetchUserWithCompany < Data.define(:user_id, :tag)
  include RatatuiRuby::Tea::Command::Custom

  def call(out, token)
    # Step 1: Fetch user profile
    user_result = out.source(
      FetchUser.new(user_id: user_id, tag: :_),
      token,
      timeout: 10.0
    )
    return if user_result.nil?
    return if token.canceled?

    # Extract company_id from user result
    user_data = user_result.last
    company_id = user_data[:company_id]

    # Step 2: Fetch company using ID from step 1
    company_result = out.source(
      FetchCompany.new(company_id: company_id, tag: :_),
      token,
      timeout: 10.0
    )
    return if token.canceled?

    # Combine results
    out.put(tag, {
      user: user_data,
      company: company_result&.last
    })
  end
end
```
<!-- SPDX-SnippetEnd -->

The <tt>source</tt> method blocks until the child command sends a message. It returns <tt>nil</tt> if cancelled or timed out. Exceptions from children propagate to the parent.

Use this for sequential API calls, conditional fetches, or any workflow where step 2 depends on step 1's result.

## The Shareability Rule

Commands run in background threads. Ruby's Ractor system requires thread-safe objects to be "shareable." This means they cannot hold mutable state.

### For Procs: Don't Capture Locals

A proc captures variables from its surrounding scope. If those variables are mutable, the proc cannot be shared.

**❌ Wrong — Captures Mutable Variable:**

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
conn = DatabaseConnection.new  # Created outside

fetch_users = -> (out, token) {
  users = conn.query("SELECT * FROM users")  # Captures 'conn'
  out.put(:users, users)
}

Command.custom(fetch_users)  # 💥 Fails - conn is not shareable
```
<!-- SPDX-SnippetEnd -->

**✅ Correct — Creates Connection Inside:**

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
fetch_users = -> (out, token) {
  conn = DatabaseConnection.new  # Created inside
  users = conn.query("SELECT * FROM users")
  out.put(:users, users)
  conn.close
}

Command.custom(fetch_users)  # ✅ Works - no captured state
```
<!-- SPDX-SnippetEnd -->

The lambda now captures nothing. It creates the connection fresh on every execution.

### For Classes: Reference Constants

Instance methods don't create closures. They can reference constants without shareability issues.

**✅ Database Connection Pattern:**

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
# Create a persistent connection or connection pool
DB = Sequel.connect(ENV["DATABASE_URL"])

class FetchUsers < Data.define(:tag)
  include RatatuiRuby::Tea::Command::Custom

  def call(out, token)
    users = DB[:users].where(active: true).all
    out.put(tag, users)
  end
end
```
<!-- SPDX-SnippetEnd -->

The <tt>FetchUsers</tt> instance only holds <tt>tag</tt> (a symbol, always shareable). The <tt>call</tt> method references the global <tt>DB</tt> constant at runtime.

**✅ Pass Configuration as Attributes:**

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
# frozen_string_literal: true

class DatabaseQuery < Data.define(:sql, :params, :tag)
  include RatatuiRuby::Tea::Command::Custom

  def call(out, token)
    result = DB[sql, *params].all
    out.put(tag, result)
  end
end

# Usage
DatabaseQuery.new(
  sql: "SELECT * FROM users WHERE role = ?",
  params: ["admin"].freeze,
  tag: :admin_users
)
```
<!-- SPDX-SnippetEnd -->

The query and parameters are frozen strings and symbols. The database connection is a global constant.

## What Makes Objects Shareable?

- Frozen strings
- Symbols
- Numbers
- <tt>true</tt>, <tt>false</tt>, <tt>nil</tt>
- <tt>Data.define</tt> instances with shareable attributes
- Constants (accessed at runtime, not captured in closures)

## What Cannot Be Shared?

- Mutable strings (<tt>String.new</tt>)
- Database connections
- File handles
- Test instance references (<tt>self</tt> in a test method)
- Any object that holds mutable state

## Debug Mode Validation

In tests, <tt>Command.custom</tt> validates shareability. It tries to make your callable shareable. If it fails, you see:

```
RatatuiRuby::Error::Invariant: Command.custom requires a Ractor-shareable callable.
Proc is not shareable. Use Ractor.make_shareable or define at top-level.
```

This means your lambda captures something mutable. Common causes:

**1. Test Instance Capture**

Defining a lambda inside a test method captures <tt>self</tt>:

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
class MyTest < Minitest::Test
  def test_command
    # ❌ Lambda captures 'self' (the test instance)
    cmd = Command.custom { |out, token| out.put(@result) }
  end
end
```
<!-- SPDX-SnippetEnd -->

**Solution: Define at Class Level**

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
class MyTest < Minitest::Test
  # Lambda defined at class level doesn't capture instance
  TEST_COMMAND = Command.custom(-> (out, token) {
    Thread.current[:test_result] = :done
    out.put(:complete)
  })

  def test_command
    Tea.run(..., command: TEST_COMMAND)
    assert_equal :done, Thread.current[:test_result]
  end
end
```
<!-- SPDX-SnippetEnd -->

**2. Mutable Closure**

Referencing a local variable from outside the lambda:

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
result = []  # Mutable array

cmd = Command.custom { |out, token|
  result << "item"  # ❌ Captures 'result'
  out.put(:done)
}
```
<!-- SPDX-SnippetEnd -->

**Solution: Use Constants or Create at Runtime**

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
cmd = Command.custom { |out, token|
  result = []  # Created inside
  result << "item"
  out.put(:done, result)
}
```
<!-- SPDX-SnippetEnd -->

## Production Mode

In production (non-test environments), <tt>Command.custom</tt> skips validation. This avoids overhead since the framework doesn't yet use Ractors.

Validation only runs in debug mode. Catch bugs during development. Ship fast in production.

## Cancellation

Long-running commands should check the cancellation token:

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
class PollAPI < Data.define(:url, :interval_seconds, :tag)
  include RatatuiRuby::Tea::Command::Custom

  def call(out, token)
    until token.canceled?
      response = HTTParty.get(url)
      out.put(tag, response.parsed_response)
      sleep interval_seconds
    end
  end
end
```
<!-- SPDX-SnippetEnd -->

Store the command handle in your model. Cancel it when the user dismisses the view:

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
# Start polling
cmd = PollAPI.new(
  url: "https://api.example.com/status",
  interval_seconds: 30,
  tag: :status_update
)
[model.with(poller: cmd), cmd]

# Later, cancel it
[model.with(poller: nil), Command.cancel(model.poller)]
```
<!-- SPDX-SnippetEnd -->

### Grace Periods

The <tt>grace_period</tt> controls how long the runtime waits for a command to finish after cancellation at application exit. Default is 0.1 seconds. If your command has a long grace period and ignores <tt>token.canceled?</tt>, it may prevent the application from exiting. Users will not like that.

Commands that ignore <tt>token.canceled?</tt> are orphaned (left running until process exit). The runtime uses cooperative cancellation only. It will not forcibly kill threads. Ruby, however, _will_ forcibly kill threads when the process exits.

Override the grace period for commands that need more time to clean up:

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
class WebSocketListener < Data.define(:url, :tag)
  include RatatuiRuby::Tea::Command::Custom

  def tea_cancellation_grace_period
    5.0  # Give the WS close handshake time to complete
  end

  def call(out, token)
    ws = connect_websocket(url)

    until token.canceled?
      message = ws.receive
      out.put(tag, message)
    end

    ws.close  # Cleanup
  end
end
```
<!-- SPDX-SnippetEnd -->

## Common Patterns

### Background File Processing

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
class ProcessFile < Data.define(:path, :tag)
  include RatatuiRuby::Tea::Command::Custom

  def call(out, token)
    lines = File.readlines(path)
    processed = lines.map(&:strip).reject(&:empty?)
    out.put(tag, processed)
  end
end
```
<!-- SPDX-SnippetEnd -->

### Batch Operations with Progress

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
class BatchImport < Data.define(:items, :tag)
  include RatatuiRuby::Tea::Command::Custom

  def call(out, token)
    items.each_with_index do |item, index|
      return if token.canceled?

      import_item(item)

      # Send progress updates
      out.put(:progress, {
        current: index + 1,
        total: items.size
      })
    end

    out.put(tag, :complete)
  end

  private

  def import_item(item)
    # Your import logic
  end
end
```
<!-- SPDX-SnippetEnd -->

### Database Query with Connection Pooling

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
# Connection pool (created once at app startup)
DB = Sequel.connect(
  ENV["DATABASE_URL"],
  max_connections: 10
)

class FetchUserProfile < Data.define(:user_id, :tag)
  include RatatuiRuby::Tea::Command::Custom

  def call(out, token)
    user = DB[:users].where(id: user_id).first
    posts = DB[:posts].where(user_id: user_id).limit(10).all

    out.put(tag, { user: user, posts: posts })
  end
end
```
<!-- SPDX-SnippetEnd -->

## Summary

**For one-off tasks:**
- Use <tt>Command.custom</tt> with lambdas
- Don't capture mutable variables
- Create resources inside the lambda

**For reusable commands:**
- Use <tt>Data.define</tt> classes
- Include <tt>Command::Custom</tt>
- Reference constants for database connections
- Pass configuration as frozen attributes

**Debug mode catches bugs:**
- Validates shareability in tests
- Provides clear error messages
- Skipped in production for performance

**Cancellation:**
- Check <tt>token.canceled?</tt> in loops
- Set <tt>grace_period</tt> for cleanup time
- Store command handles in your model
