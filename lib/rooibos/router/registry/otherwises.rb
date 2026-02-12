# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    # Collection of otherwise rules.
    class Otherwises < Data.define(:rules)
      include Registry

      def initialize(rules: [])
        super
      end

      def add(route_to:, **guard_opts)
        super(Otherwise.new(
          target: route_to,
          guard: Guard.from(**guard_opts)
        ))
      end
    end
    private_constant :Otherwises
  end
end
