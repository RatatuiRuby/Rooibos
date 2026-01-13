# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module RatatuiRuby
  module Tea
    module Message
      # Response from an HTTP command.
      #
      # HTTP requests return status codes, bodies, and headers. Errors may occur.
      # Without structured responses, handling success vs. error requires manual
      # checks on raw data.
      #
      # This response includes predicates for common checks and deconstructs for
      # pattern matching. Include Predicates for safe predicate calls on any message.
      #
      # Use it to handle +Command.http+ completions.
      #
      # === Example
      #
      #   case msg
      #   in { type: :http, envelope: :users, status:, body: }
      #     model.with(users: JSON.parse(body))
      #   in { type: :http, envelope: :users, error: }
      #     model.with(error:)
      #   end
      #
      HttpResponse = Data.define(:envelope, :status, :body, :headers, :error) do
        include Predicates

        # Returns +true+ for HTTP responses.
        def http?
          true
        end

        # Returns +true+ if status is 2xx.
        def success?
          status&.between?(200, 299)
        end

        # Returns +true+ if an error occurred.
        def error?
          !!error
        end

        # Deconstructs for pattern matching.
        #
        # Returns a hash with <tt>:type</tt>, <tt>:envelope</tt>, and either
        # <tt>:error</tt> or <tt>:status</tt>, <tt>:body</tt>, <tt>:headers</tt>.
        def deconstruct_keys(_keys)
          if error
            { type: :http, envelope:, error: }
          else
            { type: :http, envelope:, status:, body:, headers: }
          end
        end
      end
    end
  end
end
