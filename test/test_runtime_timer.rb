# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestRuntimeTimer < Minitest::Test
  include Rooibos::TestHelper

  # Class-scope state for lambda-based updates
  def setup
    @@messages = []
    @@original_cmd = nil
  end

  def teardown
    @@messages = []
    @@original_cmd = nil
  end

  ClearView = -> (_m, t) { t.clear }

  # Timer update for wait/tick tests
  TimerUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "w" then [m, Rooibos::Command.wait(0.05, :waited)]
      when "t" then [m, Rooibos::Command.tick(0.05, :ticked)]
      when "q" then [m, Rooibos::Command.exit]
      else [m, nil]
      end
    else
      TestRuntimeTimer.class_variable_get(:@@messages) << msg
      [m, nil]
    end
  end

  def test_wait_message_arrives_in_update
    model = Ractor.make_shareable({})

    view = ClearView
    update = TimerUpdate

    with_test_terminal do
      inject_key("w")
      inject_sync # Wait for command to complete
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(@@messages)

    # Should receive TimerResponse, not bare tag
    timer_msg = @@messages.find { |m| m.is_a?(Rooibos::Message::Timer) }
    refute_nil timer_msg, "Should receive TimerResponse"
    assert_equal :waited, timer_msg.envelope
    assert_operator timer_msg.elapsed, :>=, 0.05
  end

  def test_tick_message_arrives_in_update
    model = Ractor.make_shareable({})

    view = ClearView
    update = TimerUpdate

    with_test_terminal do
      inject_key("t")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(@@messages)

    # Should receive TimerResponse, not bare tag
    timer_msg = @@messages.find { |m| m.is_a?(Rooibos::Message::Timer) }
    refute_nil timer_msg, "Should receive TimerResponse"
    assert_equal :ticked, timer_msg.envelope
  end

  # CancelUpdate for timer cancellation tests
  CancelWaitUpdate = -> (msg, m) do
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
      TestRuntimeTimer.class_variable_get(:@@messages) << msg
      [m, nil]
    end
  end

  def test_wait_returns_quickly_when_canceled
    model = Ractor.make_shareable({ cmd: nil })

    view = ClearView
    update = CancelWaitUpdate

    start = Time.now
    with_test_terminal do
      inject_key("w")  # Start 10s wait
      inject_key("c")  # Cancel immediately
      inject_key("q")  # Quit
      Rooibos::Runtime.run(model:, view:, update:)
    end
    elapsed = Time.now - start

    # Must return quickly (< 5s), not wait full 10s
    assert_operator elapsed, :<, 5.0, "Canceled wait should return quickly, not block for grace period"
    refute @@messages.include?(:should_not_arrive), "No timeout message when canceled"
  end

  # AckUpdate for canceled wait acknowledgment test
  AckUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "w"
        cmd = Rooibos::Command.wait(1.0, :timeout)
        TestRuntimeTimer.class_variable_set(:@@original_cmd, cmd)
        [Ractor.make_shareable({ cmd: }), cmd]
      when "c"
        [m, Rooibos::Command.cancel(m[:cmd])]
      when "q"
        [m, Rooibos::Command.exit]
      else
        [m, nil]
      end
    else
      TestRuntimeTimer.class_variable_get(:@@messages) << msg
      [m, nil]
    end
  end

  def test_canceled_wait_acknowledges_cancellation
    model = Ractor.make_shareable({ cmd: nil })

    view = ClearView
    update = AckUpdate

    with_test_terminal(timeout: 5) do
      inject_key("w")  # Start 1s wait
      inject_key("c")  # Cancel it before it completes
      # Wait.rooibos_cancellation_grace_period is 0, so cancel removes the
      # future from @pending_futures immediately. inject_sync would have
      # nothing to wait on. Give the background thread time to wake from
      # combined.origin.wait and push Message::Canceled to the channel.
      sleep 3
      inject_key("q") # Quit
      Rooibos::Runtime.run(model:, view:, update:)
    end

    # Cooperative cancellation sends Message::Canceled; thread-kill sends nothing
    cancel_msg = @@messages.find { |m| m.is_a?(Rooibos::Message::Canceled) }
    refute_nil cancel_msg, "Should receive a Canceled message"
    assert_same @@original_cmd, cancel_msg.command, "Canceled message wraps the original command as .command"
  end
end
