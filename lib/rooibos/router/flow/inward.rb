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
      # Inward flow: messages traveling toward the leaves.
      #
      # Observe → receive → forward → otherwise.
      class Inward < Data.define(:observes, :receives, :forwards, :otherwises, :routes)
        include Dispatch

        def initialize(observes:, receives:, forwards:, otherwises:, routes:)
          super
          validate_routes!
        end

        def call(message, model)
          transition = run_all(observes, message, model)
          config = Configuration.new(message:, model: transition.model)
          apply_first_matching(receives, config, transition) ||
            apply_first_matching(forwards, config, transition) ||
            apply_first_matching(otherwises, config, transition) ||
            transition
        end

        private def validate_routes!
          forwards.each { |fwd| Array(fwd.targets).each { |t| routes.for(t) } unless fwd.targets == ALL_ROUTES }
          otherwises.each { |ow| routes.for(ow.target) }
        end
      end
    end
    private_constant :Flow
  end
end
