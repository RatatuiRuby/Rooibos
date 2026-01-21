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

    # Fails if any Command::Error is present in the messages array.
    #
    # Call after running the runtime and before asserting on expected messages.
    # This ensures tests fail fast with helpful error messages instead of
    # silently passing when errors occur.
    #
    # [messages] Array of messages collected from the update function.
    # [msg]      Optional custom failure message prefix.
    #
    # === Example
    #
    #   def test_dashboard_loads_data
    #     messages = []
    #     update = -> (msg, m) do
    #       # ... handle keys ...
    #       messages << msg
    #       [m, nil]
    #     end
    #
    #     with_test_terminal do
    #       inject_key("s")
    #       inject_sync
    #       inject_key("q")
    #       Rooibos::Runtime.run(model:, view:, update:)
    #     end
    #
    #     assert_no_command_errors(messages)
    #     # ... rest of assertions
    #   end
    #
    def assert_no_command_errors(messages, msg = nil)
      error = messages.find { |m| m.is_a?(Rooibos::Command::Error) }
      return unless error

      error_detail = "#{error.exception.class}: #{error.exception.message}"
      failure_msg = msg ? "#{msg}\n#{error_detail}" : "Unexpected Command::Error: #{error_detail}"

      if respond_to?(:flunk)
        # rubocop:disable Style/SendWithLiteralMethodName
        public_send(:flunk, failure_msg)
        # rubocop:enable Style/SendWithLiteralMethodName
      else
        raise failure_msg
      end
    end
  end
end

# Attach Rooibos test helpers to RatatuiRuby::TestHelper
RatatuiRuby::TestHelper.include(Rooibos::TestHelper)
