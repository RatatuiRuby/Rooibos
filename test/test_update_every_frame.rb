# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestUpdateEveryFrame < Minitest::Test
  include Rooibos::TestHelper

  def setup
    @@none_count = 0
  end

  # Update that counts None events, exits on "q" or after 3 None events
  NoneCountingUpdate = -> (msg, model) do
    if msg.none?
      count = TestUpdateEveryFrame.class_variable_get(:@@none_count) + 1
      TestUpdateEveryFrame.class_variable_set(:@@none_count, count)
      [model, (count >= 3) ? Rooibos::Command.exit : nil]
    elsif msg.key? && msg.q?
      [model, Rooibos::Command.exit]
    else
      [model, nil]
    end
  end

  def test_none_events_reach_update_when_enabled
    model = Ractor.make_shareable({ idle_frames: 0 }, copy: true)

    with_test_terminal do
      3.times { inject_event(RatatuiRuby::Event::None.new) }
      Rooibos::Runtime.run(model:, view: ClearView, update: NoneCountingUpdate,
        update_every_frame: true)
    end

    assert_equal 3, @@none_count, "Update should have received 3 None events"
  end

  def test_none_events_are_dropped_by_default
    model = Ractor.make_shareable({ idle_frames: 0 }, copy: true)

    with_test_terminal do
      inject_event(RatatuiRuby::Event::None.new)
      inject_event(RatatuiRuby::Event::None.new)
      inject_key("q")
      Rooibos::Runtime.run(model:, view: ClearView, update: NoneCountingUpdate)
    end

    assert_equal 0, @@none_count,
      "Update should not receive None events when update_every_frame is disabled"
  end
end
