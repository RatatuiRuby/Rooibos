# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "concurrent-edge"
require_relative "command/custom"
require_relative "command/outlet"
require_relative "command/lifecycle"
require_relative "command/timed"
require_relative "command/wait"
require_relative "command/clock"
require_relative "command/random"
require_relative "command/batch"
require_relative "command/all"
require_relative "command/http"
require_relative "command/open"
require_relative "command/deliver"
require_relative "command/bubble"

module Rooibos
  # Commands represent side effects.
  #
  # The MVU pattern separates logic from effects. Your update function returns a pure
  # model transformation. Side effects go in commands. The runtime executes them.
  #
  # Commands produce **messages**, not callbacks. The +tag+ argument names the message
  # so your update function can pattern-match on it. This keeps all logic in +update+
  # and ensures messages are Ractor-shareable.
  #
  # === Examples
  #
  #   # Terminate the application
  #   [model, Command.exit]
  #
  #   # Run a shell command; produces [:got_files, {stdout:, stderr:, status:}]
  #   [model, Command.system("ls -la", :got_files)]
  #
  #   # No side effect
  #   [model, nil]
  module Command
    # Terminates the application.
    #
    # Users press a key or click a button to quit. The update function returns
    # a command, and the runtime executes it. Termination is special: the
    # runtime detects this sentinel before dispatching and breaks the loop.
    #
    # Prefer the <tt>Command.exit</tt> factory method for convenience.
    #
    # === Example
    #
    #   # Using the factory method (recommended)
    #   [model, Command.exit]
    #
    #   # Using the class directly
    #   [model, Exit.new]
    class Exit < Data.define
      include Custom

      # Ruby 3.x does not auto-freeze zero-member Data.define instances,
      # which prevents Ractor shareability. Explicit freeze is idempotent on 4.0+.
      def initialize # :nodoc:
        super
        freeze
      end

      # Stub - Exit is a sentinel handled by runtime before dispatch.
      def call(_out, _token)
        raise "Exit command should never be dispatched"
      end
    end

    # Internal wrapper for multiple commands to be dispatched separately.
    #
    # Router DSL uses this to return multiple commands from observe + keymap
    # without triggering Message::Batch. The runtime unwraps this and dispatches
    # each command independently.
    #
    # Unlike Batch:
    # - Does NOT send Message::Batch on completion
    # - Each command runs and sends its own messages
    # - Invisible to app developers
    class Separate < Data.define(:commands) # :nodoc:
      include Custom

      # Stub - Separate is a sentinel unwrapped by runtime before dispatch.
      def call(_out, _token)
        raise "Separate command should never be dispatched directly"
      end

      def extract_bubbles # :nodoc:
        bubbles, rest = commands.partition { |c| c.is_a?(Bubble) }
        remaining = case rest.size
        when 0 then nil
        when 1 then rest.first
        else Separate.new(commands: rest)
        end
        [bubbles, remaining]
      end
    end
    private_constant :Separate

    # Creates a quit command.
    #
    # Returns a sentinel the runtime detects to terminate the application.
    #
    # === Example
    #
    #   def update(message, model)
    #     case message
    #     in { type: :key, code: "q" }
    #       [model, Command.exit]
    #     else
    #       [model, nil]
    #     end
    #   end
    def self.exit
      Exit.new
    end

    # Delivers a message to Update.
    #
    # Custom commands produce results. Those results feed back into your update
    # function. This factory method wraps a message in a command that delivers
    # it when executed.
    #
    # === Example
    #
    #   # Define a message type
    #   class FetchComplete < Data.define(:envelope, :data)
    #     include Rooibos::Message::Predicates
    #   end
    #
    #   # Send after a synchronous operation
    #   result = fetch_data_sync()
    #   [model, Command.deliver(FetchComplete.new(envelope: :items, data: result))]
    #
    #   # Receive in Update
    #   in { type: :fetch_complete, envelope: :items, data: }
    #     model.with(items: data)
    def self.deliver(message)
      Deliver.new(message:)
    end

    # Bubbles a message outward through the fragment hierarchy.
    #
    # Nested fragments produce results. Sometimes those results belong to an outer
    # fragment. Passing callbacks or references inward couples fragments tightly.
    # The hierarchy becomes rigid.
    #
    # This command wraps a message for outward propagation. Outer fragments
    # intercept the bubble and decide how to handle it. With the Router DSL,
    # use <tt>observe</tt> or <tt>intercept</tt>. Without the Router, check
    # for <tt>Command::Bubble</tt> manually and extract the message.
    #
    # Use it for notifications, validation results, or any signal that flows
    # from nested fragments to outer containers.
    #
    # === Example (Router DSL)
    #
    #   # Nested fragment signals completion
    #   class TaskComplete < Data.define(:envelope, :task_id)
    #     include Rooibos::Message::Predicates
    #   end
    #
    #   # Return from nested Update
    #   [model, Command.bubble(TaskComplete.new(envelope: :task, task_id: 42))]
    #
    #   # Outer Router observes the bubble
    #   observe TaskComplete do |model, message|
    #     model.with(completed_tasks: model.completed_tasks + [message.task_id])
    #   end
    #
    # === Example (Manual Bubbling)
    #
    #   # Outer Update handles bubbles without Router
    #   def self.handle_nested_result(cmd, model)
    #     return [model, nil] unless cmd.is_a?(Command::Bubble)
    #
    #     case cmd.message
    #     when TaskComplete
    #       [model.with(completed_tasks: model.completed_tasks + [cmd.message.task_id]), nil]
    #     else
    #       [model, cmd]  # Re-bubble outward
    #     end
    #   end
    def self.bubble(message)
      Bubble.new(message:)
    end

    # Creates a fresh cancellation that never fires.
    #
    # Some I/O operations cannot be canceled mid-execution. Ruby's <tt>Net::HTTP</tt>
    # blocks until completion or timeout — there is no way to interrupt it.
    #
    # A shared singleton would be unsafe. If any code path accidentally resolves
    # the origin, all commands using it become canceled.
    #
    # Use it for commands that wrap non-cancellable blocking I/O.
    #
    # === Example
    #
    #   token = Command.uncancellable
    #   HttpCommand.new(url).call(outlet, token)
    def self.uncancellable
      cancellation, _origin = Concurrent::Cancellation.new(Concurrent::Promises.resolvable_event)
      cancellation
    end

    # Cancels a running command.
    #
    # Long-running commands (WebSocket listeners, database pollers) run until
    # stopped. Stopping them requires signaling from outside the command. The
    # runtime tracks active commands by their object identity and routes cancel
    # requests.
    #
    # This type carries the handle (command object) to cancel. The runtime
    # pattern-matches on <tt>Command::Cancel</tt> and signals the token.
    #
    # Prefer the <tt>Command.cancel</tt> factory method for convenience.
    #
    # === Example
    #
    #   # Using the factory method (recommended)
    #   [model, Command.cancel(model.active_fetch)]
    #
    #   # Using the class directly
    #   [model, Cancel.new(handle: model.active_fetch)]
    class Cancel < Data.define(:handle)
      include Custom

      # Stub - Cancel is a sentinel handled by runtime before dispatch.
      def call(_out, _token)
        raise "Cancel command should never be dispatched"
      end
    end

    # Request cancellation of a running command.
    #
    # The model stores the command handle (the command object itself). Returning
    # <tt>Command.cancel(handle)</tt> signals the runtime to stop it.
    #
    # [handle] The command object to cancel.
    #
    # === Example
    #
    #   # Dispatch and store handle
    #   cmd = FetchData.new(url)
    #   [model.with(active_fetch: cmd), cmd]
    #
    #   # User clicks cancel
    #   when :cancel_clicked
    #     [model.with(active_fetch: nil), Command.cancel(model.active_fetch)]
    def self.cancel(handle)
      Cancel.new(handle:)
    end

    # Runs a shell command and routes its output back as messages.
    #
    # Apps run external tools: linters, compilers, scripts, system utilities.
    # The runtime dispatches the command in a thread, so the UI stays responsive.
    # Batch mode (default) waits for completion; streaming mode shows output live.
    # Orphaned child processes linger and waste resources, so cancellation sends
    # <tt>SIGTERM</tt> for graceful shutdown, then <tt>SIGKILL</tt> to prevent orphans.
    #
    # Use it to run builds, lint files, execute scripts, or invoke any CLI tool.
    #
    # Prefer the <tt>Command.system</tt> factory method for convenience.
    #
    # === Batch Mode (default)
    #
    # A single message arrives when the command finishes:
    # <tt>Message::System::Batch</tt> with <tt>stdout</tt>, <tt>stderr</tt>, <tt>status</tt>.
    #
    # === Streaming Mode
    #
    # <tt>Message::System::Stream</tt> messages arrive incrementally:
    # <tt>stream: :stdout</tt>:: for each stdout chunk
    # <tt>stream: :stderr</tt>:: for each stderr chunk
    # <tt>stream: :complete</tt>:: when the command finishes
    # <tt>stream: :error</tt>:: if the command cannot start
    #
    # === Example
    #
    #   # Using the factory method (recommended)
    #   Command.system("ls -la", :got_files)
    #   Command.system("tail -f log.txt", :log, stream: true)
    #
    #   # Using the class directly
    #   System.new(command: "ls -la", envelope: :got_files, stream: false)
    class System < Data.define(:command, :envelope, :stream)
      include Custom

      # Returns true if streaming mode is enabled.
      def stream?
        stream
      end

      # Executes the shell command and sends results via outlet.
      #
      # In batch mode, sends a single message with all output.
      # In streaming mode, sends incremental messages as output arrives.
      # Respects cancellation token by sending SIGTERM (then SIGKILL) to child.
      def call(out, token)
        require "open3"

        if stream?
          stream_execution(out, token)
        else
          batch_execution(out)
        end
      end

      private def batch_execution(out)
        stdout, stderr, status = Open3.capture3(command)
        message = Message::System::Batch.new(
          envelope:,
          stdout:,
          stderr:,
          status: status.exitstatus
        )
        out.put(Ractor.make_shareable(message))
      end

      private def stream_execution(out, token)
        # pgroup: true spawns the child in its own process group.
        # On Linux, popen3(string) invokes /bin/sh which may fork (not exec),
        # so killing just the shell PID leaves the child orphaned. Signaling
        # the process group (-pid) ensures TERM reaches all descendants.
        pgroup_opts = Gem.win_platform? ? {} : { pgroup: true }
        Open3.popen3(command, **pgroup_opts) do |stdin, stdout, stderr, wait_thr|
          stdin.close
          pid = wait_thr.pid

          # Track which streams are still open
          streams = { stdout => :stdout, stderr => :stderr }

          until streams.empty?
            # Check cancellation before blocking on IO.select
            if token.canceled? && wait_thr.alive?
              begin
                # On Unix, signal the process group; on Windows, kill the process directly
                Process.kill("TERM", Gem.win_platform? ? pid : -pid)
              rescue Errno::ESRCH
                # Already dead
              end
            end

            # Wait up to 0.05s for any stream to have data
            ready = IO.select(streams.keys, nil, nil, 0.05)
            next unless ready

            ready[0].each do |io|
              stream_type = streams[io]
              begin
                line = io.read_nonblock(8192, exception: false)
                case line
                when :wait_readable
                  next
                when nil, ""
                  # EOF - stream closed
                  streams.delete(io)
                else
                  # Split into lines and send each
                  line.each_line do |l|
                    msg = Message::System::Stream.new(
                      envelope:,
                      stream: stream_type,
                      content: l.freeze,
                      status: nil
                    )
                    out.put(Ractor.make_shareable(msg))
                  end
                end
              rescue EOFError
                streams.delete(io)
              rescue IOError
                # Stream forcibly closed
                streams.delete(io)
              end
            end
          end

          # Wait for process to finish
          wait_thr.join

          status = wait_thr.value.exitstatus
          msg = Message::System::Stream.new(
            envelope:,
            stream: :complete,
            content: nil,
            status:
          )
          out.put(Ractor.make_shareable(msg))
        end
      rescue Errno::ENOENT, Errno::EACCES => e
        msg = Message::System::Stream.new(
          envelope:,
          stream: :error,
          content: e.message,
          status: nil
        )
        out.put(Ractor.make_shareable(msg))
      end
    end

    # Creates a shell execution command.
    #
    # [command] Shell command string to execute.
    # [tag] Symbol or class to tag the result message.
    # [stream] If <tt>true</tt>, the runtime sends incremental stdout/stderr
    #   messages as they arrive. If <tt>false</tt> (default), waits for
    #   completion and sends a single message with all output.
    #
    # === Example (Batch Mode)
    #
    #   # Return this from update:
    #   [model.with(loading: true), Command.system("ls -la", :got_files)]
    #
    #   # Then handle it later:
    #   def update(message, model)
    #     case message
    #     in { type: :system, envelope: :got_files, stdout:, status: 0 }
    #       [model.with(files: stdout.lines), nil]
    #     in { type: :system, envelope: :got_files, stderr:, status: }
    #       [model.with(error: stderr), nil]
    #     end
    #   end
    #
    # === Example (Streaming Mode)
    #
    #   # Return this from update:
    #   [model.with(loading: true), Command.system("tail -f log.txt", :log, stream: true)]
    #
    #   # Then handle incremental messages:
    #   def update(message, model)
    #     case message
    #     in { type: :system, envelope: :log, stream: :stdout, content: line }
    #       [model.with(lines: [*model.lines, line]), nil]
    #     in { type: :system, envelope: :log, stream: :stderr, content: line }
    #       [model.with(errors: [*model.errors, line]), nil]
    #     in { type: :system, envelope: :log, stream: :complete, status: }
    #       [model.with(loading: false, exit_status: status), nil]
    #     in { type: :system, envelope: :log, stream: :error, content: msg }
    #       [model.with(loading: false, error: msg), nil]
    #     end
    #   end
    def self.system(command, envelope, stream: false)
      System.new(command:, envelope:, stream:)
    end

    # Wraps another command's result with a transformation.
    #
    # Fractal Architecture requires composition. Child fragments produce commands
    # with their own tags. Parent fragments need those results routed back with
    # a parent prefix. Without transformation, update functions become
    # monolithic "God Reducers" that know about every child's internals.
    #
    # This command wraps an inner command and transforms its result message.
    # The parent fragment delegates to the child, then intercepts the result and
    # adds its routing prefix. Clean separation. No coupling.
    #
    # Use it to compose child fragments that return their own commands.
    #
    # Prefer the <tt>Command.map</tt> factory method for convenience.
    #
    # === Example
    #
    #   # Using the factory method (recommended)
    #   Command.map(child_command) { |msg| [:sidebar, msg] }
    #
    #   # Using the class directly
    #   Mapped.new(inner_command: child_command, mapper: ->(msg) { [:sidebar, msg] })
    class Mapped < Data.define(:inner_command, :mapper)
      include Custom

      DONE = Object.new.freeze
      private_constant :DONE

      # Grace period delegates to inner command.
      def rooibos_cancellation_grace_period
        inner_command.respond_to?(:rooibos_cancellation_grace_period) ?
          inner_command.rooibos_cancellation_grace_period : 0.1
      end

      # Executes the inner command and transforms each message.
      def call(out, token)
        inner_channel = Concurrent::Promises::Channel.new
        inner_outlet = Outlet.new(inner_channel, lifecycle: out.live)

        Concurrent::Promises.future do
          if inner_command.respond_to?(:call)
            inner_command.call(inner_outlet, token)
          else
            raise ArgumentError, "Inner command must respond to #call"
          end
          inner_channel.push(DONE)
        end

        loop do
          msg = inner_channel.pop
          break if msg.equal?(DONE)
          transformed = mapper.call(msg)
          out.put(*transformed) if transformed
        end
      end
    end

    # Creates a mapped command for Fractal Architecture composition.
    #
    # Wraps an inner command. When the inner command completes, the +mapper+ block
    # transforms the result into a parent message. This prevents monolithic update
    # functions (the "God Reducer" anti-pattern).
    #
    # [inner_command] The child command to wrap.
    # [mapper] Block that transforms child message to parent message.
    #
    # === Example
    #
    #   # Child returns Command.execute that produces [:got_files, {...}]
    #   child_command = Command.system("ls", :got_files)
    #
    #   # Parent wraps to route as [:sidebar, :got_files, {...}]
    #   parent_command = Command.map(child_command) { |child_result| [:sidebar, *child_result] }
    def self.map(inner_command, mapper = nil, &block)
      if mapper && block
        raise ArgumentError, "Pass either a mapper callable or a block, not both"
      end
      unless mapper || block
        raise ArgumentError, "Pass a mapper callable or a block"
      end
      Mapped.new(inner_command:, mapper: mapper || block)
    end

    # Gives a callable unique identity for cancellation.
    #
    # Reusable procs and lambdas share identity. Dispatch them twice, and
    # +Command.cancel+ would cancel both. Wrap them to get distinct handles.
    #
    # The callable must be Ractor-shareable (cannot capture mutable state).
    # Create resources like database connections inside the callable, not in
    # the closure. See the Custom Commands guide for details.
    #
    # [callable] Proc, lambda, or any object responding to +call(out, token)+.
    #            If omitted, the block is used.
    # [grace_period] Cleanup time override. Default: 2.0 seconds.
    #
    # === Example
    #
    #   # With callable
    #   cmd = Command.custom(->(out, token) { out.put(:fetched, data) })
    #
    #   # With block
    #   cmd = Command.custom(grace_period: 5.0) do |out, token|
    #       until token.canceled?
    #       out.put(:tick, Time.now)
    #       sleep 1
    #     end
    #   end
    def self.custom(callable = nil, grace_period: nil, &block)
      c = callable || block

      # Debug mode: validate that callable can be made shareable (fail fast)
      if RatatuiRuby::Debug.enabled?
        begin
          c = Ractor.make_shareable(c)
        rescue Ractor::IsolationError
          raise Rooibos::Error::Invariant,
            "Command.custom requires a Ractor-shareable callable. " \
              "#{c.class} is not shareable. Use Ractor.make_shareable or define at top-level."
        end
      end
      # Production mode: skip validation (Ractors not yet used, avoid overhead)

      Wrapped.new(callable: c, grace_period:)
    end

    # Creates a one-shot timer command.
    #
    # Waits for +seconds+ then sends +TimerResponse+ to the update function.
    # Use for delayed actions like notification dismissal or debounced search.
    #
    # [seconds] Duration to wait (Float or Integer).
    # [envelope] Symbol to tag the result message.
    def self.wait(seconds, envelope)
      Wait.new(seconds:, envelope:)
    end

    # Creates a recurring timer command.
    #
    # Identical to +wait+, but semantically used for animation frames where
    # the update function re-dispatches to continue the animation loop.
    #
    # [interval] Duration between ticks (Float or Integer).
    # [tag] Symbol to tag the result message.
    singleton_class.alias_method :tick, :wait

    # Creates a wall-clock time command.
    #
    # Waits for +seconds+ then sends +Message::Clock+ with the current time.
    # Use for displaying time, throttling refreshes, or scheduling.
    #
    # [seconds] Duration to wait (Float or Integer).
    # [envelope] Symbol to tag the result message.
    def self.clock(seconds, envelope)
      Clock.new(seconds:, envelope:)
    end

    # Creates a random value command.
    #
    # Delegates to Ruby's <tt>Random</tt> class through the runtime.
    # The last argument is always the envelope. Everything before it
    # maps to <tt>Random</tt>.
    #
    # Without a leading symbol, calls <tt>Random#rand</tt>.
    # With a leading symbol, calls that method on <tt>Random</tt>.
    #
    # [*args] Arguments to pass to <tt>Random</tt>, followed by the envelope.
    def self.random(*args)
      envelope = args.pop
      Random.new(args: args.freeze, envelope:)
    end

    # Creates a parallel batch command.
    #
    # Applications fetch data from multiple sources. Dashboard panels load
    # users, stats, and notifications. Waiting sequentially is slow.
    # Managing threads and error handling manually is error-prone.
    #
    # This command runs children in parallel. Each child sends its own messages
    # independently. The batch completes when all children finish or when
    # cancellation fires.
    #
    # Use it for parallel fetches, concurrent refreshes, or any work that
    # does not need coordinated results.
    #
    # [commands] One or more commands to run in parallel. Pass multiple
    #   arguments or a single array.
    #
    # === Example
    #
    #   # Variadic syntax
    #   Command.batch(
    #     Command.http(:get, "/users", :users),
    #     Command.http(:get, "/stats", :stats),
    #   )
    #
    #   # Array syntax
    #   Command.batch([cmd1, cmd2, cmd3])
    def self.batch(*)
      Batch.new(*)
    end

    # Creates an aggregating parallel command.
    #
    # Applications load dashboards that combine user, settings, and stats.
    # Fire-and-forget loses correlation. This command waits for all children
    # and returns their results together in a single message.
    #
    # [commands] One or more commands to run in parallel. Pass multiple
    #   arguments or a single array.
    #
    # === Example
    #
    #   # Variadic syntax
    #   Command.all(
    #     Command.http(:get, "/users", :_),
    #     Command.http(:get, "/stats", :_),
    #   )
    #   # Produces: [:all, [user_result, stats_result]]
    def self.all(envelope, *)
      All.new(envelope, *)
    end

    # Creates an HTTP request command.
    # Supports DWIM arity - see Http.new for patterns.
    def self.http(*, **)
      Http.new(*, **)
    end

    # Opens a file or URL with the system's default application.
    # Cross-platform: uses +open+ on macOS, +xdg-open+ on Linux, +start+ on Windows.
    #
    # On success (exit 0), sends +Message::Open+.
    # On failure (non-zero), sends +Message::Error+.
    #
    # === Example
    #
    #   case message
    #   in { type: :open, envelope: path }
    #     model.with(status: "Opened #{path}")
    #   in { type: :error, envelope: path }
    #     model.with(error: "Could not open #{path}")
    #   end
    #
    def self.open(path, envelope = path)
      Open.new(path:, envelope:)
    end

    class Wrapped < Data.define(:callable, :grace_period) # :nodoc:
      include Custom
      def rooibos_cancellation_grace_period
        grace_period || super
      end

      def call(out, token) # :nodoc:
        callable.call(out, token)
      end
    end
    private_constant :Wrapped
  end
end
