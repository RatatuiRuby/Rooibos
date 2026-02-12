# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Command
    # A fire-and-forget parallel command.
    #
    # Applications fetch data from multiple sources. Dashboard panels load
    # users, stats, and notifications. Waiting sequentially is slow.
    # Managing threads and error handling manually is error-prone.
    #
    # This command runs children in parallel. Each child sends its own messages
    # independently. The batch completes when all children finish or when
    # cancellation fires. On cancellation, emits <tt>Message::Canceled</tt>.
    #
    # Use it for parallel fetches, concurrent refreshes, or any work that
    # does not need coordinated results.
    #
    # Prefer the <tt>Command.batch</tt> factory method for convenience.
    #
    # === Example
    #
    #   # Using the factory method (recommended)
    #   Command.batch(
    #     Command.http(:get, "/users", :users),
    #     Command.http(:get, "/stats", :stats),
    #   )
    #
    #   # Using the class directly
    #   Batch.new(
    #     Command.http(:get, "/users", :users),
    #     Command.http(:get, "/stats", :stats),
    #   )
    #
    #   # Handle each response independently
    #   def update(msg, model)
    #     case msg
    #     in { type: :http, envelope: :users, body: }
    #       model.with(users: JSON.parse(body))
    #     in { type: :http, envelope: :stats, body: }
    #       model.with(stats: JSON.parse(body))
    #     end
    #   end
    class Batch < Data.define(:commands) do
      include Custom

      class << self
        undef_method :new

        # Creates a parallel batch command.
        #
        # [args] Commands to run in parallel. Pass as multiple arguments
        #        or a single array.
        #
        # === Example
        #
        #   Batch.new(cmd1, cmd2, cmd3)
        #   Batch.new([cmd1, cmd2, cmd3])
        def new(*args)
          # DWIM: accept (cmd1, cmd2) or ([cmd1, cmd2])
          commands = (args.size == 1 && args.first.is_a?(Array)) ? args.first : args

          if RatatuiRuby::Debug.enabled?
            commands.each do |cmd|
              unless Ractor.shareable?(cmd)
                raise Rooibos::Error::Invariant,
                  "Command is not Ractor-shareable: #{cmd.inspect}\n" \
                    "Use Ractor.make_shareable or a Data.define command."
              end
            end
          end

          instance = allocate
          instance.__send__(:initialize, commands: commands.freeze)
          instance
        end
      end

      # Executes all child commands in parallel.
      #
      # Each child sends its results independently via the runtime.
      # When all complete, sends <tt>Message::Batch</tt>. If canceled,
      # sends <tt>Message::Canceled</tt> instead.
      #
      # [out] Outlet for sending messages.
      # [token] Cancellation token from the runtime.
      def call(out, token)
        handles = commands.map { |cmd| out.standing(cmd, token) }
        out.wait(*handles, token:)

        if token.canceled?
          out.put(Message::Canceled.new(command: self))
        else
          out.put(Message::Batch.new(command: self))
        end
      end

      def extract_bubbles # :nodoc:
        bubbles, rest = commands.partition { |c| c.is_a?(Bubble) }
        remaining = case rest.size
          when 0 then nil
          when 1 then rest.first
          else Batch.new(*rest)
        end
        [bubbles, remaining]
      end
    end
    end
  end
end
