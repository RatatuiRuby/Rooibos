# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module RatatuiRuby
  module Tea
    module Command
      # An aggregating parallel command.
      All = Data.define(:tag, :commands, :nested) do
        include Custom

        def self.new(tag, *args)
          # DWIM: detect nested vs splatted based on call-site arity
          if args.size == 1 && args.first.is_a?(Array)
            commands = args.first
            nested = true
          else
            commands = args
            nested = false
          end

          if RatatuiRuby::Debug.enabled?
            commands.each do |cmd|
              unless Ractor.shareable?(cmd)
                raise RatatuiRuby::Error::Invariant,
                  "Command is not Ractor-shareable: #{cmd.inspect}\n" \
                    "Use Ractor.make_shareable or a Data.define command."
              end
            end
          end

          instance = allocate
          instance.__send__(:initialize, tag:, commands: commands.freeze, nested:)
          instance
        end

        def call(outlet, token)
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

          return outlet.put(Command.cancel(self)) if token.canceled?

          shareable_results = Ractor.make_shareable(all_done.value!)
          if nested
            outlet.put(tag, shareable_results)
          else
            outlet.put(tag, *shareable_results)
          end
        end
      end
    end
  end
end
