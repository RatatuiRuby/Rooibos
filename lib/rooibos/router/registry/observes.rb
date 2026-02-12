# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    # Collection of observe rules.
    class Observes < Data.define(:rules, :actions)
      include Registry

      def initialize(rules: [], actions:)
        super
      end

      def add_events(keys, handler, **guard_opts) = add(Observe.new(
        predicate: Predicate::Events.new(keys:),
        action: resolve(handler),
        guard: Guard.from(**guard_opts)
      ))

      def add_routed(envelope, handler, guard: nil) = add(Observe.new(
        predicate: Predicate::Routed.new(envelope:),
        action: resolve(handler),
        guard: Guard.from(guard:)
      ))

      def add_instances_of(klass, handler, guard: nil) = add(Observe.new(
        predicate: Predicate::InstancesOf.new(klass:),
        action: resolve(handler),
        guard: Guard.from(guard:)
      ))

      def add_all(handler, **guard_opts) = add(Observe.new(
        predicate: Predicate::Always.new,
        action: resolve(handler),
        guard: Guard.from(**guard_opts)
      ))

      def add_custom(predicate, handler, **guard_opts) = add(Observe.new(
        predicate:,
        action: resolve(handler),
        guard: Guard.from(**guard_opts)
      ))

      private def resolve(handler)
        return actions[handler] if handler.is_a?(Symbol)
        LambdaAction.new(name: nil, handler:)
      end
    end
    private_constant :Observes
  end
end
