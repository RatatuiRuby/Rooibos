# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Message
    # Response from a clock command.
    #
    # Long-lived applications display the time. Dashboards show "last updated
    # 30 seconds ago." Schedulers fire actions at specific hours. All of these
    # need wall-clock time. But calling <tt>Time.now</tt> in Update is a side
    # effect—the same model and message produce different results depending
    # on when you call them.
    #
    # This response carries the wall-clock time from the runtime. Update
    # pattern-matches on the envelope to distinguish multiple clocks.
    #
    # Use it to handle <tt>Command.clock</tt> completions.
    #
    # === Example
    #
    #   case msg
    #   in { type: :clock, envelope: :refresh, time: }
    #     [model.with(last_refresh: time), Command.clock(1, :refresh)]
    #   in { type: :clock, envelope: :display, time: }
    #     model.with(current_time: time.utc.to_s)
    #   end
    #
    class Clock < Data.define(:envelope, :time)
      include Predicates
      # Returns <tt>true</tt> for clock responses.
      def clock?
        true
      end
    end
  end
end
