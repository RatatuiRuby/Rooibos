# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Message
    # Signals that a file or URL was successfully opened.
    #
    # This message arrives after +Command.open+ completes with exit status 0.
    # Non-zero exits produce +Message::Error+ instead.
    #
    # === Pattern Matching
    #
    #   case message
    #   in { type: :open, envelope: path }
    #     model.with(status: "Opened #{path}")
    #   end
    #
    class Open < Data.define(:envelope)
      include Predicates

      def deconstruct_keys(_keys)
        { type: :open, envelope: }
      end
    end
  end
end
