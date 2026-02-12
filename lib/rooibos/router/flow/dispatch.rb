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
      module Dispatch
        private def run_all(rules, message, model)
          transition = Transition.initial(model)
          rules.each do |rule|
            config = Configuration.new(message:, model: transition.model)
            new_transition = rule.apply_if_matches(config, routes) or next
            transition = separate_commands(transition, new_transition)
          end
          transition
        end

        private def apply_first_matching(rules, config, transition)
          rules.each do |rule|
            new_transition = rule.apply_if_matches(config, routes) or next
            return separate_commands(transition, new_transition)
          end
          nil
        end

        private def separate_commands(transition, new_transition) = transition
          .with_model(new_transition.model)
          .with_separate_command(new_transition.command)
      end
    end
    private_constant :Flow
  end
end
