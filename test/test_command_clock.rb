# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestCommandClock < Minitest::Test
  include Rooibos::TestHelper

  def setup
    @@messages = []
  end

  def teardown
    @@messages = []
  end

  ClearView = -> (_m, t) { t.clear }

  ClockUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "c" then [m, Rooibos::Command.clock(0.05, :clocked)]
      when "q" then [m, Rooibos::Command.exit]
      else [m, nil]
      end
    else
      TestCommandClock.class_variable_get(:@@messages) << msg
      [m, nil]
    end
  end

  def test_clock_message_arrives_in_update
    model = Ractor.make_shareable({})

    with_test_terminal do
      inject_key("c")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view: ClearView, update: ClockUpdate)
    end

    assert_no_errors(@@messages)

    clock_msg = @@messages.find { |m| m.is_a?(Rooibos::Message::Clock) }
    refute_nil clock_msg, "Should receive Clock message"
    assert_equal :clocked, clock_msg.envelope
    assert_instance_of Time, clock_msg.time
  end

  CancelClockUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "c"
        cmd = Rooibos::Command.clock(10.0, :should_not_arrive)
        [Ractor.make_shareable({ cmd: }), cmd]
      when "x"
        [m, Rooibos::Command.cancel(m[:cmd])]
      else
        [m, nil]
      end
    when Rooibos::Message::Canceled
      TestCommandClock.class_variable_get(:@@messages) << msg
      [m, Rooibos::Command.exit]
    else
      TestCommandClock.class_variable_get(:@@messages) << msg
      [m, nil]
    end
  end

  def test_canceled_clock_sends_canceled_not_clock
    model = Ractor.make_shareable({ cmd: nil })

    with_test_terminal do
      inject_key("c")
      inject_key("x")
      Rooibos::Runtime.run(model:, view: ClearView, update: CancelClockUpdate)
    end

    cancel_msg = @@messages.find { |m| m.is_a?(Rooibos::Message::Canceled) }
    refute_nil cancel_msg, "Should receive Canceled message"
    clock_msgs = @@messages.select { |m| m.is_a?(Rooibos::Message::Clock) }
    assert_empty clock_msgs, "Should not receive Clock message when canceled"
  end

  def test_clock_grace_period_is_zero
    cmd = Rooibos::Command.clock(1.0, :test)

    assert_equal 0, cmd.rooibos_cancellation_grace_period
  end
end
