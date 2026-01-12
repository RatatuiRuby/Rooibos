# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "ratatui_ruby/test_helper"

class TestRuntimeParallel < Minitest::Test
  include RatatuiRuby::TestHelper

  def test_batch_fires_multiple_commands_independently
    messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "b"
          batch = RatatuiRuby::Tea::Command.batch([
            RatatuiRuby::Tea::Command.wait(0.01, :first),
            RatatuiRuby::Tea::Command.wait(0.01, :second),
          ])
          [m, batch]
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
        else [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("b")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_includes messages, :first
    assert_includes messages, :second
  end

  def test_batch_runs_commands_in_parallel
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "b"
          # Two 0.1s waits — sequential = 0.2s, parallel < 0.15s
          batch = RatatuiRuby::Tea::Command.batch([
            RatatuiRuby::Tea::Command.wait(0.1, :first),
            RatatuiRuby::Tea::Command.wait(0.1, :second),
          ])
          [m, batch]
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
        else [m, nil]
        end
      else
        [m, nil]
      end
    end

    start = Time.now
    with_test_terminal do
      inject_key("b")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end
    elapsed = Time.now - start

    # Parallel execution: both 0.1s waits overlap, total < 0.15s
    # Sequential execution: 0.1 + 0.1 = 0.2s minimum
    assert_operator elapsed, :<, 0.15, "Batch should run commands in parallel, not sequentially"
  end

  def test_batch_cancellation_signals_children_cooperatively
    messages = []
    first_wait = nil
    second_wait = nil
    model = Ractor.make_shareable({ cmd: nil })
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "b"
          first_wait = RatatuiRuby::Tea::Command.wait(10.0, :should_not_arrive)
          second_wait = RatatuiRuby::Tea::Command.wait(10.0, :also_should_not)
          cmd = RatatuiRuby::Tea::Command.batch([first_wait, second_wait])
          [Ractor.make_shareable({ cmd: }), cmd]
        when "c"
          [m, RatatuiRuby::Tea::Command.cancel(m[:cmd])]
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
        else [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("b")
      inject_key("c")
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    # Cooperative cancellation: children emit Command.cancel(self)
    cancel_handles = messages
      .select { |m| m.is_a?(RatatuiRuby::Tea::Command::Cancel) }
      .map(&:handle)

    assert_includes cancel_handles, first_wait, "First child should emit Cancel sentinel"
    assert_includes cancel_handles, second_wait, "Second child should emit Cancel sentinel"
  end

  def test_batch_reports_child_errors
    messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    failing_class = Data.define do
      include RatatuiRuby::Tea::Command::Custom
      def call(_out, _token)
        raise "intentional failure"
      end
    end
    failing_command = Ractor.make_shareable(failing_class.new)

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "b"
          cmd = RatatuiRuby::Tea::Command.batch([failing_command])
          [m, cmd]
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
        else [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("b")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    # Child error should surface as Command::Error (aligned with Command.all)
    error_msg = messages.find { |m| m.is_a?(RatatuiRuby::Tea::Command::Error) }
    refute_nil error_msg, "Expected Command::Error message from failed child"
    assert_match(/intentional failure/, error_msg.exception.message)
  end

  def test_batch_exits_early_on_cancellation
    # Stubborn command with long grace — forces the race to be tested
    # Uses Data.define so it's Ractor-shareable
    stubborn_class = Data.define do
      include RatatuiRuby::Tea::Command::Custom
      def tea_cancellation_grace_period = 60.0

      def call(_out, _token)
        sleep 100
      end
    end
    stubborn_command = Ractor.make_shareable(stubborn_class.new)

    batch_cmd = nil
    messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "b"
          batch_cmd = RatatuiRuby::Tea::Command.batch([stubborn_command])
          [m, batch_cmd]
        when "c"
          [m, RatatuiRuby::Tea::Command.cancel(batch_cmd)]
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
        else [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    start = Time.now
    with_test_terminal do
      inject_key("b")
      inject_key("c")
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end
    elapsed = Time.now - start

    # Batch races and exits fast despite stubborn child's 60s grace
    assert_operator elapsed, :<, 2.0, "Batch should exit early on cancellation"

    # Batch emits Cancel sentinel
    cancel_msg = messages.find { |m| m.is_a?(RatatuiRuby::Tea::Command::Cancel) }
    assert_same batch_cmd, cancel_msg&.handle, "Batch should emit Cancel sentinel with self"
  end

  def test_batch_validates_commands_are_shareable
    non_shareable_command = Class.new do
      include RatatuiRuby::Tea::Command::Custom
      def call(_out, _token) = nil
    end.new

    # Should raise at construction time, not later
    assert_raises(RatatuiRuby::Error::Invariant) do
      RatatuiRuby::Tea::Command.batch([non_shareable_command])
    end
  end

  def test_batch_accepts_variadic_args
    cmd1 = Ractor.make_shareable(Data.define { include RatatuiRuby::Tea::Command::Custom; def call(o, _t) = o.put(:a) }.new)
    cmd2 = Ractor.make_shareable(Data.define { include RatatuiRuby::Tea::Command::Custom; def call(o, _t) = o.put(:b) }.new)

    # Both should work: batch([cmd1, cmd2]) AND batch(cmd1, cmd2)
    batch_array = RatatuiRuby::Tea::Command.batch([cmd1, cmd2])
    batch_variadic = RatatuiRuby::Tea::Command.batch(cmd1, cmd2)

    assert_equal 2, batch_array.commands.size
    assert_equal 2, batch_variadic.commands.size

    # Batch.new directly also gets DWIM behavior
    batch_array = RatatuiRuby::Tea::Command::Batch.new(cmd1, cmd2)
    batch_variadic = RatatuiRuby::Tea::Command::Batch.new([cmd1, cmd2])
    assert_equal 2, batch_array.commands.size
    assert_equal 2, batch_variadic.commands.size
  end

  def test_batch_continues_other_commands_when_one_fails
    messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    failing_class = Data.define do
      include RatatuiRuby::Tea::Command::Custom
      def call(_out, _token)
        raise "intentional failure"
      end
    end
    failing_command = Ractor.make_shareable(failing_class.new)

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "b"
          # One fails, one succeeds
          cmd = RatatuiRuby::Tea::Command.batch([
            failing_command,
            RatatuiRuby::Tea::Command.wait(0.01, :success),
          ])
          [m, cmd]
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
        else [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("b")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    # The successful command should still complete
    assert_includes messages, :success, "Successful command should still run when sibling fails"

    # Error should also be reported
    error_msg = messages.find { |m| m.is_a?(RatatuiRuby::Tea::Command::Error) }
    refute_nil error_msg, "Expected Command::Error from failed child"
  end
end
