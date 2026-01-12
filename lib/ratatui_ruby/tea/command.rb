# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "concurrent-edge"
require_relative "command/custom"
require_relative "command/outlet"
require_relative "command/wait"
require_relative "command/batch"

module RatatuiRuby
  module Tea
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
      # Sentinel value for application termination.
      #
      # The runtime detects this before dispatching. It breaks the loop immediately.
      Exit = Data.define

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

      # Creates a fresh cancellation that never fires.
      #
      # Some I/O operations cannot be cancelled mid-execution. Ruby's <tt>Net::HTTP</tt>
      # blocks until completion or timeout — there is no way to interrupt it.
      #
      # A shared singleton would be unsafe. If any code path accidentally resolves
      # the origin, all commands using it become cancelled.
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

      # Sentinel value for command cancellation.
      #
      # Long-running commands (WebSocket listeners, database pollers) run until stopped.
      # Stopping them requires signaling from outside the command. The runtime tracks
      # active commands by their object identity and routes cancel requests.
      #
      # This type carries the handle (command object) to cancel. The runtime pattern-matches
      # on <tt>Command::Cancel</tt> and signals the token.
      Cancel = Data.define(:handle)

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

      # Sentinel value for command errors.
      #
      # Commands run in threads. Exceptions bubble up silently. The update function
      # never sees them, and backtraces in STDERR corrupt the TUI display.
      #
      # The runtime catches exceptions and pushes <tt>Error</tt> to the queue.
      # Pattern match on it in your update function.
      #
      # Analogous to <tt>Exit</tt> and <tt>Cancel</tt>.
      Error = Data.define(:command, :exception)

      # Creates an error sentinel.
      #
      # The runtime produces this automatically when a command raises.
      # Use this factory for testing or for commands that want to signal
      # error completion without raising.
      #
      # [command] The command that failed.
      # [exception] The exception that was raised.
      #
      # === Example
      #
      #   def update(message, model)
      #     case message
      #     in Command::Error(command:, exception:)
      #       model.with(error: "#{command.class} failed: #{exception.message}")
      #     end
      #   end
      def self.error(command, exception)
        Error.new(command:, exception:)
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
      # === Batch Mode (default)
      #
      # A single message arrives when the command finishes:
      # <tt>[tag, {stdout:, stderr:, status:}]</tt>
      #
      # === Streaming Mode
      #
      # Messages arrive incrementally:
      # - <tt>[tag, :stdout, line]</tt> for each stdout line
      # - <tt>[tag, :stderr, line]</tt> for each stderr line
      # - <tt>[tag, :complete, {status:}]</tt> when the command finishes
      # - <tt>[tag, :error, {message:}]</tt> if the command cannot start
      #
      # The <tt>status</tt> is the integer exit code (0 = success).
      System = Data.define(:command, :tag, :stream) do
        # Command identification — runtime uses this to dispatch as a command.
        def tea_command?
          true
        end

        # Grace period for cleanup after cancellation.
        def tea_cancellation_grace_period
          0.1
        end

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
          out.put(tag, Ractor.make_shareable({ stdout:, stderr:, status: status.exitstatus }))
        end

        private def stream_execution(out, token)
          Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
            stdin.close
            pid = wait_thr.pid

            stdout_thread = Thread.new do
              stdout.each_line { |line| out.put(tag, :stdout, line.freeze) }
            rescue IOError
              # Stream closed - SIGKILL the child if still alive (forcible cleanup)
              begin
                Process.kill("KILL", pid) if wait_thr.alive?
              rescue Errno::ESRCH
                # Already dead
              end
            end
            stderr_thread = Thread.new do
              stderr.each_line { |line| out.put(tag, :stderr, line.freeze) }
            rescue IOError
              # Stream closed
            end

            # Cooperative cancellation: SIGTERM when token is cancelled
            cancellation_watcher = Thread.new do
              sleep 0.01 until token.canceled? || !wait_thr.alive?
              if token.canceled? && wait_thr.alive?
                begin
                  Process.kill("TERM", pid)
                rescue Errno::ESRCH
                  # Already dead
                end
              end
            end

            wait_thr.join

            # Child exited; clean up threads
            stdout_thread.kill
            stderr_thread.kill
            cancellation_watcher.kill

            status = wait_thr.value.exitstatus
            out.put(tag, :complete, Ractor.make_shareable({ status: }))
          end
        rescue Errno::ENOENT, Errno::EACCES => e
          out.put(tag, :error, Ractor.make_shareable({ message: e.message }))
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
      #     in [:got_files, {stdout:, status: 0}]
      #       [model.with(files: stdout.lines), nil]
      #     in [:got_files, {stderr:, status:}]
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
      #     in [:log, :stdout, line]
      #       [model.with(lines: [*model.lines, line]), nil]
      #     in [:log, :stderr, line]
      #       [model.with(errors: [*model.errors, line]), nil]
      #     in [:log, :complete, {status:}]
      #       [model.with(loading: false, exit_status: status), nil]
      #     in [:log, :error, {message:}]
      #       [model.with(loading: false, error: message), nil]
      #     end
      #   end
      def self.system(command, tag, stream: false)
        System.new(command:, tag:, stream:)
      end

      # Wraps another command's result with a transformation.
      #
      # Fractal Architecture requires composition. Child bags produce commands
      # with their own tags. Parent bags need those results routed back with
      # a parent prefix. Without transformation, update functions become
      # monolithic "God Reducers" that know about every child's internals.
      #
      # This command wraps an inner command and transforms its result message.
      # The parent bag delegates to the child, then intercepts the result and
      # adds its routing prefix. Clean separation. No coupling.
      #
      # Use it to compose child bags that return their own commands.
      Mapped = Data.define(:inner_command, :mapper) do
        # Command identification for runtime dispatch.
        def tea_command?
          true
        end

        # Grace period delegates to inner command.
        def tea_cancellation_grace_period
          inner_command.respond_to?(:tea_cancellation_grace_period) ?
            inner_command.tea_cancellation_grace_period : 0.1
        end

        # Executes the inner command, waits for result, and transforms it.
        def call(out, token)
          inner_channel = Concurrent::Promises::Channel.new
          inner_outlet = Outlet.new(inner_channel)

          # Dispatch inner command
          if inner_command.respond_to?(:call)
            inner_command.call(inner_outlet, token)
          else
            raise ArgumentError, "Inner command must respond to #call"
          end

          # Transform result and send
          inner_message = inner_channel.pop
          transformed = mapper.call(inner_message)
          out.put(*transformed)
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
      def self.map(inner_command, &mapper)
        Mapped.new(inner_command:, mapper:)
      end

      # Gives a callable unique identity for cancellation.
      #
      # Reusable procs and lambdas share identity. Dispatch them twice, and
      # +Command.cancel+ would cancel both. Wrap them to get distinct handles.
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
        Wrapped.new(callable: callable || block, grace_period:)
      end

      # Creates a one-shot timer command.
      #
      # Waits for +seconds+ then sends +[tag, seconds]+ to the update function.
      # Use for delayed actions like notification dismissal or debounced search.
      #
      # [seconds] Duration to wait (Float or Integer).
      # [tag] Symbol to tag the result message.
      def self.wait(seconds, tag)
        Wait.new(seconds:, tag:)
      end

      # Creates a recurring timer command.
      #
      # Identical to +wait+, but semantically used for animation frames where
      # the update function re-dispatches to continue the animation loop.
      #
      # [interval] Duration between ticks (Float or Integer).
      # [tag] Symbol to tag the result message.
      singleton_class.alias_method :tick, :wait

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

      # :nodoc:
      Wrapped = Data.define(:callable, :grace_period) do
        include Custom
        def tea_cancellation_grace_period = grace_period || super
        def call(out, token) = callable.call(out, token)
      end
      private_constant :Wrapped
    end
  end
end
