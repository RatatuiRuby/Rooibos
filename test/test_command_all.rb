# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "ratatui_ruby/test_helper"

class TestCommandAll < Minitest::Test
  include RatatuiRuby::TestHelper

  def test_all_validates_commands_are_shareable
    non_shareable_command = Class.new do
      include RatatuiRuby::Tea::Command::Custom
      def call(_out, _token) = nil
    end.new

    assert_raises(RatatuiRuby::Error::Invariant) do
      RatatuiRuby::Tea::Command.all(:tag, [non_shareable_command])
    end
  end

  def test_all_skips_validation_when_debug_disabled
    RatatuiRuby::Debug.suppress_debug_mode do
      non_shareable_command = Class.new do
        include RatatuiRuby::Tea::Command::Custom
        def call(_out, _token) = nil
      end.new

      # Should NOT raise when debug is disabled
      RatatuiRuby::Tea::Command.all(:tag, [non_shareable_command])
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
          cmd = RatatuiRuby::Tea::Command.all(:dashboard, [
            RatatuiRuby::Tea::Command.wait(0.01, :first),
            RatatuiRuby::Tea::Command.wait(0.01, :second),
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
      inject_key("a")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    all_msg = messages.find { |m| m.is_a?(Array) && m[0] == :dashboard }
    refute_nil all_msg, "Expected [:dashboard, [...]] message from Command.all"

    results = all_msg[1]
    assert_kind_of Array, results
    assert_equal 2, results.size
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
          cmd = RatatuiRuby::Tea::Command.all(:dashboard,
            RatatuiRuby::Tea::Command.wait(0.01, :first),
            RatatuiRuby::Tea::Command.wait(0.01, :second),
          )
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
      inject_key("a")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    # Variadic produces [:dashboard, result1, result2] (splatted)
    all_msg = messages.find { |m| m.is_a?(Array) && m[0] == :dashboard }
    refute_nil all_msg, "Expected [:dashboard, ...] message from Command.all"

    # Splatted: [:dashboard, :first, :second] (not [:dashboard, [:first, :second]])
    assert_equal 3, all_msg.size, "Expected 3 elements (tag + 2 splatted results)"
    assert_equal :first, all_msg[1]
    assert_equal :second, all_msg[2]
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
          all_cmd = RatatuiRuby::Tea::Command.all(:dashboard, [
            RatatuiRuby::Tea::Command.wait(10.0, :should_not_arrive),
          ])
          [m, all_cmd]
        when "c"
          [m, RatatuiRuby::Tea::Command.cancel(all_cmd)]
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
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
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    cancel_msg = messages.find { |m| m.is_a?(RatatuiRuby::Tea::Command::Cancel) }
    assert_same all_cmd, cancel_msg&.handle, "Expected Cancel sentinel with self as handle"
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
          cmd = RatatuiRuby::Tea::Command.all(:dashboard, [
            RatatuiRuby::Tea::Command.wait(0.1, :first),
            RatatuiRuby::Tea::Command.wait(0.1, :second),
          ])
          [m, cmd]
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
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
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end
    elapsed = Time.now - start

    # Parallel execution: both 0.1s waits overlap, total < 0.15s
    # Sequential execution: 0.1 + 0.1 = 0.2s minimum
    assert_operator elapsed, :<, 0.15, "Command.all should run commands in parallel, not sequentially"
  end

  def test_all_reports_child_errors
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
        when "a"
          cmd = RatatuiRuby::Tea::Command.all(:dashboard, [failing_command])
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
      inject_key("a")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    # Child error should surface as Command::Error
    error_msg = messages.find { |m| m.is_a?(RatatuiRuby::Tea::Command::Error) }
    refute_nil error_msg, "Expected Command::Error message from failed child"
    assert_match(/intentional failure/, error_msg.exception.message)
  end
end
