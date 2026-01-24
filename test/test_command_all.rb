# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestCommandAll < Minitest::Test
  include Rooibos::TestHelper

  def test_all_validates_commands_are_shareable
    non_shareable_command = Class.new do
      include Rooibos::Command::Custom
      def call(_out, _token) = nil
    end.new

    assert_raises(Rooibos::Error::Invariant) do
      Rooibos::Command.all(:tag, [non_shareable_command])
    end
  end

  def test_all_has_envelope_accessor
    wait_cmd = Data.define do
      include Rooibos::Command::Custom
      def call(out, _token)
        out.put(:done)
      end
    end.new
    cmd = Rooibos::Command.all(:my_envelope, [Ractor.make_shareable(wait_cmd)])
    assert_equal :my_envelope, cmd.envelope
  end

  def test_all_with_empty_commands_returns_empty_results_immediately
    messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "a"
          # Dynamic filter that results in empty array - common pattern
          cmd = Rooibos::Command.all(:empty, [].filter { |c| c })
          [m, cmd]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("a")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(messages)

    # Should get Message::All with empty results, not hang forever
    all_msg = messages.find { |m| m.is_a?(Rooibos::Message::All) }
    refute_nil all_msg, "Expected Message::All from Command.all with empty commands. Got: #{messages.inspect}"
    assert_equal :empty, all_msg.envelope
    assert_equal [], all_msg.results, "Empty commands should return empty results"
    assert all_msg.nested, "Array syntax should produce nested: true"
  end

  def test_all_skips_validation_when_debug_disabled
    RatatuiRuby::Debug.suppress_debug_mode do
      non_shareable_command = Class.new do
        include Rooibos::Command::Custom
        def call(_out, _token) = nil
      end.new

      # Should NOT raise when debug is disabled
      Rooibos::Command.all(:tag, [non_shareable_command])
    end
  end

  def test_all_aggregates_child_results_nested
    messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "a"
          cmd = Rooibos::Command.all(:dashboard, [
            Rooibos::Command.wait(0.01, :first),
            Rooibos::Command.wait(0.01, :second),
          ])
          [m, cmd]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("a")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(messages)

    all_msg = messages.find { |m| m.is_a?(Rooibos::Message::All) }
    refute_nil all_msg, "Expected Message::All from Command.all"

    assert_equal :dashboard, all_msg.envelope
    assert_kind_of Array, all_msg.results
    assert_equal 2, all_msg.results.size
    assert all_msg.nested, "Array syntax should produce nested: true"
  end

  def test_all_splats_results_with_variadic_args
    messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "a"
          # Variadic syntax → splatted output
          cmd = Rooibos::Command.all(:dashboard,
            Rooibos::Command.wait(0.01, :first),
            Rooibos::Command.wait(0.01, :second),
          )
          [m, cmd]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("a")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(messages)

    # Variadic produces Message::All with nested: false
    all_msg = messages.find { |m| m.is_a?(Rooibos::Message::All) }
    refute_nil all_msg, "Expected Message::All from Command.all"

    # Variadic: Message::All with nested: false, results contain the child messages
    assert_equal :dashboard, all_msg.envelope
    refute all_msg.nested, "Variadic syntax should produce nested: false"
    assert_equal 2, all_msg.results.size
    assert_kind_of Rooibos::Message::Timer, all_msg.results[0]
    assert_kind_of Rooibos::Message::Timer, all_msg.results[1]
    assert_equal :first, all_msg.results[0].envelope
    assert_equal :second, all_msg.results[1].envelope
  end

  def test_all_emits_cancel_sentinel_on_cancellation
    messages = []
    all_cmd = nil
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "a"
          all_cmd = Rooibos::Command.all(:dashboard, [
            Rooibos::Command.wait(10.0, :should_not_arrive),
          ])
          [m, all_cmd]
        when "c"
          [m, Rooibos::Command.cancel(all_cmd)]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("a")
      inject_key("c")
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    # Note: This test expects Message::Canceled, not Message::Error
    cancel_msg = messages.find { |m| m.is_a?(Rooibos::Message::Canceled) }
    assert_same all_cmd, cancel_msg&.command, "Expected Canceled message with self as command"
  end

  def test_all_runs_commands_in_parallel
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "a"
          # Two 0.1s waits — sequential = 0.2s, parallel < 0.15s
          cmd = Rooibos::Command.all(:dashboard, [
            Rooibos::Command.wait(0.1, :first),
            Rooibos::Command.wait(0.1, :second),
          ])
          [m, cmd]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        [m, nil]
      end
    end

    start = Time.now
    with_test_terminal do
      inject_key("a")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end
    elapsed = Time.now - start

    # Parallel execution: both 0.1s waits overlap, total < 0.15s
    # Sequential execution: 0.1 + 0.1 = 0.2s minimum
    assert_operator elapsed, :<, 0.15, "Command.all should run commands in parallel, not sequentially"
  end

  def test_all_emits_message_all_for_nested_syntax
    messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "a"
          cmd = Rooibos::Command.all(:dashboard, [
            Rooibos::Command.wait(0.01, :first),
            Rooibos::Command.wait(0.01, :second),
          ])
          [m, cmd]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("a")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(messages)

    # Command.all should emit Message::All, not raw arrays
    all_msg = messages.find { |m| m.is_a?(Rooibos::Message::All) }
    refute_nil all_msg, "Expected Message::All from Command.all, got: #{messages.inspect}"

    # Verify hash-based pattern matching works
    case all_msg
    in { type: :all, envelope: :dashboard, results:, nested: true }
      assert_equal 2, results.size
      assert_kind_of Rooibos::Message::Timer, results[0]
      assert_kind_of Rooibos::Message::Timer, results[1]
    else
      flunk "Message::All should match hash pattern { type: :all, envelope:, results:, nested: }"
    end
  end

  def test_all_reports_child_errors
    messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    failing_class = Data.define do
      include Rooibos::Command::Custom
      def call(_out, _token)
        raise "intentional failure"
      end
    end
    failing_command = Ractor.make_shareable(failing_class.new)

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "a"
          cmd = Rooibos::Command.all(:dashboard, [failing_command])
          [m, cmd]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("a")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    # Child error should surface as Message::Error
    error_msg = messages.find { |m| m.is_a?(Rooibos::Message::Error) }
    refute_nil error_msg, "Expected Message::Error message from failed child"
    assert_match(/intentional failure/, error_msg.exception.message)
  end

  # Demonstrate that Command.all works with heterogeneous command types.
  # This test verifies parallel execution across different command categories
  # and that each result correctly matches the { type:, envelope: } pattern.
  def test_all_with_mixed_command_types
    messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "a"
          cmd = Rooibos::Command.all(:dashboard,
            Rooibos::Command.wait(0.01, :timer_result),
            Rooibos::Command.system("echo mixed", :shell_result),
          )
          [m, cmd]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("a")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(messages)

    all_msg = messages.find { |m| m.is_a?(Rooibos::Message::All) }
    refute_nil all_msg, "Expected Message::All from Command.all with mixed types"

    assert_equal :dashboard, all_msg.envelope
    assert_equal 2, all_msg.results.size

    # First result should be a Timer message
    timer_result = all_msg.results.find { |r| r.is_a?(Rooibos::Message::Timer) }
    refute_nil timer_result, "Expected Timer result in aggregated results"
    assert_equal :timer_result, timer_result.envelope

    # Second result should be a System::Batch message
    system_result = all_msg.results.find { |r| r.is_a?(Rooibos::Message::System::Batch) }
    refute_nil system_result, "Expected System::Batch result in aggregated results"
    assert_equal :shell_result, system_result.envelope
    assert_equal 0, system_result.status
    assert_match(/mixed/, system_result.stdout)

    # Verify hash pattern matching works for heterogeneous results
    all_msg.results.each do |result|
      case result
      in { type: :timer, envelope:, elapsed: _ }
        assert_equal :timer_result, envelope
      in { type: :system, envelope:, stdout: _, status: 0 }
        assert_equal :shell_result, envelope
      else
        flunk "Unexpected result type in mixed Command.all: #{result.class}"
      end
    end
  end
end
