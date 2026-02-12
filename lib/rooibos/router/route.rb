# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    Route = Data.define(:prefix, :fragment, :read, :write) do
      def initialize(prefix:, fragment:, read: nil, write: nil)
        super
      end

      def delegate(message, model)
        nested_model = extract(model)
        result = fragment::Update.call(message, nested_model)
        transition = Transition.from(result, nested_model)
        Transition.new(model: merge(model, transition.model), command: transition.command)
      end

      private def extract(model)
        if read
          read.call(model)
        else
          model.public_send(prefix)
        end
      end

      private def merge(model, new_nested_model)
        if write
          write.call(model, new_nested_model)
        else
          model.with(prefix => new_nested_model)
        end
      end
    end
    private_constant :Route
  end
end
