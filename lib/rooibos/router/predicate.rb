# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    module Predicate
      # Matches key events by symbol.
      class Events < Data.define(:keys)
        def initialize(keys:)
          super(keys: Array(keys))
        end

        def arity = 2

        def call(message, _model)
          message.respond_to?(:to_sym) && keys.include?(message.to_sym)
        end
      end

      # Matches routed messages by envelope.
      class Routed < Data.define(:envelope)
        def arity = 2

        def call(message, _model)
          message.is_a?(Message::Routed) && message.envelope == envelope
        end
      end

      # Matches routed messages by any of the given envelopes.
      class RoutedEnvelopes < Data.define(:envelopes)
        def initialize(envelopes:)
          super(envelopes: Array(envelopes))
        end

        def arity = 2

        def call(message, _model)
          message.routed? && envelopes.include?(message.envelope)
        end
      end

      # Matches messages by class.
      class InstancesOf < Data.define(:klass)
        def arity = 2

        def call(message, _model)
          message.is_a?(klass)
        end
      end

      # Matches all messages.
      class Always < Data.define
        def arity = 2
        def call(_message, _model) = true
      end
    end
    private_constant :Predicate
  end
end
