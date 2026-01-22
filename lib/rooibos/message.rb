# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  # Messages sent from commands to update functions.
  #
  # All built-in response types live here. Each includes the +Predicates+
  # mixin for safe predicate calls.
  module Message
    # Fallback predicate mixin.
    #
    # Returns +false+ for any unknown predicate method (ending in +?+).
    # Include in custom message types for safe predicate calls.
    module Predicates
      # Returns +false+ for unknown predicate methods.
      def method_missing(name, *args, **kwargs, &block)
        return false if name.to_s.end_with?("?") && args.empty? && kwargs.empty?

        super
      end

      # Responds to all predicate methods.
      def respond_to_missing?(name, *)
        name.to_s.end_with?("?")
      end
    end
  end
end

require_relative "message/timer"
require_relative "message/http_response"
require_relative "message/system/batch"
require_relative "message/system/stream"
require_relative "message/all"
require_relative "message/batch"
