# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    # Normalizes guard options into a callable.
    class Guard < Data.define(:callable)
      @scope = []

      def self.scoped(callable)
        @scope.push(callable)
        yield
      ensure
        @scope.pop
      end

      def self.from(guard: nil, when: nil, unless: nil, if: nil, only: nil, except: nil, skip: nil)
        when_guard = binding.local_variable_get(:when) ||
          binding.local_variable_get(:if) ||
          binding.local_variable_get(:only)
        unless_guard = binding.local_variable_get(:unless) ||
          binding.local_variable_get(:except) ||
          binding.local_variable_get(:skip)
        normalized = guard || when_guard
        normalized = -> (msg, model) { !unless_guard.call(msg, model) } if unless_guard
        new(callable: apply_scope(normalized))
      end

      # Combines two guards into a single callable without creating a closure.
      class CombinedGuard < Data.define(:inner, :outer)
        def arity = 2
        def call(msg, model) = inner.call(msg, model) && outer.call(msg, model)
      end

      private_class_method def self.apply_scope(callable)
        @scope.inject(callable) do |inner, outer|
          if inner
            CombinedGuard.new(inner:, outer:)
          else
            outer
          end
        end
      end

      def arity
        callable&.arity || 2
      end

      def call(message, model)
        return true unless callable
        callable.arity.zero? ? callable.call : callable.call(message, model)
      end
    end
    private_constant :Guard
  end
end
