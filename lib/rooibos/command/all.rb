# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Command
    # Aggregates parallel commands and returns all results together.
    #
    # Dashboards load user profiles, settings, and stats before rendering.
    # Fetching sequentially is slow. Fire-and-forget batches lose correlation
    # between commands and their results.
    #
    # This command runs children in parallel and collects their results into
    # a single <tt>Message::All</tt> response. Pattern-match on the envelope
    # to correlate results. Each result appears in the same order as commands.
    #
    # Use it for coordinated fetches where you need all results before proceeding.
    #
    # Prefer the <tt>Command.all</tt> factory method for convenience.
    #
    # === Example
    #
    #   # Using the factory method (recommended)
    #   Command.all(:dashboard,
    #     Command.http(:get, "/users", :_),
    #     Command.http(:get, "/stats", :_),
    #   )
    #
    #   # Using the class directly
    #   All.new(:dashboard,
    #     Command.http(:get, "/users", :_),
    #     Command.http(:get, "/stats", :_),
    #   )
    #
    #   # Pattern-match on the aggregated result
    #   def update(message, model)
    #     case message
    #     in { type: :all, envelope: :dashboard, results: [users, stats] }
    #       model.with(users:, stats:, loading: false)
    #     end
    #   end
    class All < Data.define(:envelope, :commands, :nested)
      include Custom

      class << self
        undef_method :new

        # Creates an aggregating parallel command.
        #
        # [tag] Symbol to tag the result message.
        # [args] Commands to run in parallel. Pass as multiple arguments
        #        or a single array.
        #
        # === Example
        #
        #   All.new(:dashboard,
        #     Command.http(:get, "/users", :_),
        #     Command.http(:get, "/stats", :_),
        #   )
        def new(tag, *args)
          # DWIM: flatten single-array arg to support both call patterns
          nested = args.size == 1 && args.first.is_a?(Array)
          commands = [args].flatten(2)

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
          instance.__send__(:initialize, envelope: tag, commands: commands.freeze, nested:)
          instance
        end
      end

      # Executes all child commands in parallel and aggregates results.
      #
      # Sends <tt>Message::All</tt> when all children complete. Results appear
      # in the same order as commands. If canceled, sends <tt>Message::Canceled</tt>.
      #
      # [out] Outlet for sending messages.
      # [token] Cancellation token from the runtime.
      def call(out, token)
        # Early return for empty commands - prevents hang from zip_futures([])
        if commands.empty?
          results = [] #: Array[Object]
          response = Message::All.new(envelope:, results: results.freeze, nested:)
          out.put(Ractor.make_shareable(response))
          return
        end

        child_lifecycle = Lifecycle.new

        futures = commands.map do |command|
          Concurrent::Promises.future do
            child_channel = Concurrent::Promises::Channel.new
            child_outlet = Outlet.new(child_channel, lifecycle: child_lifecycle)
            command.call(child_outlet, token)
            child_channel.pop
          end
        end

        all_done = Concurrent::Promises.zip_futures(*futures)
        Concurrent::Promises.any_event(all_done, token.origin).wait

        return out.put(Message::Canceled.new(command: self)) if token.canceled?

        shareable_results = Ractor.make_shareable(all_done.value!)
        response = Message::All.new(envelope:, results: shareable_results, nested:)
        out.put(Ractor.make_shareable(response))
      end
    end
  end
end
