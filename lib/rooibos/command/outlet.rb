# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "ratatui_ruby"

module Rooibos
  module Command
    # Messaging gateway for custom commands.
    #
    # Custom commands run in background threads. They produce results that the
    # main loop consumes.
    #
    # Managing queues and message formats manually is tedious. It scatters queue
    # logic across your codebase and makes mistakes easy.
    #
    # This class wraps the queue with a clean API. Call +put+ to send tagged
    # messages. Debug mode validates Ractor-shareability.
    #
    # Use it to send results from HTTP requests, WebSocket streams, or database polls.
    #
    # === Example (One-Shot)
    #
    # Commands run in their own thread. Blocking calls work fine:
    #
    #--
    # SPDX-SnippetBegin
    # SPDX-FileCopyrightText: 2026 Kerrick Long
    # SPDX-License-Identifier: MIT-0
    #++
    #   class FetchUserCommand
    #     include Rooibos::Command::Custom
    #
    #     def initialize(user_id)
    #       @user_id = user_id
    #     end
    #
    #     def call(out, _token)
    #       response = Net::HTTP.get(URI("https://api.example.com/users/#{@user_id}"))
    #       user = JSON.parse(response)
    #       out.put(:user_fetched, Ractor.make_shareable(user: user))
    #     rescue => e
    #       out.put(:user_fetch_failed, error: e.message.freeze)
    #     end
    #   end
    #--
    # SPDX-SnippetEnd
    #++
    #
    # === Example (Long-Running)
    #
    # Commands that loop check the cancellation token:
    #
    #--
    # SPDX-SnippetBegin
    # SPDX-FileCopyrightText: 2026 Kerrick Long
    # SPDX-License-Identifier: MIT-0
    #++
    #   class PollerCommand
    #     include Rooibos::Command::Custom
    #
    #     def call(out, token)
    #       until token.canceled?
    #         data = fetch_batch
    #         out.put(:batch, Ractor.make_shareable(data))
    #         sleep 5
    #       end
    #       out.put(:poller_stopped)
    #     end
    #   end
    #--
    # SPDX-SnippetEnd
    #++
    class Outlet
      # Creates an outlet for the given message queue.
      #
      # The runtime provides the message queue and lifecycle. Custom commands receive
      # the outlet as their first argument.
      #
      # [message_queue] A <tt>Concurrent::Promises::Channel</tt> or compatible object.
      # [lifecycle] A <tt>Lifecycle</tt> for managing nested command execution.
      def initialize(message_queue, lifecycle:)
        @message_queue = message_queue
        @live = lifecycle
        @pending_async = [] #: Array[AsyncHandle]
      end

      # Internal handle for async streaming commands.
      AsyncHandle = Data.define(:future) # :nodoc:
      private_constant :AsyncHandle

      # Internal infrastructure for nested command lifecycle sharing.
      attr_reader :live # :nodoc:

      # Sends a message to the runtime.
      #
      # Custom commands produce results. Messages about those results feed back
      # into your update function. This method handles the wiring.
      #
      # Use it for complex data flows or transports Rooibos doesn't ship with.
      #
      # For structured data and to avoid NoMethodError, define a custom
      # Message class with +envelope+ and domain-specific fields, and mix in
      # <tt>Rooibos::Message::Predicates</tt>. This follows the same pattern as
      # built-in Message types and RatatuiRuby events.
      #
      # === Structured Messages
      #
      #   class UserFetched < Data.define(:envelope, :user)
      #     include Rooibos::Message::Predicates
      #   end
      #
      #   out.put(UserFetched.new(envelope: :profile, user: alice))
      #
      #   # Update can pattern match:
      #   # in { type: :user_fetched, envelope: :profile, user: }
      #
      #   # Update can also use predicates:
      #   # message.user if message.user_fetched? and message.profile?
      #
      # Debug mode validates Ractor-shareability.
      def put(*args)
        message = (args.size == 1) ? args.first : args.freeze

        if RatatuiRuby::Debug.enabled? && !Ractor.shareable?(message)
          raise Rooibos::Error::Invariant,
            "Message is not Ractor-shareable: #{message.inspect}\n" \
              "Use Ractor.make_shareable or Object#freeze."
        end

        @message_queue.push(message)
      end

      # Runs a child command synchronously within a custom command.
      #
      # Use this to orchestrate multi-step workflows: fetch one result, then
      # use it to compose the next command.
      #
      # The child runs asynchronously in a future. This method blocks until
      # the child calls +put+, cancellation occurs, or the timeout expires.
      #
      # [command] A callable (lambda or Custom command) with +call(out, token)+.
      # [token]   The parent's cancellation token, passed through to the child.
      # [timeout] Max seconds to wait for the child's result (default: 30.0).
      #
      # Returns the message from the child, or +nil+ if canceled/timed out.
      # Raises if the child command raised an exception.
      #
      # === Example
      #
      #--
      # SPDX-SnippetBegin
      # SPDX-FileCopyrightText: 2026 Kerrick Long
      # SPDX-License-Identifier: MIT-0
      #++
      #   def call(out, token)
      #     user_result = out.source(fetch_user_cmd, token)
      #     return if user_result.nil?
      #     out.put(:user_loaded, user: user_result)
      #   end
      #--
      # SPDX-SnippetEnd
      #++
      def source(command, token, timeout: 30.0)
        @live.run_sync(command, token, timeout:)
      end

      # Spawns an async streaming command.
      #
      # Multiple data sources often need to stream in parallel. Dashboards,
      # real-time feeds, and multi-provider aggregations all face this pattern.
      # Waiting for one source before starting the next creates latency.
      #
      # This method spawns a child command that runs asynchronously. Messages
      # from the child stream directly to your update function as they arrive.
      # The child gets a full Outlet, so it can nest +source+ or +standing+ calls.
      #
      # Use +wait+ to block until the child completes, or fire-and-forget for
      # long-running streams.
      #
      # [command] A callable with <tt>call(out, token)</tt>.
      # [token]   The parent's cancellation token.
      #
      # Returns a handle for use with +wait+.
      #
      # === Example
      #
      # A dashboard that opens two SSE streams for live updates. Each stream
      # emits chunks as they arrive — no waiting for the other.
      #
      #--
      # SPDX-SnippetBegin
      # SPDX-FileCopyrightText: 2026 Kerrick Long
      # SPDX-License-Identifier: MIT-0
      #++
      #   def call(out, token)
      #     # Authenticate first (sync)
      #     auth = out.source(Authenticate.new, token)
      #     return if auth.nil?
      #
      #     # Open two SSE streams in parallel — chunks arrive live
      #     # Streams remain outstanding until token is canceled
      #     out.standing(StreamNotifications.new(auth), token)
      #     out.standing(StreamPrices.new(auth), token)
      #   end
      #--
      # SPDX-SnippetEnd
      #++
      def standing(command, token)
        child_outlet = Outlet.new(@message_queue, lifecycle: @live)
        future = Concurrent::Promises.future do
          command.call(child_outlet, token)
        rescue => e
          @message_queue.push Message::Error.new(command:, exception: e)
        end
        handle = AsyncHandle.new(future:)
        @pending_async << handle
        handle
      end

      # Blocks until async commands complete.
      #
      # After spawning children with +standing+, the parent command normally
      # returns immediately. Use +wait+ to block until children finish, then
      # emit a completion signal.
      #
      # This is how custom commands achieve the same end-of-streams dispatch
      # that +Command.batch+ gets automatically with +Message::Batch+.
      #
      # [handles] Zero or more handles from +standing+. If empty, waits for all.
      #
      # === Example
      #
      # A custom command that streams from two sources and signals when done.
      #
      #--
      # SPDX-SnippetBegin
      # SPDX-FileCopyrightText: 2026 Kerrick Long
      # SPDX-License-Identifier: MIT-0
      #++
      #   def call(out, token)
      #     h1 = out.standing(StreamPrices.new, token)
      #     h2 = out.standing(StreamNews.new, token)
      #     out.wait(h1, h2)
      #     out.put(:streams_closed)  # Your custom completion signal
      #   end
      #--
      # SPDX-SnippetEnd
      #++
      def wait(*handles, token: nil)
        handles = @pending_async || [] if handles.empty?
        return if handles.empty?

        futures = handles.map(&:future)
        all_done = Concurrent::Promises.zip_futures(*futures)

        if token
          # Race completion against cancellation
          Concurrent::Promises.any_event(all_done, token.origin).wait
        else
          all_done.wait
        end
      end
    end
  end
end
