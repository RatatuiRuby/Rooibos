# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Message
    module System
      # Streaming message from a system command.
      #
      # Streaming commands send incremental output instead of batching. Each line
      # is a separate message, followed by a completion message.
      #
      # This message includes predicates to distinguish stdout, stderr, and
      # completion events for pattern matching workflows.
      #
      # Use it to handle <tt>Command.system(..., stream: true)</tt> output.
      #
      # === Example
      #
      #   case msg
      #   in { type: :system_stream, envelope: :build, stream: :stdout, content: }
      #     model.with(log: model[:log] + content)
      #   in { type: :system_stream, envelope: :build, stream: :complete, status: 0 }
      #     model.with(success: true)
      #   end
      #
      Stream = Data.define(:envelope, :stream, :content, :status) do
        include Predicates

        # Returns <tt>true</tt> for system stream messages.
        def system?
          true
        end

        # Returns <tt>true</tt> for stdout messages.
        def stdout?
          stream == :stdout
        end

        # Returns <tt>true</tt> for stderr messages.
        def stderr?
          stream == :stderr
        end

        # Returns <tt>true</tt> for complete messages.
        def complete?
          stream == :complete
        end

        # Deconstructs for pattern matching.
        #
        # Returns a hash with <tt>:type</tt>, <tt>:envelope</tt>, <tt>:stream</tt>,
        # and either <tt>:content</tt> (for stdout/stderr) or <tt>:status</tt> (for complete).
        def deconstruct_keys(_keys)
          if complete?
            { type: :system_stream, envelope:, stream:, status: }
          else
            { type: :system_stream, envelope:, stream:, content: }
          end
        end
      end
    end
  end
end
