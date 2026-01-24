# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "ratatui_ruby/test_helper"

module Rooibos
  # Assertions and test utilities for Rooibos applications.
  #
  # Custom commands run in background threads. Forgetting to include
  # <tt>Command::Custom</tt> causes cryptic Ractor errors. Validating
  # protocol compliance manually is tedious.
  #
  # This module provides Rooibos-specific assertions. It also includes
  # {RatatuiRuby::TestHelper}[https://www.ratatui-ruby.dev/docs/v1.0/RatatuiRuby/TestHelper.html],
  # giving you access to <tt>with_test_terminal</tt>, <tt>inject_key</tt>, etc.
  #
  # Use it in Minitest classes to validate commands and control test terminals.
  #
  # === Example
  #
  #   class TestMyApp < Minitest::Test
  #     include Rooibos::TestHelper
  #
  #     def test_app_exits_on_ctrl_c
  #       with_test_terminal do
  #         inject_key(:ctrl_c)
  #         Rooibos.run(MyApp)
  #       end
  #     end
  #   end
  module TestHelper
    include RatatuiRuby::TestHelper

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
