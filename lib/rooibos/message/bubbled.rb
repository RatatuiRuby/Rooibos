# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Message
    # Message synthesized by Router when a child fragment bubbles.
    #
    # When a child fragment returns <tt>Command.bubble(message)</tt>, the Router
    # wraps the inner message in Bubbled and dispatches it through the
    # outward flow (observe, then intercept).
    #
    # [message] The inner message that was bubbled.
    Bubbled = Data.define(:message) do
      include Predicates

      def deconstruct_keys(_keys)
        { type: :bubbled, message: }
      end

      def bubbled?
        true
      end
    end
  end
end
