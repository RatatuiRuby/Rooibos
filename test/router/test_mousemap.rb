# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterMousemap < Minitest::Test
  def test_mousemap_registers_mouse_handlers_that_respond_to_scroll_events
    scroll_up_called = false
    scroll_down_called = false

    test_class = Class.new do
      include Rooibos::Router

      mousemap do |map|
        map.scroll :up, -> { scroll_up_called = true; nil }
        map.scroll :down, -> { scroll_down_called = true; nil }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    # Test scroll up
    scroll_up_event = RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0)
    update.call(scroll_up_event, model)
    assert scroll_up_called, "Scroll up handler should be called"

    # Test scroll down
    scroll_down_event = RatatuiRuby::Event::Mouse.new(kind: "scroll_down", button: "left", x: 0, y: 0)
    update.call(scroll_down_event, model)
    assert scroll_down_called, "Scroll down handler should be called"
  end

  def test_mousemap_delegates_to_named_action
    action_called = false

    test_class = Class.new do
      include Rooibos::Router

      action :scroll_up_action, -> { action_called = true; nil }

      mousemap do |map|
        map.scroll :up, :scroll_up_action # Delegate to action
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)
    scroll_up_event = RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0)

    update.call(scroll_up_event, model)

    assert action_called, "Action should be called via delegation"
  end
end
