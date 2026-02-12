# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    # Collection of named actions.
    class Actions < Data.define(:rules)
      include Enumerable

      def initialize(rules: [])
        super
      end

      def add(name, handler)
        action = if handler.is_a?(Module)
          RoutedAction.new(name: name.to_sym, fragment: handler)
        else
          LambdaAction.new(name: name.to_sym, handler:)
        end
        rules << action
      end

      def [](name)
        find { |action| action.name == name.to_sym } or
          raise ArgumentError, "Unknown action: #{name}"
      end

      def each(&block)
        return rules.each unless block
        rules.each { |action| block.call(action) }
      end
    end
    private_constant :Actions
  end
end
