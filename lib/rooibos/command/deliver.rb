# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Command
    # Delivers a message to Update.
    #
    # Sometimes you have data ready now. A synchronous calculation. A value from
    # the model. You want Update to process it as a message — pattern match on it,
    # use predicates, the whole workflow.
    #
    # This command wraps any message and delivers it to Update via the runtime.
    #
    # Use it to send structured messages from Update, or to produce messages
    # from synchronous operations.
    #
    # === Example
    #
    # Define a message type:
    #   class CacheLoaded < Data.define(:envelope, :data)
    #     include Rooibos::Message::Predicates
    #   end
    #
    # Send from Update:
    #   in { type: :key, code: "f" }
    #     cache = load_yaml_cache("auth")
    #     Command.deliver(CacheLoaded.new(envelope: :auth, data: cache))
    #
    # Receive in Update:
    #   in { type: :cache_loaded, envelope: :auth, data: }
    #     model.with(auth: data)
    #
    # Or use predicates:
    #   elsif message.cache_loaded? and message.auth
    #     model.with(auth: message.data)
    #
    class Deliver < Data.define(:message)
      include Custom

      # Sends the message to the runtime.
      def call(out, _token)
        out.put(message)
      end
    end
  end
end
