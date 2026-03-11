# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Command
    # A one-shot clock command.
    #
    # Applications display the time, throttle refreshes, and show
    # "last updated 30 seconds ago." All of these call <tt>Time.now</tt>.
    # But <tt>Time.now</tt> in Update is a side effect. The same model
    # and message produce different results depending on when you call
    # them. Testing becomes non-deterministic.
    #
    # This command waits, then sends a <tt>Message::Clock</tt> with the
    # current time. It responds to cancellation cooperatively. When
    # canceled, it sends <tt>Message::Canceled</tt> so you know the
    # clock stopped.
    #
    # Use it for periodic time updates, scheduling, or any feature that
    # asks "what time is it?"
    #
    # Prefer the <tt>Command.clock</tt> factory method for convenience.
    #
    # === Example: Periodic refresh
    #
    #   def update(msg, model)
    #     case msg
    #     in { type: :clock, envelope: :refresh, time: }
    #       [model.with(current_time: time.utc.to_s),
    #        Command.clock(1, :refresh)]
    #     end
    #   end
    #
    # === Example: "Last updated" display
    #
    #   def update(msg, model)
    #     case msg
    #     in { type: :clock, envelope: :clock, time: }
    #       ago = (time - model.last_fetch).round
    #       [model.with(status: "Updated #{ago}s ago"),
    #        Command.clock(1, :clock)]
    #     end
    #   end
    class Clock < Data.define(:seconds, :envelope)
      include Custom
      include Timed

      private def timed_response(_start_time)
        Message::Clock.new(envelope:, time: Time.now)
      end
    end
  end
end
