# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module RatatuiRuby
  module Tea
    module Command
      # Executes commands with thread tracking and force-termination.
      #
      # Commands run in threads. Some ignore cancellation. They block forever,
      # orphan resources, or hang the terminal. Manual thread tracking is tedious
      # and error-prone.
      #
      # This class manages command threads. It races results against cancellation.
      # After a grace period, it kills misbehaving threads. The runtime and
      # <tt>Outlet#source</tt> share one instance for unified behavior.
      #
      # Use it indirectly — the framework creates and injects it automatically.
      class Lifecycle
        # :nodoc: Internal representation of a tracked async command.
        Entry = Data.define(:future, :origin)

        # Creates a lifecycle manager.
        #
        # The runtime creates one at startup. All outlets share it. Child commands
        # from <tt>Outlet#source</tt> inherit the same lifecycle for consistent
        # thread management.
        def initialize
          @active = Concurrent::Map.new
        end

        # Runs a command synchronously, returning its result.
        #
        # Spawns a thread, races the result against cancellation and timeout.
        # On cancellation, waits the grace period then kills the thread if needed.
        #
        # [command] Callable with <tt>call(out, token)</tt>.
        # [token]   Parent's cancellation token.
        # [timeout] Max wait seconds for the result.
        #
        # Returns the child's message, or <tt>nil</tt> if cancelled or timed out.
        # Raises if the child raised.
        def run_sync(command, token, timeout:)
          return nil if token.canceled?

          child_channel = Concurrent::Promises::Channel.new
          child_outlet = Outlet.new(child_channel, lifecycle: self)

          exception = nil
          thread = Thread.new do
            command.call(child_outlet, token)
          rescue => e
            exception = e
          end

          # Race: pop result vs cancellation vs timeout
          pop_future = Concurrent::Promises.future { child_channel.pop(timeout, :timeout) }
          Concurrent::Promises.any_event(pop_future, token.origin).wait

          if token.canceled?
            # Get grace period from command if available
            grace = command.respond_to?(:tea_cancellation_grace_period) ?
              command.tea_cancellation_grace_period : 0.1

            # Wait for grace period, then force-kill if still running
            thread.join(grace)
            thread.kill if thread.alive?

            return nil
          end

          if exception
            raise exception.is_a?(Exception) ? exception : RuntimeError.new(exception.to_s)
          end

          result = pop_future.value
          return nil if result == :timeout

          result
        end

        # Runs a command asynchronously, tracking it for later cancellation.
        #
        # Spawns a future that executes the command. Tracks the command in the
        # active map for cancellation support. Errors are pushed to the channel
        # as <tt>Command::Error</tt> messages.
        #
        # [command] Callable with <tt>call(out, token)</tt>.
        # [channel] Channel to push results and errors to.
        #
        # Returns a hash with <tt>:future</tt> and <tt>:origin</tt> for tracking.
        def run_async(command, channel)
          cancellation, origin = Concurrent::Cancellation.new
          outlet = Outlet.new(channel, lifecycle: self)

          future = Concurrent::Promises.future do
            command.call(outlet, cancellation)
          rescue => e
            channel.push Command::Error.new(command:, exception: e)
          end

          entry = Entry.new(future:, origin:)
          @active[command] = entry
          entry
        end

        # Cancels a running command, waiting for its grace period.
        #
        # Signals cancellation, waits for the command's grace period, then
        # removes it from tracking. Does nothing if the command isn't tracked.
        #
        # [command] The command to cancel (must be the same object passed to run_async).
        def cancel(command)
          entry = @active[command]
          return unless entry&.future&.pending?

          entry.origin.resolve # Signal cancellation

          grace = command.respond_to?(:tea_cancellation_grace_period) ?
            command.tea_cancellation_grace_period : 0.1
          entry.future.wait(grace.finite? ? grace : nil)

          @active.delete(command)
        end

        # Cancels all active commands and waits for them to complete.
        #
        # Iterates through all tracked commands, signals cancellation, and waits
        # for each command's grace period. Called at runtime shutdown.
        def shutdown
          @active.each do |command, entry|
            entry.origin.resolve # Signal cancellation

            grace = command.respond_to?(:tea_cancellation_grace_period) ?
              command.tea_cancellation_grace_period : 0.1
            entry.future.wait(grace.finite? ? grace : nil)
          end
        end
      end
    end
  end
end
