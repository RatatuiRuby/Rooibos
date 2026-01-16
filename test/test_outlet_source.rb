# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "ratatui_ruby/test_helper"

# Integration tests for Outlet#source demonstrating command composition.
#
# These tests serve as documentation for app developers who need to
# orchestrate multi-step workflows within custom commands.
class TestOutletSource < Minitest::Test
  include RatatuiRuby::TestHelper

  # A command that fetches a result, then uses it for a second fetch.
  # Demonstrates the basic source pattern: call a child command,
  # wait for its result, then continue processing.
  TwoStepFetch = Data.define do
    include Rooibos::Command::Custom

    def call(out, token)
      # Step 1: Get first value
      step1_result = out.source(StepOneCommand.new, token)
      return if step1_result.nil?

      # Step 2: Use it to get second value
      step2_result = out.source(StepTwoCommand.new(step1_result), token)
      return if step2_result.nil?

      # Final output - must be Ractor-shareable for debug mode
      out.put(:two_step_complete, Ractor.make_shareable({ step1: step1_result, step2: step2_result }))
    end
  end

  StepOneCommand = Data.define do
    include Rooibos::Command::Custom

    def call(out, _token)
      out.put(:step_one_value, 42)
    end
  end

  StepTwoCommand = Data.define(:input) do
    include Rooibos::Command::Custom

    def call(out, _token)
      # Double the input value
      out.put(:step_two_value, input.last * 2)
    end
  end

  def test_source_orchestrates_multi_step_commands
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s" then [m, TwoStepFetch.new]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        received_messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")  # Start two-step fetch
      inject_sync      # Wait for command to complete
      inject_key("q")  # Quit

      Rooibos::Runtime.run(model:, view:, update:)
    end

    # The final composed result should arrive
    final = received_messages.find { |m| m.is_a?(Array) && m.first == :two_step_complete }
    assert final, "Should receive composed result, got: #{received_messages.inspect}"
    assert_equal({ step1: [:step_one_value, 42], step2: [:step_two_value, 84] }, final.last)
  end

  # A command that bails out when cancellation is detected.
  # Demonstrates how source returns nil on cancellation, allowing
  # the parent command to clean up and exit gracefully.
  CancellableMultiStep = Data.define do
    include Rooibos::Command::Custom

    def call(out, token)
      out.put(:multi_step_started)

      # This step takes a while
      result = out.source(SlowCommand.new, token)

      if result.nil?
        out.put(:multi_step_cancelled)
        return
      end

      out.put(:multi_step_finished, result)
    end
  end

  SlowCommand = Data.define do
    include Rooibos::Command::Custom

    def call(out, token)
      sleep 0.02 until token.canceled?
      # If cancelled, never puts, so source returns nil
    end
  end

  def test_source_returns_nil_when_parent_cancelled
    received_messages = []
    model = Ractor.make_shareable({ cmd: nil })
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s"
          cmd = CancellableMultiStep.new
          [Ractor.make_shareable({ cmd: }), cmd]
        when "c"
          [m, Rooibos::Command.cancel(m[:cmd])]
        when "q"
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        received_messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")  # Start multi-step command
      inject_key("c")  # Cancel it
      inject_key("q")  # Quit

      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_includes received_messages, :multi_step_started
    assert_includes received_messages, :multi_step_cancelled
    refute received_messages.any? { |m| m.is_a?(Array) && m.first == :multi_step_finished }
  end

  # A command that handles exceptions from child commands.
  # Demonstrates how source propagates exceptions, allowing the
  # parent to catch and handle them appropriately.
  ResilientFetch = Data.define do
    include Rooibos::Command::Custom

    def call(out, token)
      out.source(FailingCommand.new, token, timeout: 0.5)
      out.put(:should_not_reach)
    rescue ArgumentError => e
      out.put(:error_handled, Ractor.make_shareable({ message: e.message.freeze }))
    end
  end

  FailingCommand = Data.define do
    include Rooibos::Command::Custom

    def call(_out, _token)
      raise ArgumentError, "simulated failure"
    end
  end

  def test_source_propagates_exceptions_for_handling
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s" then [m, ResilientFetch.new]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        received_messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")

      Rooibos::Runtime.run(model:, view:, update:)
    end

    error_msg = received_messages.find { |m| m.is_a?(Array) && m.first == :error_handled }
    refute_nil error_msg, "Parent should catch and handle the exception"
    assert_equal "simulated failure", error_msg.last[:message]
    refute received_messages.include?(:should_not_reach)
  end

  # A command that respects a timeout when child command hangs.
  # Demonstrates how timeout prevents indefinite blocking.
  TimeoutAwareFetch = Data.define do
    include Rooibos::Command::Custom

    def call(out, token)
      result = out.source(HungCommand.new, token, timeout: 0.05)

      if result.nil?
        out.put(:fetch_timed_out)
      else
        out.put(:fetch_succeeded, result)
      end
    end
  end

  HungCommand = Data.define do
    include Rooibos::Command::Custom

    def call(_out, _token)
      sleep 10 # Never completes
    end
  end

  def test_source_times_out_with_timeout
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s" then [m, TimeoutAwareFetch.new]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        received_messages << msg
        [m, nil]
      end
    end

    start_time = Time.now

    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")

      Rooibos::Runtime.run(model:, view:, update:)
    end

    elapsed = Time.now - start_time

    assert_includes received_messages, :fetch_timed_out
    assert_operator elapsed, :<, 1.0, "Should timeout quickly, not wait 10s"
  end
end
