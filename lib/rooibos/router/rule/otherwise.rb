# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    # Rule for otherwise routing - routes unhandled messages to a fragment.
    Otherwise = Data.define(:target, :guard, :predicate) do
      include Rule

      def initialize(target:, guard: nil, predicate: Predicate::Always.new)
        super
      end

      def apply(message, model, routes)
        routes.subset([target]).broadcast(message, model)
      end
    end
    private_constant :Otherwise
  end
end
