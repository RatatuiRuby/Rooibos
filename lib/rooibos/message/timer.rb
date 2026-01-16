# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Message
    # Response from a timer command.
    #
    # Timer commands fire after a delay. Pattern matching in UPDATE distinguishes
    # multiple timers. Without structured responses, timers return bare symbols—hard
    # to extend with elapsed time or other metadata.
    #
    # This response includes the envelope for routing and elapsed time. Include
    # Predicates for safe predicate calls on any message.
    #
    # Use it to handle +Command.wait+ or +Command.tick+ completions.
    #
    # === Example
    #
    #   case msg
    #   in { type: :timer, envelope: :dismiss }
    #     model.with(notification: nil)
    #   in { type: :timer, envelope: :animate, elapsed: }
    #     model.with(frame: next_frame(elapsed))
    #   end
    #
    Timer = Data.define(:envelope, :elapsed) do
      include Predicates

      # Returns +true+ for timer responses.
      def timer?
        true
      end

      # Deconstructs for pattern matching.
      #
      # Returns a hash with <tt>:type</tt>, <tt>:envelope</tt>, and <tt>:elapsed</tt>.
      def deconstruct_keys(_keys)
        { type: :timer, envelope:, elapsed: }
      end
    end
  end
end
