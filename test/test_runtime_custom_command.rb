# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "ratatui_ruby/test_helper"

class TestRuntimeCustomCommand < Minitest::Test
  include RatatuiRuby::TestHelper

  def test_normalize_update_result_recognizes_custom_command
    command_class = Class.new do
      include RatatuiRuby::Tea::Command::Custom
    end

    command = command_class.new
    previous_model = :old_model

    # Simulate update returning [model, custom_command]
    result = [:new_model, command]
    normalized = RatatuiRuby::Tea::Runtime.__send__(:normalize_update_result, result, previous_model)

    assert_equal :new_model, normalized[0], "Model should be extracted"
    assert_equal command, normalized[1], "Custom command should be recognized as command"
  end

  def test_dispatch_calls_custom_command_with_outlet_and_token
    received_out = nil
    received_token = nil

    command_class = Class.new do
      include RatatuiRuby::Tea::Command::Custom

      define_method(:initialize) do |callback|
        @callback = callback
      end

      define_method(:call) do |out, token|
        @callback.call(out, token)
      end
    end

    callback = -> (out, token) do
      received_out = out
      received_token = token
    end

    command = command_class.new(callback)
    queue = Queue.new

    thread = RatatuiRuby::Tea::Runtime.__send__(:dispatch, command, queue)
    thread&.join

    refute_nil received_out, "Command should have received an Outlet"
    refute_nil received_token, "Command should have received a CancellationToken"
    assert_kind_of RatatuiRuby::Tea::Command::Outlet, received_out
    assert_kind_of RatatuiRuby::Tea::Command::CancellationToken, received_token
  end

  def test_outlet_messages_arrive_in_queue
    command_class = Class.new do
      include RatatuiRuby::Tea::Command::Custom

      define_method(:call) do |out, _token|
        out.put(:test_message, :payload)
      end
    end

    command = command_class.new
    queue = Queue.new

    thread = RatatuiRuby::Tea::Runtime.__send__(:dispatch, command, queue)
    thread&.join

    message = begin
      queue.pop(true)
    rescue
      nil
    end
    refute_nil message, "Queue should have received a message"
    assert_equal [:test_message, :payload], message
  end

  # Command that runs briefly then finishes
  BriefCommand = Data.define do
    include RatatuiRuby::Tea::Command::Custom

    def call(out, _token)
      sleep 0.05 # Brief work
      out.put(:brief_done)
    end
  end

  def test_runtime_waits_for_active_commands_on_exit
    events = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s" then [m, BriefCommand.new]
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
        else [m, nil]
        end
      when Array
        events << msg[0]
        [m, nil]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")  # Start brief command
      inject_key("q")  # Quit immediately

      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    # The brief command should have finished BEFORE runtime exited
    assert_includes events, :brief_done, "Runtime should wait for active commands before exiting"
  end

  # Long-running command that waits until cancelled
  WaitForCancel = Data.define do
    include RatatuiRuby::Tea::Command::Custom

    def call(out, token)
      out.put(:command_started)
      sleep 0.02 until token.cancelled?
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
          [m, RatatuiRuby::Tea::Command.cancel(m[:cmd])]
        when "q"
          [m, RatatuiRuby::Tea::Command.exit]
        else
          [m, nil]
        end
      when Array
        events << msg[0]
        [m, nil]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")  # Start command
      inject_key("c")  # Cancel it
      inject_key("q")  # Quit

      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_includes events, :command_started, "Command should have started"
    assert_includes events, :command_cancelled, "Command should have been cancelled"
  end

  # Command that ignores cancellation with short grace period
  IgnoresCancel = Data.define do
    include RatatuiRuby::Tea::Command::Custom

    def tea_cancellation_grace_period = 0.1 # 100ms grace

    def call(out, _token)
      out.put(:stubborn_started)
      sleep 10 # Ignores token, sleeps forever
      out.put(:stubborn_finished) # Should never reach here
    end
  end

  def test_cancel_force_kills_after_grace_period
    events = []
    model = Ractor.make_shareable({ cmd: nil })
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s"
          cmd = IgnoresCancel.new
          [Ractor.make_shareable({ cmd: }), cmd]
        when "c"
          [m, RatatuiRuby::Tea::Command.cancel(m[:cmd])]
        when "q"
          [m, RatatuiRuby::Tea::Command.exit]
        else
          [m, nil]
        end
      when Array
        events << msg[0]
        [m, nil]
      else
        [m, nil]
      end
    end

    start_time = Time.now

    with_test_terminal do
      inject_key("s")  # Start stubborn command
      inject_key("c")  # Cancel it (should force-kill after 0.1s)
      inject_key("q")  # Quit

      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    elapsed = Time.now - start_time

    assert_includes events, :stubborn_started, "Command should have started"
    refute_includes events, :stubborn_finished, "Command should have been killed before finishing"
    assert_operator elapsed, :<, 1.0, "Should finish quickly (force-kill at 0.1s), not wait 10s"
  end

  # Command with infinite grace that cooperates with cancellation
  InfiniteGraceCooperative = Data.define do
    include RatatuiRuby::Tea::Command::Custom

    def tea_cancellation_grace_period = Float::INFINITY

    def call(out, token)
      out.put(:infinite_started)
      sleep 0.02 until token.cancelled?
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
          [m, RatatuiRuby::Tea::Command.cancel(m[:cmd])]
        when "q"
          [m, RatatuiRuby::Tea::Command.exit]
        else
          [m, nil]
        end
      when Array
        events << msg[0]
        [m, nil]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")  # Start infinite grace command
      inject_key("c")  # Cancel it (should wait for cooperative stop)
      inject_key("q")  # Quit

      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_includes events, :infinite_started, "Command should have started"
    assert_includes events, :infinite_stopped, "Command should have stopped cooperatively"
  end
end
