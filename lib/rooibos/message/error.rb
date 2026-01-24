# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Message
    # Error message from a failed command.
    #
    # Commands run in background threads. Exceptions bubble up silently.
    # Your update function never sees them. Backtraces in STDERR corrupt the TUI.
    #
    # The runtime catches exceptions and wraps them in Error messages.
    # Pattern match on Error in your update function. Display the error, log it, or recover.
    #
    # Use it to surface failures from HTTP requests, file I/O, or external processes.
    #
    # === Examples
    #
    #   Update = ->(message, model) {
    #     case message
    #     in { type: :error, command:, exception: }
    #       # Show error toast
    #       model.with(error: exception.message)
    #     in Message::Error
    #       # Store for later inspection
    #       model.with(last_error: message.exception)
    #     end
    #   }
    Error = Data.define(:command, :exception) do
      include Predicates

      # Returns <tt>true</tt> for error messages.
      def error?
        true
      end

      # Deconstructs for pattern matching.
      #
      # Returns a hash with <tt>type</tt>, <tt>command</tt>, and <tt>exception</tt>.
      def deconstruct_keys(_keys)
        { type: :error, command:, exception: }
      end
    end
  end
end
