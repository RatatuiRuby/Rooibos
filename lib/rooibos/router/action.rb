# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    # Lambda action - calls handler directly with (message, model).
    class LambdaAction < Data.define(:name, :handler)
      def routed? = false

      def apply(message, model, _routes)
        result = handler.arity.zero? ? handler.call : handler.call(message, model)
        Transition.from(result, model)
      end
    end
    private_constant :LambdaAction

    # Routed action - wraps message and delegates through route to fragment.
    class RoutedAction < Data.define(:name, :fragment)
      def routed? = true

      def apply(message, model, routes)
        route = routes.find { |r| r.fragment == fragment }
        raise ArgumentError, "No route found for fragment #{fragment}" unless route
        routed_message = Message::Routed.new(envelope: name, event: message)
        route.delegate(routed_message, model)
      end
    end
    private_constant :RoutedAction
  end
end
