# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Message
    # Cancellation notification from a canceled command.
    #
    # Long-running commands respond to cancellation cooperatively. When the
    # runtime signals cancellation, the command finishes current work and sends
    # this message.
    #
    # Pattern match on Canceled in your update function to clean up state,
    # stop animations, or acknowledge the cancellation.
    #
    # Use it to handle timer cancellations, aborted HTTP requests, or
    # stopped background processes.
    #
    # === Example
    #
    #   Update = ->(message, model) {
    #     case message
    #     in { type: :canceled, command: }
    #       # Timer was canceled, clear the notification
    #       model.with(notification: nil)
    #     in Message::Canceled
    #       # Generic cancellation handling
    #       model
    #     end
    #   }
    Canceled = Data.define(:command) do
      include Predicates

      # Returns <tt>true</tt> for cancellation messages.
      def canceled?
        true
      end
      alias_method :cancelled?, :canceled?

      # Deconstructs for pattern matching.
      #
      # Returns a hash with <tt>type</tt> and <tt>command</tt>.
      def deconstruct_keys(_keys)
        { type: :canceled, command: }
      end
    end
  end
end
