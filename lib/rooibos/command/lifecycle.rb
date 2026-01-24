# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Command
    # Coordinates command execution across the runtime.
    #
    # Commands run off the main thread. Both the runtime and nested commands
    # via <tt>Outlet#source</tt> share cancellation tokens. Racing results
    # against cancellation is repetitive. Tracking active commands is tedious.
    #
    # This class centralizes that logic. It races results against cancellation
    # and timeout. Commands that ignore cancellation are orphaned until
    # process exit. Cooperative cancellation is the only way to exit cleanly.
    #
    # The framework creates one instance at startup. All outlets share it.
    class Lifecycle
      Entry = Data.define(:future, :origin) # :nodoc: Internal representation of a tracked async command.

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
        Concurrent::Promises.future do
          command.call(child_outlet, token)
        rescue => e
          exception = e
        end

        # Race: pop result vs cancellation vs timeout
        pop_future = Concurrent::Promises.future { child_channel.pop(timeout, :timeout) }
        Concurrent::Promises.any_event(pop_future, token.origin).wait

        # Cooperative cancellation only — misbehaving commands are orphaned
        return nil if token.canceled?

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
      # as <tt>Message::Error</tt> messages.
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
          channel.push Message::Error.new(command:, exception: e)
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

        grace = command.respond_to?(:rooibos_cancellation_grace_period) ?
          command.rooibos_cancellation_grace_period : 0.1
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

          grace = command.respond_to?(:rooibos_cancellation_grace_period) ?
            command.rooibos_cancellation_grace_period : 0.1
          entry.future.wait(grace.finite? ? grace : nil)
        end
      end
    end
  end
end
