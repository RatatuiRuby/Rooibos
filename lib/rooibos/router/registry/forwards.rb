# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    # Collection of forwards
    class Forwards < Data.define(:rules)
      include Registry

      def initialize(rules: [])
        super
      end

      def add_instances_of(klass, to: nil, as: nil, broadcast: false, broadcast_to: nil) = add(Forward.new(
        predicate: Predicate::InstancesOf.new(klass:),
        targets: resolve_targets(to:, broadcast:, broadcast_to:),
        envelope: as
      ))

      def add_events(keys, to:, as: nil, guard: nil, when: nil, unless: nil) = add(Forward.new(
        predicate: Predicate::Events.new(keys:),
        targets: to,
        envelope: as,
        guard: Guard.from(guard:, when: binding.local_variable_get(:when), unless: binding.local_variable_get(:unless))
      ))

      def add_routed(envelopes, to:, as: nil) = add(Forward.new(
        predicate: Predicate::RoutedEnvelopes.new(envelopes:),
        targets: to,
        envelope: as
      ))

      def add_custom(predicate, to:, as: nil, **guard_opts) = add(Forward.new(
        predicate:,
        targets: to,
        envelope: as,
        guard: Guard.from(**guard_opts)
      ))

      private def resolve_targets(to:, broadcast:, broadcast_to:)
        if broadcast
          ALL_ROUTES
        elsif broadcast_to
          broadcast_to
        else
          to
        end
      end
    end
    private_constant :Forwards
  end
end
