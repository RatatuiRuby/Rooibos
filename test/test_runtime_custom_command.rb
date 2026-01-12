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
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
        else [m, nil]
        end
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    refute_nil received_token, "Command should have received a Cancellation"
    assert_kind_of RatatuiRuby::Tea::Command::Outlet, received_out
    assert_kind_of Concurrent::Cancellation, received_token
  end

  def test_outlet_messages_arrive_in_update
    messages = []
    command_class = Class.new do
      include RatatuiRuby::Tea::Command::Custom

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
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
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
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_includes messages, [:test_message, :payload], "Update should receive outlet message"
  end

  # Command that runs briefly then finishes
  BriefCommand = Data.define do
    include RatatuiRuby::Tea::Command::Custom

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
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
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

      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    # Brief command (0.05s) finishes within its 0.1s grace period
    assert_includes events, :brief_done, "Commands should finish within grace period"
  end

  # Long-running command that waits until cancelled
  WaitForCancel = Data.define do
    include RatatuiRuby::Tea::Command::Custom

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
          [m, RatatuiRuby::Tea::Command.cancel(m[:cmd])]
        when "q"
          [m, RatatuiRuby::Tea::Command.exit]
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
      else
        events << msg
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
          [m, RatatuiRuby::Tea::Command.cancel(m[:cmd])]
        when "q"
          [m, RatatuiRuby::Tea::Command.exit]
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

      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_includes events, :infinite_started, "Command should have started"
    assert_includes events, :infinite_stopped, "Command should have stopped cooperatively"
  end

  def test_shutdown_kills_stubborn_commands_quickly
    skip "Timing test - timing doesn't distinguish kill from orphan"
  end

  def test_shutdown_does_not_orphan_command_threads
    threads_before = Thread.list

    with_test_terminal do
      inject_key("s")  # Start stubborn command (sleeps for 10s)
      inject_key("q")  # Quit

      model = Ractor.make_shareable({})
      view = -> (_m, t) { t.clear }
      update = -> (msg, m) do
        case msg
        when RatatuiRuby::Event::Key
          case msg.code
          when "s" then [m, IgnoresCancel.new]
          when "q" then [m, RatatuiRuby::Tea::Command.exit]
          else [m, nil]
          end
        else
          [m, nil]
        end
      end

      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    # Give orphaned threads a moment to show up
    sleep 0.05

    threads_after = Thread.list
    orphaned = threads_after - threads_before
    # Filter to only command threads (from runtime.rb), not stdlib threads
    command_orphans = orphaned.select { |t| t.to_s.include?("runtime.rb") }

    assert_empty command_orphans, "Shutdown should not leave orphaned command threads: #{command_orphans.map(&:inspect)}"
  end

  # Command that raises an error
  ExplodingCommand = Data.define do
    include RatatuiRuby::Tea::Command::Custom

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
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
        else [m, nil]
        end
      when RatatuiRuby::Tea::Command::Error
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

      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    refute_nil received_error, "Update should receive Command::Error"
    assert_kind_of RatatuiRuby::Tea::Command::Error, received_error
    assert_equal ExplodingCommand, received_error.command.class
    assert_equal "Boom!", received_error.exception.message
  end
end
