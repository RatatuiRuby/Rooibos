# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    class Routes
      include Enumerable

      def initialize(routes = Set.new) = @routes = routes

      def add(route)
        @routes << route
        route
      end

      def for(identifier)
        case identifier
        when Module then unique(identifier) { |r| r.fragment == identifier }
        when Symbol then unique(identifier) { |r| r.prefix == identifier }
        else identifier
        end
      end

      def each(&block)
        return @routes.each unless block
        @routes.each { |route| block.call(route) }
      end

      def subset(targets)
        resolved = targets.filter_map { |t| self.for(t) }
        Routes.new(resolved.to_set)
      end

      def broadcast(message, model)
        reduce(Transition.initial(model)) do |transition, route|
          new_model, command = route.delegate(message, transition.model)
          transition.with_model(new_model).with_added_command(command)
        end
      end

      def broadcast_to(prefixes, message, model)
        subset(prefixes).broadcast(message, model)
      end

      private def unique(identifier, &)
        matches = @routes.select(&)
        raise Rooibos::Error::Invariant, "Ambiguous route: #{identifier} matches #{matches.size} routes. Capture the Route returned by `route` and pass it to `to:` to disambiguate." if matches.size > 1
        matches.first
      end
    end
    private_constant :Routes
  end
end
