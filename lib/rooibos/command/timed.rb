# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Command
    # Shared behavior for commands that wait, then respond.
    #
    # Timer and clock commands follow the same pattern: wait for
    # <tt>seconds</tt>, check for cancellation, then send a response.
    # Duplicating the cancellation dance is error-prone.
    #
    # This module extracts the wait-cancel-respond skeleton. Include
    # it in any <tt>Data.define(:seconds, :envelope)</tt> command and
    # implement <tt>timed_response</tt> to build the success message.
    #
    # === Example
    #
    #   class MyTimer < Data.define(:seconds, :envelope)
    #     include Custom
    #     include Timed
    #
    #     private def timed_response(start_time)
    #       Message::Timer.new(envelope:, elapsed: Time.now - start_time)
    #     end
    #   end
    #
    module Timed # :nodoc:
      # Cooperative cancellation needs no grace period.
      # The command responds instantly to cancellation via
      # <tt>Concurrent::Cancellation.timeout</tt>.
      def rooibos_cancellation_grace_period
        0
      end

      # Waits for <tt>seconds</tt>, then sends the result of
      # <tt>timed_response</tt>. If canceled, sends
      # <tt>Message::Canceled</tt> instead.
      #
      # [out] Outlet for sending messages.
      # [token] Cancellation token from the runtime.
      def call(out, token)
        start_time = Time.now
        timer_cancellation, _origin = Concurrent::Cancellation.timeout(seconds)
        combined = token.join(timer_cancellation)
        combined.origin.wait

        if token.canceled?
          out.put(Message::Canceled.new(command: self))
        else
          out.put(Ractor.make_shareable(timed_response(start_time)))
        end
      end
    end
    private_constant :Timed
  end
end
