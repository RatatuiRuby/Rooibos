# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestClockResponse < Minitest::Test
  def test_clock_has_envelope_and_time
    now = Time.now.freeze
    msg = Rooibos::Message::Clock.new(envelope: :refresh, time: now)

    assert_equal :refresh, msg.envelope
    assert_equal now, msg.time
    assert msg.clock?
  end

  def test_to_sym
    msg = Rooibos::Message::Clock.new(envelope: :clock, time: Time.now)

    assert_equal :message_clock, msg.to_sym
  end

  def test_deconstruct_keys_for_pattern_matching
    now = Time.now.freeze
    msg = Rooibos::Message::Clock.new(envelope: :refresh, time: now)

    case msg
    in { type: :clock, envelope: :refresh, time: }
      assert_equal now, time
    else
      flunk "Pattern match failed"
    end
  end

  def test_timer_predicate_returns_false
    msg = Rooibos::Message::Clock.new(envelope: :clock, time: Time.now)

    refute msg.timer?
  end

  def test_ractor_shareable
    msg = Rooibos::Message::Clock.new(envelope: :refresh, time: Time.now.freeze)

    assert Ractor.shareable?(Ractor.make_shareable(msg))
  end

  def test_symbol_equality
    msg = Rooibos::Message::Clock.new(envelope: :clock, time: Time.now)

    assert_operator msg, :==, :message_clock
    refute_operator msg, :==, :message_timer
  end
end
