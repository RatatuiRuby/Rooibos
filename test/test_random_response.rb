# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRandomResponse < Minitest::Test
  def test_random_has_envelope_and_value
    msg = Rooibos::Message::Random.new(envelope: :roll, value: 4)

    assert_equal :roll, msg.envelope
    assert_equal 4, msg.value
    assert msg.random?
  end

  def test_to_sym
    msg = Rooibos::Message::Random.new(envelope: :roll, value: 0.5)

    assert_equal :message_random, msg.to_sym
  end

  def test_deconstruct_keys_for_pattern_matching
    msg = Rooibos::Message::Random.new(envelope: :die, value: 4)

    case msg
    in { type: :random, envelope: :die, value: }
      assert_equal 4, value
    else
      flunk "Pattern match failed"
    end
  end

  def test_clock_predicate_returns_false
    msg = Rooibos::Message::Random.new(envelope: :roll, value: 0.5)

    refute msg.clock?
  end

  def test_ractor_shareable
    msg = Rooibos::Message::Random.new(envelope: :roll, value: 0.42)

    assert Ractor.shareable?(Ractor.make_shareable(msg))
  end

  def test_symbol_equality
    msg = Rooibos::Message::Random.new(envelope: :roll, value: 0.5)

    assert_operator msg, :==, :message_random
    refute_operator msg, :==, :message_clock
  end
end
