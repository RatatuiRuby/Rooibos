# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestTimerResponse < Minitest::Test
  def test_timer_predicate_returns_true
    msg = RatatuiRuby::Tea::Message::TimerResponse.new(envelope: :dismiss, elapsed: 3.0)

    assert msg.timer?, "TimerResponse should return true for timer?"
  end

  def test_deconstruct_keys_for_pattern_matching
    msg = RatatuiRuby::Tea::Message::TimerResponse.new(envelope: :animate, elapsed: 0.5)

    case msg
    in { type: :timer, envelope: :animate, elapsed: }
      assert_in_delta 0.5, elapsed
    else
      flunk "Pattern match failed"
    end
  end
end
