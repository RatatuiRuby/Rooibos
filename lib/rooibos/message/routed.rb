# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Message
    # Message synthesized by Router when keymap uses symbol + route.
    #
    # When a keymap entry uses a symbol instead of a handler, and specifies
    # a route, the Router creates this message and dispatches it to the
    # child fragment's UPDATE.
    #
    # === Example
    #
    #   # In parent keymap:
    #   key :down, :move_down, route: :file_list
    #
    #   # Router synthesizes:
    #   Routed.new(envelope: :move_down, event: key_event)
    #
    #   # Child UPDATE matches:
    #   in { type: :routed, envelope: :move_down }
    #     handle_move_down(model)
    Routed = Data.define(:envelope, :event) do
      include Predicates

      def deconstruct_keys(_keys)
        { type: :routed, envelope:, event: }
      end

      def routed?
        true
      end

      def respond_to_missing?(method_name, include_private = false)
        method_name.end_with?("?") || super
      end

      def method_missing(method_name, *args, &block)
        if method_name.end_with?("?")
          method_name.to_s.chomp("?") == envelope.to_s
        else
          super
        end
      end
    end
  end
end
