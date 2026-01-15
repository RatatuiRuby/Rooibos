# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "ratatui_ruby/test_helper"

module RatatuiRuby
  module Tea
    # Test helpers for Tea command validation.
    #
    # This module extends RatatuiRuby::TestHelper with Tea-specific assertions
    # for verifying custom commands implement the proper protocol.
    module TestHelper
      # Validates a command implements the Tea command protocol.
      #
      # Custom commands run in background threads. They dispatch work and send messages.
      # Forgetting to include \<tt>Command::Custom\</tt> breaks dispatch. The runtime
      # treats \<tt>[model, bad_command]\</tt> as a model, not a tuple. Tests fail with
      # confusing Ractor shareability errors.
      #
      # This method checks the protocol. Call it in tests to catch mistakes early.
      #
      # [command] The command object to validate.
      #
      # === Example
      #
      #   def test_websocket_command_protocol
      #     cmd = WebSocketCommand.new("wss://example.com")
      #     validate_tea_command!(cmd)
      #   end
      def validate_tea_command!(command)
        unless command.respond_to?(:tea_command?)
          raise RatatuiRuby::Error::Invariant,
            "#{command.class} does not respond to #tea_command?. " \
              "Include Command::Custom or implement the tea_command? predicate."
        end

        unless command.respond_to?(:call)
          raise RatatuiRuby::Error::Invariant,
            "#{command.class} does not respond to #call. " \
              "Implement call(out, token) to execute the command."
        end

        unless command.respond_to?(:tea_cancellation_grace_period)
          raise RatatuiRuby::Error::Invariant,
            "#{command.class} does not respond to #tea_cancellation_grace_period. " \
              "Include Command::Custom or implement this method."
        end
      end
    end
  end
end

# Attach Tea test helpers to RatatuiRuby::TestHelper
RatatuiRuby::TestHelper.include(RatatuiRuby::Tea::TestHelper)
