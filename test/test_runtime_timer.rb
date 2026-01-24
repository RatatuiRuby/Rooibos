# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestRuntimeTimer < Minitest::Test
  include Rooibos::TestHelper

  def test_wait_message_arrives_in_update
    messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "w" then [m, Rooibos::Command.wait(0.05, :waited)]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("w")
      inject_sync # Wait for command to complete
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_command_errors(messages)

    # Should receive TimerResponse, not bare tag
    timer_msg = messages.find { |m| m.is_a?(Rooibos::Message::Timer) }
    refute_nil timer_msg, "Should receive TimerResponse"
    assert_equal :waited, timer_msg.envelope
    assert_operator timer_msg.elapsed, :>=, 0.05
  end

  def test_tick_message_arrives_in_update
    messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "t" then [m, Rooibos::Command.tick(0.05, :ticked)]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("t")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_command_errors(messages)

    # Should receive TimerResponse, not bare tag
    timer_msg = messages.find { |m| m.is_a?(Rooibos::Message::Timer) }
    refute_nil timer_msg, "Should receive TimerResponse"
    assert_equal :ticked, timer_msg.envelope
  end

  def test_wait_returns_quickly_when_cancelled
    messages = []
    model = Ractor.make_shareable({ cmd: nil })
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "w"
          # 10 second wait — if naive sleep, grace period = 10s = slow
          cmd = Rooibos::Command.wait(10.0, :should_not_arrive)
          [Ractor.make_shareable({ cmd: }), cmd]
        when "c"
          [m, Rooibos::Command.cancel(m[:cmd])]
        when "q"
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    start = Time.now
    with_test_terminal do
      inject_key("w")  # Start 10s wait
      inject_key("c")  # Cancel immediately
      inject_key("q")  # Quit
      Rooibos::Runtime.run(model:, view:, update:)
    end
    elapsed = Time.now - start

    # Must return quickly (< 2s), not wait full 10s
    assert_operator elapsed, :<, 2.0, "Cancelled wait should return quickly, not block for grace period"
    refute messages.include?(:should_not_arrive), "No timeout message when cancelled"
  end

  def test_cancelled_wait_acknowledges_cancellation
    messages = []
    original_cmd = nil
    model = Ractor.make_shareable({ cmd: nil })
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "w"
          cmd = Rooibos::Command.wait(10.0, :timeout)
          original_cmd = cmd
          [Ractor.make_shareable({ cmd: }), cmd]
        when "c"
          [m, Rooibos::Command.cancel(m[:cmd])]
        when "q"
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("w")  # Start 10s wait
      inject_key("c")  # Cancel it
      inject_key("q")  # Quit
      Rooibos::Runtime.run(model:, view:, update:)
    end

    # Cooperative cancellation sends Command.cancel(self); thread-kill sends nothing
    cancel_msg = messages.find { |m| m.is_a?(Rooibos::Command::Cancel) }
    refute_nil cancel_msg, "Should receive a Cancel message"
    assert_same original_cmd, cancel_msg.handle, "Cancel sentinel wraps the original command as .handle"
  end
end
