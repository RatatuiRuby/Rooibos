# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    # Common behavior for routing rules.
    module Rule
      def matches?(config) = predicate_matches?(config) && guard_passes?(config)

      def apply_if_matches(config, *)
        if matches?(config)
          apply(config.message, config.model, *)
        end
      end

      private def predicate_matches?(config)
        if predicate.arity.zero?
          predicate.call
        else
          predicate.call(config.message, config.model)
        end
      end

      private def guard_passes?(config)
        if guard
          !!guard.call(config.message, config.model)
        else
          true
        end
      end
    end
    private_constant :Rule
  end
end
