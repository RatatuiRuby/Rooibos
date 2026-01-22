# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Message
    # Completion sentinel from Command.batch.
    #
    # Batch commands stream child messages live. When all children finish,
    # this message signals completion. Use it to trigger follow-up actions
    # or UI updates after parallel work completes.
    #
    # === Example
    #
    #   case msg
    #   in Message::Batch
    #     out.put(:all_done)
    #   in [:progress, pct]
    #     model.with(progress: pct)
    #   end
    #
    Batch = Data.define(:command) do
      include Predicates

      # Returns <tt>true</tt> for batch completion messages.
      def batch?
        true
      end

      # Deconstructs for pattern matching.
      def deconstruct_keys(_keys)
        { type: :batch, command: }
      end
    end
  end
end
