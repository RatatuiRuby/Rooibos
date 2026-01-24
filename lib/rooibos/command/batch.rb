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
    # cancellation fires. On cancellation, emits <tt>Command.cancel(self)</tt>.
    #
    # Use it for parallel fetches, concurrent refreshes, or any work that
    # does not need coordinated results.
    #
    # === Example
    #
    #   def update(msg, model)
    #     case msg
    #     in :refresh_all
    #       batch = Command.batch(
    #         Command.http(:get, "/users", :users),
    #         Command.http(:get, "/stats", :stats),
    #       )
    #       [model.with(loading: true), batch]
    #     in :users | :stats
    #       [model.with(msg => data), nil]
    #     end
    #   end
    class Batch < Data.define(:commands) do
      include Custom

      class << self
        undef_method :new

        # Initialize
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

      # Call it
      def call(out, token)
        handles = commands.map { |cmd| out.standing(cmd, token) }
        out.wait(*handles, token:)

        if token.canceled?
          out.put(Command.cancel(self))
        else
          out.put(Message::Batch.new(command: self))
        end
      end
    end
    end
  end
end
