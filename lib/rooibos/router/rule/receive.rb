# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    # Receive rule - matches messages and delegates to action.
    class Receive < Data.define(:predicate, :action, :guard)
      include Rule

      def apply(message, model, routes)
        action.apply(message, model, routes)
      end
    end
    private_constant :Receive
  end
end
