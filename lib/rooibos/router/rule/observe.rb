# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    # Observe rule - matches messages, handles, and continues processing.
    class Observe < Data.define(:predicate, :action, :guard)
      include Rule

      def apply(message, model, routes)
        action.apply(message, model, routes)
      end
    end
    private_constant :Observe
  end
end
