# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "ratatui_ruby"

module RatatuiRuby
  module Tea
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
      #     include Tea::Command::Custom
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
      #     include Tea::Command::Custom
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
        # Creates an outlet for the given channel.
        #
        # The runtime provides the channel and lifecycle. Custom commands receive
        # the outlet as their first argument.
        #
        # [channel] A <tt>Concurrent::Promises::Channel</tt> or compatible object.
        # [lifecycle] A <tt>Lifecycle</tt> for managing nested command execution.
        def initialize(channel, lifecycle:)
          @channel = channel
          @live = lifecycle
        end

        # :nodoc: Internal infrastructure for nested command lifecycle sharing.
        attr_reader :live

        # Sends a message to the runtime.
        #
        # Custom commands produce results. Those results feed back into your
        # update function. This method handles the wiring.
        #
        # Call with one argument to send it directly. Call with multiple
        # arguments and they arrive as an array.
        #
        # Use it for complex data flows or transports Tea doesn't ship with.
        #
        # === Example
        #
        #   out.put(:done)              # Update receives :done
        #   out.put(current_user)       # Update receives current_user
        #   out.put(:user, alice)       # Update receives [:user, alice]
        #
        # Debug mode validates Ractor-shareability.
        def put(*args)
          message = (args.size == 1) ? args.first : args.freeze

          if RatatuiRuby::Debug.enabled? && !Ractor.shareable?(message)
            raise RatatuiRuby::Error::Invariant,
              "Message is not Ractor-shareable: #{message.inspect}\n" \
                "Use Ractor.make_shareable or Object#freeze."
          end

          @channel.push(message)
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
        # Returns the message from the child, or +nil+ if cancelled/timed out.
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
      end
    end
  end
end
