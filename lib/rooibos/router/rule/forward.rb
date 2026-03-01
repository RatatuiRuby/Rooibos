# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    # Forward rule - matches messages and delegates to route(s)
    class Forward < Data.define(:predicate, :targets, :envelope, :guard)
      include Rule

      def initialize(predicate:, targets: ALL_ROUTES, envelope: nil, guard: nil)
        targets = Array(targets) unless targets == ALL_ROUTES
        super
      end

      def apply(message, model, routes)
        if targets == ALL_ROUTES
          routes
        else
          routes.subset(targets)
        end.broadcast(envelop(message), model)
      end

      private def envelop(message)
        if envelope
          event = message.is_a?(Message::Routed) ? message.event : message
          Message::Routed.new(envelope:, event:)
        else
          message
        end
      end
    end
    private_constant :Forward
  end
end
