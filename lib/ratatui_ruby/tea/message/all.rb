# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module RatatuiRuby
  module Tea
    module Message
      # Response from Command.all aggregating parallel execution.
      #
      # Running multiple commands in parallel needs aggregated results. Without
      # structured responses, handling mixed success/failure requires manual
      # array parsing.
      #
      # This response collects all child results and provides predicates for
      # success checking. Include Predicates for safe predicate calls.
      #
      # Use it to handle <tt>Command.all</tt> completions.
      #
      # === Example
      #
      #   case msg
      #   in { type: :all, envelope: :parallel, results: }
      #     model.with(outputs: results)
      #   end
      #
      All = Data.define(:envelope, :results, :nested) do
        include Predicates

        # Returns <tt>true</tt> for all responses.
        def all?
          true
        end

        # Deconstructs for pattern matching.
        #
        # Returns a hash with <tt>:type</tt>, <tt>:envelope</tt>, <tt>:results</tt>,
        # and <tt>:nested</tt>.
        def deconstruct_keys(_keys)
          { type: :all, envelope:, results:, nested: }
        end
      end
    end
  end
end
