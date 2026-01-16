# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Message
    # System command response types.
    #
    # Contains message types for system command results.
    module System
      # Response from a system command (batch mode).
      #
      # Shell commands capture output and status. Without structured responses,
      # handling success vs error requires manual parsing of arrays.
      #
      # This response includes predicates for common checks and deconstructs for
      # pattern matching. Include Predicates for safe predicate calls.
      #
      # Use it to handle <tt>Command.system</tt> completions (batch mode).
      #
      # === Example
      #
      #   case msg
      #   in { type: :system, envelope: :build, status: 0, stdout: }
      #     model.with(output: stdout)
      #   in { type: :system, envelope: :build, status: }
      #     model.with(error: "Build failed with exit #{status}")
      #   end
      #
      Batch = Data.define(:envelope, :stdout, :stderr, :status) do
        include Predicates

        # Returns <tt>true</tt> for system responses.
        def system?
          true
        end

        # Returns <tt>true</tt> if status is 0.
        def success?
          status == 0
        end

        # Returns <tt>true</tt> if status is non-zero.
        def error?
          status != 0
        end

        # Deconstructs for pattern matching.
        #
        # Returns a hash with <tt>:type</tt>, <tt>:envelope</tt>, <tt>:stdout</tt>,
        # <tt>:stderr</tt>, and <tt>:status</tt>.
        def deconstruct_keys(_keys)
          { type: :system, envelope:, stdout:, stderr:, status: }
        end
      end
    end
  end
end
