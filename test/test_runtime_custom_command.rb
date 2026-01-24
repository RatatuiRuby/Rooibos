# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestRuntimeCustomCommand < Minitest::Test
  include Rooibos::TestHelper

  def test_normalize_update_return_recognizes_custom_command
    command_class = Class.new do
      include Rooibos::Command::Custom
    end

    command = command_class.new
    previous_model = :old_model

    # Simulate update returning [model, custom_command]
    result = [:new_model, command]
    normalized = Rooibos::Runtime.__send__(:normalize_update_return, result, previous_model)

    assert_equal :new_model, normalized[0], "Model should be extracted"
    assert_equal command, normalized[1], "Custom command should be recognized as command"
  end

  def test_dispatch_calls_custom_command_with_outlet_and_token
    received_out = nil
    received_token = nil

    command_class = Class.new do
      include Rooibos::Command::Custom

      define_method(:initialize) do |callback|
        @callback = callback
      end

      define_method(:call) do |out, token|
        @callback.call(out, token)
      end
    end

    received_out = nil
    received_token = nil
    callback = -> (out, token) do
      received_out = out
      received_token = token
    end
    command = command_class.new(callback)

    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }
    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s" then [m, command]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    refute_nil received_token, "Command should have received a Cancellation"
    assert_kind_of Rooibos::Command::Outlet, received_out
    assert_kind_of Concurrent::Cancellation, received_token
  end

  def test_outlet_messages_arrive_in_update
    messages = []
    command_class = Class.new do
      include Rooibos::Command::Custom

      define_method(:call) do |out, _token|
        out.put(:test_message, :payload)
      end
    end

    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }
    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s" then [m, command_class.new]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_includes messages, [:test_message, :payload], "Update should receive outlet message"
  end

  # Command that runs briefly then finishes
  BriefCommand = Data.define do
    include Rooibos::Command::Custom

    def call(out, _token)
      sleep 0.05 # Brief work
      out.put(:brief_done)
    end
  end

  def test_shutdown_allows_commands_to_finish_within_grace_period
    events = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s" then [m, BriefCommand.new] # 0.05s work, 0.1s grace
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        events << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")  # Start brief command
      inject_key("q")  # Quit

      Rooibos::Runtime.run(model:, view:, update:)
    end

    # Brief command (0.05s) finishes within its 0.1s grace period
    assert_includes events, :brief_done, "Commands should finish within grace period"
  end

  # Long-running command that waits until cancelled
  WaitForCancel = Data.define do
    include Rooibos::Command::Custom

    def call(out, token)
      out.put(:command_started)
      sleep 0.02 until token.canceled?
      out.put(:command_cancelled)
    end
  end

  def test_cancel_command_signals_token
    events = []
    model = Ractor.make_shareable({ cmd: nil })
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s"
          cmd = WaitForCancel.new
          [Ractor.make_shareable({ cmd: }), cmd]
        when "c"
          [m, Rooibos::Command.cancel(m[:cmd])]
        when "q"
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        events << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")  # Start command
      inject_key("c")  # Cancel it
      inject_key("q")  # Quit

      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_includes events, :command_started, "Command should have started"
    assert_includes events, :command_cancelled, "Command should have been cancelled"
  end

  # Command with infinite grace that cooperates with cancellation
  InfiniteGraceCooperative = Data.define do
    include Rooibos::Command::Custom

    def rooibos_cancellation_grace_period = Float::INFINITY

    def call(out, token)
      out.put(:infinite_started)
      sleep 0.02 until token.canceled?
      out.put(:infinite_stopped)
    end
  end

  def test_infinite_grace_waits_for_cooperative_stop
    events = []
    model = Ractor.make_shareable({ cmd: nil })
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s"
          cmd = InfiniteGraceCooperative.new
          [Ractor.make_shareable({ cmd: }), cmd]
        when "c"
          [m, Rooibos::Command.cancel(m[:cmd])]
        when "q"
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        events << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")  # Start infinite grace command
      inject_key("c")  # Cancel it (should wait for cooperative stop)
      inject_key("q")  # Quit

      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_includes events, :infinite_started, "Command should have started"
    assert_includes events, :infinite_stopped, "Command should have stopped cooperatively"
  end

  def test_shutdown_kills_stubborn_commands_quickly
    skip "Timing test - timing doesn't distinguish kill from orphan"
  end

  # Command that raises an error
  ExplodingCommand = Data.define do
    include Rooibos::Command::Custom

    def call(_out, _token)
      raise "Boom!"
    end
  end

  def test_unhandled_command_exception_produces_command_error
    received_error = nil
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s" then [m, ExplodingCommand.new]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      when Rooibos::Message::Error
        received_error = msg
        [m, nil]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")  # Start exploding command
      inject_sync      # Wait for command to complete
      inject_key("q")  # Quit

      Rooibos::Runtime.run(model:, view:, update:)
    end

    refute_nil received_error, "Update should receive Message::Error"
    assert_kind_of Rooibos::Message::Error, received_error
    assert_equal ExplodingCommand, received_error.command.class
    assert_equal "Boom!", received_error.exception.message
  end

  def test_command_error_includes_message_predicates
    error = Rooibos::Message::Error.new(command: nil, exception: RuntimeError.new("boom"))

    # Message::Error should include Message::Predicates so it can be safely
    # pattern-matched in update functions alongside keyboard/mouse events
    refute error.ctrl_c?, "Message::Error should respond to ctrl_c? via Predicates"
    refute error.mouse?,  "Message::Error should respond to mouse? via Predicates"
    refute error.key?,    "Message::Error should respond to key? via Predicates"
  end
end
