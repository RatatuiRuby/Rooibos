<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->
# Async Work

## Context

Your application does concurrent work. It fetches from multiple APIs. It reads from sockets. It processes streams. These operations overlap in time.

## Problem

Threads are hard. Exceptions in spawned threads vanish silently. The main thread never learns what happened. Your application hangs, waiting for messages that will never arrive. Debugging this is miserable.

## Solution

Rooibos handles concurrency for you. Two patterns cover nearly every case. Use them instead of raw threads.

## Pattern 1: Command Orchestration

Compose child commands instead of spawning threads. Use <tt>out.source</tt> for sequential steps. Use <tt>Command.all</tt> for parallel steps.

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
class LoadDashboard < Data.define(:user_id, :tag)
  include Rooibos::Command::Custom

  def call(out, token)
    # Step 1: Authenticate (sequential - we need the token first)
    auth = out.source(Authenticate.new(user_id:, tag: :_), token)
    return if auth.nil? || token.canceled?

    # Step 2: Fetch dashboard data in parallel, waiting for all to complete
    dashboard = out.source(
      Command.all(:_, [
        FetchProfile.new(token: auth[:token], tag: :profile),
        FetchNotifications.new(token: auth[:token], tag: :notifications),
        FetchWeather.new(tag: :weather)
      ]),
      token
    )
    return if dashboard.nil? || token.canceled?

    # Step 3: Send a message to the update with the dashboard data
    out.put(tag, dashboard.results)
    return if token.canceled?

    # Step 4: Log the access (sequential - after we have data)
    out.source(LogAccess.new(user_id:, tag: :_), token)
    return if token.canceled?

    # COMING SOON: out.source_nonblock
    # Step 5: Watch for new data via HTTP Server-Sent Events, handling parallel streaming data
    # 5a: Pass messages from the StreamNotifications custom command directly to LoadDashboard's out.put
    notifications = out.source_nonblocki(
      StreamNotifications.new(:user_id, auth[:token]),
      token,
    )
    # 5b: Do work to the messages before sending them to the update function
    deltas = out.source_nonblock(
      StreamDashboardDeltas.new(dashboard.results[:profile][:id], auth[:token]),
      token,
      DeltaPostProcessor.new(:user_id)
    )
    # 5c: block this command on both async outsourced commands finishing
    out.last(notifications, deltas)
    return if token.canceled?

    # Step 6: Log completion
    out.source(LogAccess.new(user_id:, tag: :_, finished: true), token)
  end
end
```
<!-- SPDX-SnippetEnd -->

<tt>out.source</tt> blocks until the child command finishes. Pass <tt>Command.all</tt> to run children in parallel. Exceptions propagate correctly. Cancellation stops the workflow at any point.

Use this for any multi-step workflow with dependencies between stages.

## Pattern 2: Multiplexed I/O

Read from multiple sources without threads. Ruby's <tt>IO.select</tt> waits for any of several IOs to become ready.

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
class MultiSocketReader < Data.define(:sockets, :tag)
  include Rooibos::Command::Custom

  def call(out, token)
    remaining = sockets.dup

    until remaining.empty? || token.canceled?
      # Wait up to 0.1s for any socket to have data
      ready = IO.select(remaining, nil, nil, 0.1)
      next unless ready

      ready[0].each do |socket|
        data = socket.read_nonblock(4096, exception: false)
        case data
        when :wait_readable
          next
        when nil
          remaining.delete(socket)
        else
          out.put(:data, { socket: socket, chunk: data })
        end
      end
    end

    out.put(tag, :complete)
  end
end
```
<!-- SPDX-SnippetEnd -->

<tt>IO.select</tt> multiplexes reads across sockets, pipes, or files. One thread handles many connections. No spawned threads means no silent failures.

Use this for chat clients, log tailers, or any multi-stream scenario.

## Why Not Threads?

You might wonder: "Why can't I just spawn a thread?"

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long
  SPDX-License-Identifier: MIT-0
-->
```ruby
# ❌ Don't do this
def call(out, token)
  Thread.new do
    data = fetch_something
    out.put(:result, data)
  end
end
```
<!-- SPDX-SnippetEnd -->

This looks harmless. It hides a trap.

If <tt>fetch_something</tt> raises, the exception happens in the spawned thread. Ruby logs it. The main thread never sees it. Your <tt>call</tt> method returns. The runtime considers the command complete. But <tt>out.put</tt> never ran. Your update function waits for <tt>:result</tt> forever.

The runtime cannot protect you from this. Threads spawned inside your command escape its error handling. The framework wraps <tt>call</tt> in a rescue. It does not wrap threads you create.

Use the patterns above instead. They keep errors visible.

## Choosing the Right Pattern

| Situation | Pattern |
|-----------|---------|
| Multi-step workflows | <tt>out.source</tt> + <tt>Command.all</tt> |
| Read from multiple sockets/pipes | <tt>IO.select</tt> |
| One blocking operation | Just do it in <tt>call</tt> |

Commands already run off the main thread. You rarely need additional concurrency. When you do, these patterns handle the hard parts.
