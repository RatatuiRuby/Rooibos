# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestRuntimeParallel < Minitest::Test
  include Rooibos::TestHelper

  # Class-scope state for lambda-based updates
  def setup
    @@messages = []
    @@command = nil
    @@batch_cmd = nil
    @@first_wait = nil
    @@second_wait = nil
    @@failing_command = nil
    @@stubborn_command = nil
  end

  def teardown
    @@messages = []
    @@command = nil
    @@batch_cmd = nil
    @@first_wait = nil
    @@second_wait = nil
    @@failing_command = nil
    @@stubborn_command = nil
  end

  ClearView = -> (_m, t) { t.clear }

  # Basic parallel update - handles b for batch command, q for quit
  ParallelUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "b" then [m, TestRuntimeParallel.class_variable_get(:@@command)]
      when "q" then [m, Rooibos::Command.exit]
      else [m, nil]
      end
    else
      TestRuntimeParallel.class_variable_get(:@@messages) << msg
      [m, nil]
    end
  end

  # Timing update - no message capture needed
  TimingUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "b" then [m, TestRuntimeParallel.class_variable_get(:@@command)]
      when "q" then [m, Rooibos::Command.exit]
      else [m, nil]
      end
    else
      [m, nil]
    end
  end

  def test_batch_fires_multiple_commands_independently
    model = Ractor.make_shareable({})

    @@command = Rooibos::Command.batch([
      Rooibos::Command.wait(0.01, :first),
      Rooibos::Command.wait(0.01, :second),
    ])
    view = ClearView
    update = ParallelUpdate

    with_test_terminal do
      inject_key("b")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(@@messages)

    # Should receive TimerResponse messages, not bare tags
    timer_messages = @@messages.select { |m| m.is_a?(Rooibos::Message::Timer) }
    envelopes = timer_messages.map(&:envelope)
    assert_includes envelopes, :first
    assert_includes envelopes, :second
  end

  def test_batch_runs_commands_in_parallel
    model = Ractor.make_shareable({})

    # Two 0.3s waits — sequential = 0.6s, parallel < 0.5s
    @@command = Rooibos::Command.batch([
      Rooibos::Command.wait(0.3, :first),
      Rooibos::Command.wait(0.3, :second),
    ])
    view = ClearView
    update = TimingUpdate

    start = Time.now
    with_test_terminal do
      inject_key("b")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end
    elapsed = Time.now - start

    # Parallel execution: both 0.3s waits overlap, total < 0.5s
    # Sequential execution: 0.3 + 0.3 = 0.6s minimum
    assert_operator elapsed, :<, 0.5, "Batch should run commands in parallel, not sequentially"
  end

  # Cancel update - handles b for batch with model tracking, c for cancel, q for quit
  CancelUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "b"
        first = TestRuntimeParallel.class_variable_get(:@@first_wait)
        second = TestRuntimeParallel.class_variable_get(:@@second_wait)
        cmd = Rooibos::Command.batch([first, second])
        [Ractor.make_shareable({ cmd: }), cmd]
      when "c"
        [m, Rooibos::Command.cancel(m[:cmd])]
      when "q"
        [m, Rooibos::Command.exit]
      else
        [m, nil]
      end
    else
      TestRuntimeParallel.class_variable_get(:@@messages) << msg
      [m, nil]
    end
  end

  def test_batch_cancellation_signals_children_cooperatively
    @@first_wait = Rooibos::Command.wait(10.0, :should_not_arrive)
    @@second_wait = Rooibos::Command.wait(10.0, :also_should_not)
    model = Ractor.make_shareable({ cmd: nil })

    view = ClearView
    update = CancelUpdate

    with_test_terminal do
      inject_key("b")
      inject_key("c")
      inject_sync # Wait for cancellation messages
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    # Cooperative cancellation: children emit Message::Canceled
    cancel_commands = @@messages
      .select { |m| m.is_a?(Rooibos::Message::Canceled) }
      .map(&:command)

    assert_includes cancel_commands, @@first_wait, "First child should emit Canceled message"
    assert_includes cancel_commands, @@second_wait, "Second child should emit Canceled message"
  end

  # Failing update - handles b for batch with failing_command, q for quit
  FailingUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "b"
        failing = TestRuntimeParallel.class_variable_get(:@@failing_command)
        wait = TestRuntimeParallel.class_variable_get(:@@first_wait)
        cmds = wait ? [failing, wait] : [failing]
        cmd = Rooibos::Command.batch(cmds)
        [m, cmd]
      when "q"
        [m, Rooibos::Command.exit]
      else
        [m, nil]
      end
    else
      TestRuntimeParallel.class_variable_get(:@@messages) << msg
      [m, nil]
    end
  end

  # Define failing command class once
  FailingCommand = Data.define do
    include Rooibos::Command::Custom
    def call(_out, _token)
      raise "intentional failure"
    end
  end

  def test_batch_reports_child_errors
    model = Ractor.make_shareable({})

    @@failing_command = Ractor.make_shareable(FailingCommand.new)
    @@first_wait = nil
    view = ClearView
    update = FailingUpdate

    with_test_terminal do
      inject_key("b")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    # Child error should surface as Message::Error (aligned with Command.all)
    error_msg = @@messages.find { |m| m.is_a?(Rooibos::Message::Error) }
    refute_nil error_msg, "Expected Message::Error message from failed child"
    assert_match(/intentional failure/, error_msg.exception.message)
  end

  # Stubborn command class definition
  StubbornCommand = Data.define do
    include Rooibos::Command::Custom
    def rooibos_cancellation_grace_period = 60.0

    def call(_out, _token)
      sleep 100
    end
  end

  # Stubborn update - handles b for batch with stubborn_command, c for cancel, q for quit
  StubbornUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "b"
        stubborn = TestRuntimeParallel.class_variable_get(:@@stubborn_command)
        batch_cmd = Rooibos::Command.batch([stubborn])
        TestRuntimeParallel.class_variable_set(:@@batch_cmd, batch_cmd)
        [m, batch_cmd]
      when "c"
        batch_cmd = TestRuntimeParallel.class_variable_get(:@@batch_cmd)
        [m, Rooibos::Command.cancel(batch_cmd)]
      when "q"
        [m, Rooibos::Command.exit]
      else
        [m, nil]
      end
    else
      TestRuntimeParallel.class_variable_get(:@@messages) << msg
      [m, nil]
    end
  end

  def test_batch_exits_early_on_cancellation
    @@stubborn_command = Ractor.make_shareable(StubbornCommand.new)
    model = Ractor.make_shareable({})

    view = ClearView
    update = StubbornUpdate

    start = Time.now
    with_test_terminal do
      inject_key("b")
      inject_key("c")
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end
    elapsed = Time.now - start

    # Batch races and exits fast despite stubborn child's 60s grace
    assert_operator elapsed, :<, 5.0, "Batch should exit early on cancellation"

    # Batch emits Canceled message
    cancel_msg = @@messages.find { |m| m.is_a?(Rooibos::Message::Canceled) }
    assert_same @@batch_cmd, cancel_msg&.command, "Batch should emit Canceled message with self"
  end

  def test_batch_validates_commands_are_shareable
    non_shareable_command = Class.new do
      include Rooibos::Command::Custom
      def call(_out, _token) = nil
    end.new

    # Should raise at construction time, not later
    assert_raises(Rooibos::Error::Invariant) do
      Rooibos::Command.batch([non_shareable_command])
    end
  end

  def test_batch_accepts_variadic_args
    cmd1 = Ractor.make_shareable(Data.define { include Rooibos::Command::Custom; def call(o, _t) = o.put(:a) }.new)
    cmd2 = Ractor.make_shareable(Data.define { include Rooibos::Command::Custom; def call(o, _t) = o.put(:b) }.new)

    # Both should work: batch([cmd1, cmd2]) AND batch(cmd1, cmd2)
    batch_array = Rooibos::Command.batch([cmd1, cmd2])
    batch_variadic = Rooibos::Command.batch(cmd1, cmd2)

    assert_equal 2, batch_array.commands.size
    assert_equal 2, batch_variadic.commands.size

    # Batch.new directly also gets DWIM behavior
    batch_array = Rooibos::Command::Batch.new(cmd1, cmd2)
    batch_variadic = Rooibos::Command::Batch.new([cmd1, cmd2])
    assert_equal 2, batch_array.commands.size
    assert_equal 2, batch_variadic.commands.size
  end

  def test_batch_continues_other_commands_when_one_fails
    model = Ractor.make_shareable({})

    @@failing_command = Ractor.make_shareable(FailingCommand.new)
    @@first_wait = Rooibos::Command.wait(0.01, :success) # One fails, one succeeds
    view = ClearView
    update = FailingUpdate

    with_test_terminal do
      inject_key("b")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    # The successful command should still complete - check for TimerResponse
    timer_msg = @@messages.find { |m| m.is_a?(Rooibos::Message::Timer) && m.envelope == :success }
    refute_nil timer_msg, "Successful command should still run when sibling fails"

    # Error should also be reported
    error_msg = @@messages.find { |m| m.is_a?(Rooibos::Message::Error) }
    refute_nil error_msg, "Expected Message::Error from failed child"
  end
end
