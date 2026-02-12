# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    module Flow
      # Outward flow: messages traveling toward the root.
      #
      # Observe → intercept.
      class Outward < Data.define(:observes, :receives, :routes)
        include Dispatch

        # Sentinel: intercept consumed the bubble. Non-nil so
        # Transition#with_command replaces the original Command::Bubble
        # instead of preserving it via the nil no-op.
        INTERCEPTED = Object.new.freeze

        def call(message, model)
          transition = run_all(observes, message, model)
          config = Configuration.new(message:, model: transition.model)
          intercept_first_matching(receives, config, transition) ||
            transition
        end

        private def intercept_first_matching(rules, config, transition)
          rules.each do |rule|
            new_transition = rule.apply_if_matches(config, routes) or next
            return transition
                .with_model(new_transition.model)
                .with_command(new_transition.command || INTERCEPTED)
          end
          nil
        end
      end
    end
    private_constant :Flow
  end
end
