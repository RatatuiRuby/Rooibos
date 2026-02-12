# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestRuntimeCustomCommand < Minitest::Test
  include Rooibos::TestHelper

  # Class-scope state for lambda-based updates
  def setup
    @@messages = []
    @@events = []
    @@command = nil
    @@command_class = nil
    @@received_error = nil
  end

  def teardown
    @@messages = []
    @@events = []
    @@command = nil
    @@command_class = nil
    @@received_error = nil
  end

  ClearView = -> (_m, t) { t.clear }

  # Basic custom update - handles s for start with @@command, q for quit
  CustomUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "s" then [m, TestRuntimeCustomCommand.class_variable_get(:@@command)]
      when "q" then [m, Rooibos::Command.exit]
      else [m, nil]
      end
    else
      [m, nil]
    end
  end

  # Message capture update - uses @@messages
  MessageUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "s"
        cmd_class = TestRuntimeCustomCommand.class_variable_get(:@@command_class)
        [m, cmd_class.new]
      when "q" then [m, Rooibos::Command.exit]
      else [m, nil]
      end
    else
      TestRuntimeCustomCommand.class_variable_get(:@@messages) << msg
      [m, nil]
    end
  end

  # Event capture update - uses @@events
  EventUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "s" then [m, TestRuntimeCustomCommand.class_variable_get(:@@command)]
      when "q" then [m, Rooibos::Command.exit]
      else [m, nil]
      end
    else
      TestRuntimeCustomCommand.class_variable_get(:@@events) << msg
      [m, nil]
    end
  end

  # Cancel update - handles s for start with model tracking, c for cancel, q for quit
  CancelUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "s"
        cmd = TestRuntimeCustomCommand.class_variable_get(:@@command)
        [Ractor.make_shareable({ cmd: }), cmd]
      when "c"
        [m, Rooibos::Command.cancel(m[:cmd])]
      when "q"
        [m, Rooibos::Command.exit]
      else
        [m, nil]
      end
    else
      TestRuntimeCustomCommand.class_variable_get(:@@events) << msg
      [m, nil]
    end
  end

  def test_transition_from_recognizes_custom_command
    command_class = Class.new do
      include Rooibos::Command::Custom
    end

    command = command_class.new
    previous_model = :old_model

    # Simulate update returning [model, custom_command]
    result = [:new_model, command]
    transition = Rooibos::Transition.from(result, previous_model)

    assert_equal :new_model, transition.model, "Model should be extracted"
    assert_equal command, transition.command, "Custom command should be recognized as command"
  end

  # Command class to capture outlet and token
  ReceiverCommand = Class.new do
    include Rooibos::Command::Custom
    @received_out = nil
    @received_token = nil

    def self.received_out; @received_out; end
    def self.received_token; @received_token; end
    def self.reset!; @received_out = nil; @received_token = nil; end

    def call(out, token)
      self.class.instance_variable_set(:@received_out, out)
      self.class.instance_variable_set(:@received_token, token)
    end
  end

  def test_dispatch_calls_custom_command_with_outlet_and_token
    ReceiverCommand.reset!
    command = ReceiverCommand.new

    model = Ractor.make_shareable({})

    @@command = command
    view = ClearView
    update = CustomUpdate

    with_test_terminal do
      inject_key("s")
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    refute_nil ReceiverCommand.received_token, "Command should have received a Cancellation"
    assert_kind_of Rooibos::Command::Outlet, ReceiverCommand.received_out
    assert_kind_of Concurrent::Cancellation, ReceiverCommand.received_token
  end

  # Command that emits a message
  EmitterCommand = Class.new do
    include Rooibos::Command::Custom

    def call(out, _token)
      out.put(:test_message, :payload)
    end
  end

  def test_outlet_messages_arrive_in_update
    model = Ractor.make_shareable({})

    @@command_class = EmitterCommand
    view = ClearView
    update = MessageUpdate

    with_test_terminal do
      inject_key("s")
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_includes @@messages, [:test_message, :payload], "Update should receive outlet message"
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
    model = Ractor.make_shareable({})

    @@command = BriefCommand.new
    view = ClearView
    update = EventUpdate

    with_test_terminal do
      inject_key("s")  # Start brief command
      inject_key("q")  # Quit

      Rooibos::Runtime.run(model:, view:, update:)
    end

    # Brief command (0.05s) finishes within its 0.1s grace period
    assert_includes @@events, :brief_done, "Commands should finish within grace period"
  end

  # Long-running command that waits until canceled
  WaitForCancel = Data.define do
    include Rooibos::Command::Custom

    def call(out, token)
      out.put(:command_started)
      sleep 0.02 until token.canceled?
      out.put(:command_canceled)
    end
  end

  def test_cancel_command_signals_token
    model = Ractor.make_shareable({ cmd: nil })

    @@command = WaitForCancel.new
    view = ClearView
    update = CancelUpdate

    with_test_terminal do
      inject_key("s")  # Start command
      inject_key("c")  # Cancel it
      inject_key("q")  # Quit

      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_includes @@events, :command_started, "Command should have started"
    assert_includes @@events, :command_canceled, "Command should have been canceled"
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
    model = Ractor.make_shareable({ cmd: nil })

    @@command = InfiniteGraceCooperative.new
    view = ClearView
    update = CancelUpdate

    with_test_terminal do
      inject_key("s")  # Start infinite grace command
      inject_key("c")  # Cancel it (should wait for cooperative stop)
      inject_key("q")  # Quit

      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_includes @@events, :infinite_started, "Command should have started"
    assert_includes @@events, :infinite_stopped, "Command should have stopped cooperatively"
  end

  def test_shutdown_kills_stubborn_commands_quickly
    skip "Timing test - timing doesn't distinguish kill from orphan"
  end

  # Error update - captures @@received_error for error-handling tests
  ErrorUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "s" then [m, TestRuntimeCustomCommand.class_variable_get(:@@command)]
      when "q" then [m, Rooibos::Command.exit]
      else [m, nil]
      end
    when Rooibos::Message::Error
      TestRuntimeCustomCommand.class_variable_set(:@@received_error, msg)
      [m, nil]
    else
      [m, nil]
    end
  end

  # Command that raises an error
  ExplodingCommand = Data.define do
    include Rooibos::Command::Custom

    def call(_out, _token)
      raise "Boom!"
    end
  end

  def test_unhandled_command_exception_produces_command_error
    model = Ractor.make_shareable({})

    @@command = ExplodingCommand.new
    view = ClearView
    update = ErrorUpdate

    with_test_terminal do
      inject_key("s")  # Start exploding command
      inject_sync      # Wait for command to complete
      inject_key("q")  # Quit

      Rooibos::Runtime.run(model:, view:, update:)
    end

    refute_nil @@received_error, "Update should receive Message::Error"
    assert_kind_of Rooibos::Message::Error, @@received_error
    assert_equal ExplodingCommand, @@received_error.command.class
    assert_equal "Boom!", @@received_error.exception.message
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
