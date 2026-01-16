# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "ratatui_ruby/test_helper"

module Rooibos
  # Test helpers for Rooibos command validation.
  #
  # This module extends RatatuiRuby::TestHelper with Rooibos-specific assertions
  # for verifying custom commands implement the proper protocol.
  module TestHelper
    # Validates a command implements the Rooibos command protocol.
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
    #     validate_rooibos_command!(cmd)
    #   end
    def validate_rooibos_command!(command)
      unless command.respond_to?(:rooibos_command?)
        raise Rooibos::Error::Invariant,
          "#{command.class} does not respond to #rooibos_command?. " \
            "Include Command::Custom or implement the rooibos_command? predicate."
      end

      unless command.respond_to?(:call)
        raise Rooibos::Error::Invariant,
          "#{command.class} does not respond to #call. " \
            "Implement call(out, token) to execute the command."
      end

      unless command.respond_to?(:rooibos_cancellation_grace_period)
        raise Rooibos::Error::Invariant,
          "#{command.class} does not respond to #rooibos_cancellation_grace_period. " \
            "Include Command::Custom or implement this method."
      end
    end
  end
end

# Attach Rooibos test helpers to RatatuiRuby::TestHelper
RatatuiRuby::TestHelper.include(Rooibos::TestHelper)
