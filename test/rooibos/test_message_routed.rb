# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "../test_helper"
require "rooibos"

# Tests for Message::Routed - messages synthesized by Router keymap
class TestMessageRouted < Minitest::Test
  def test_routed_exists_with_envelope
    msg = Rooibos::Message::Routed.new(envelope: :move_down, event: nil)
    assert_equal :move_down, msg.envelope
  end

  def test_hash_pattern_matching
    msg = Rooibos::Message::Routed.new(envelope: :move_down, event: nil)
    matched = case msg
    in { type: :routed, envelope: :move_down }
      true
    else
      false
    end
    assert matched, "Message::Routed should match { type: :routed, envelope: :move_down }"
  end

  def test_predicates
    msg = Rooibos::Message::Routed.new(envelope: :move_down, event: nil)
    assert_predicate msg, :routed?, "Message::Routed should be routed?"
    assert_predicate msg, :move_down?, "Message::Routed should be move_down?"
    refute_predicate msg, :move_up?, "Message::Routed should not be move_up?"
  end

  def test_passes_event_if_present
    msg = Rooibos::Message::Routed.new(envelope: :move_down, event: RatatuiRuby::Event::Resize.new(width: 80, height: 24))
    matched = false
    case msg
    in { type: :routed, envelope: :move_down, event: RatatuiRuby::Event::Resize }
      matched = true
    end
    assert matched, "Message::Routed event should be pattern-matchable"
    assert_equal RatatuiRuby::Event::Resize.new(width: 80, height: 24), msg.event
  end
end
