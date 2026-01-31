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

  # ============================================================================
  # Scroll Guards (TDD)
  # ============================================================================

  # scroll :up, handler, when: guard - blocks execution when guard returns false
  def test_scroll_guard_blocks_execution_when_guard_returns_false
    handler_called = false
    guard_allows = false

    test_class = Class.new do
      include Rooibos::Router

      mousemap do |map|
        map.scroll :up, -> { handler_called = true; nil }, when: -> (_model) { guard_allows }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)
    scroll_up_event = RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0)

    update.call(scroll_up_event, model)

    refute handler_called, "Handler should NOT be called when guard returns false"
  end

  # scroll :down, handler, when: guard - must also respect guards
  def test_scroll_down_guard_blocks_execution_when_guard_returns_false
    handler_called = false
    guard_allows = false

    test_class = Class.new do
      include Rooibos::Router

      mousemap do |map|
        map.scroll :down, -> { handler_called = true; nil }, when: -> (_model) { guard_allows }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)
    scroll_down_event = RatatuiRuby::Event::Mouse.new(kind: "scroll_down", button: "left", x: 0, y: 0)

    update.call(scroll_down_event, model)

    refute handler_called, "scroll_down handler should NOT be called when guard returns false"
  end

  # scroll guard allows execution when guard returns true
  def test_scroll_guard_allows_execution_when_guard_returns_true
    handler_called = false
    guard_allows = true

    test_class = Class.new do
      include Rooibos::Router

      mousemap do |map|
        map.scroll :up, -> { handler_called = true; nil }, when: -> (_model) { guard_allows }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)
    scroll_up_event = RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0)

    update.call(scroll_up_event, model)

    assert handler_called, "Handler SHOULD be called when guard returns true"
  end

  # unless: inverts the guard logic — blocks when guard returns TRUE
  def test_scroll_unless_guard_blocks_when_guard_returns_true
    handler_called = false
    guard_blocks = true # unless this is true, skip the handler

    test_class = Class.new do
      include Rooibos::Router

      mousemap do |map|
        map.scroll :up, -> { handler_called = true; nil }, unless: -> (_model) { guard_blocks }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)
    scroll_up_event = RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0)

    update.call(scroll_up_event, model)

    refute handler_called, "Handler should NOT be called when unless: guard returns true"
  end

  # if: is an alias for when:
  def test_scroll_if_alias_blocks_when_guard_returns_false
    handler_called = false
    guard_allows = false

    test_class = Class.new do
      include Rooibos::Router

      mousemap do |map|
        map.scroll :up, -> { handler_called = true; nil }, if: -> (_model) { guard_allows }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)
    scroll_up_event = RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0)

    update.call(scroll_up_event, model)

    refute handler_called, "if: should work like when: — blocks when false"
  end

  # ============================================================================
  # Click Guards (TDD)
  # ============================================================================

  # click handler, when: guard - blocks execution when guard returns false
  def test_click_guard_blocks_execution_when_guard_returns_false
    handler_called = false
    guard_allows = false

    test_class = Class.new do
      include Rooibos::Router

      mousemap do |map|
        map.click -> (x, y) { handler_called = true; nil }, when: -> (_model) { guard_allows }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)
    click_event = RatatuiRuby::Event::Mouse.new(kind: "down", button: "left", x: 10, y: 20)

    update.call(click_event, model)

    refute handler_called, "Click handler should NOT be called when guard returns false"
  end

  # click guard allows execution when guard returns true
  def test_click_guard_allows_execution_when_guard_returns_true
    handler_called = false
    guard_allows = true

    test_class = Class.new do
      include Rooibos::Router

      mousemap do |map|
        map.click -> (x, y) { handler_called = true; nil }, when: -> (_model) { guard_allows }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)
    click_event = RatatuiRuby::Event::Mouse.new(kind: "down", button: "left", x: 10, y: 20)

    update.call(click_event, model)

    assert handler_called, "Click handler SHOULD be called when guard returns true"
  end

  # ============================================================================
  # Scoped Guard Blocks (TDD)
  # ============================================================================

  # map.only when: guard { ... } applies guard to all handlers in block
  def test_only_scoped_guard_blocks_all_handlers_when_false
    scroll_up_called = false
    scroll_down_called = false
    guard_allows = false

    test_class = Class.new do
      include Rooibos::Router

      mousemap do |map|
        map.only when: -> (_model) { guard_allows } do
          map.scroll :up, -> { scroll_up_called = true; nil }
          map.scroll :down, -> { scroll_down_called = true; nil }
        end
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0), model)
    update.call(RatatuiRuby::Event::Mouse.new(kind: "scroll_down", button: "left", x: 0, y: 0), model)

    refute scroll_up_called, "scroll_up inside only block should NOT be called when guard is false"
    refute scroll_down_called, "scroll_down inside only block should NOT be called when guard is false"
  end

  # map.only when: guard { ... } also applies to click handlers
  def test_only_scoped_guard_blocks_click_handler_when_false
    click_called = false
    guard_allows = false

    test_class = Class.new do
      include Rooibos::Router

      mousemap do |map|
        map.only when: -> (_model) { guard_allows } do
          map.click -> (x, y) { click_called = true; nil }
        end
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Mouse.new(kind: "down", button: "left", x: 10, y: 20), model)

    refute click_called, "click inside only block should NOT be called when guard is false"
  end

  # map.skip when: guard { ... } inverts (blocks when true)
  def test_skip_scoped_guard_blocks_when_guard_returns_true
    scroll_up_called = false
    guard_blocks = true # skip blocks when this is true

    test_class = Class.new do
      include Rooibos::Router

      mousemap do |map|
        map.skip when: -> (_model) { guard_blocks } do
          map.scroll :up, -> { scroll_up_called = true; nil }
        end
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0), model)

    refute scroll_up_called, "scroll_up inside skip block should NOT be called when guard is true"
  end

  # Nested scoped guards are combined (all must pass)
  def test_nested_scoped_guards_are_combined
    scroll_up_called = false
    outer_allows = true
    inner_allows = false

    test_class = Class.new do
      include Rooibos::Router

      mousemap do |map|
        map.only when: -> (_model) { outer_allows } do
          map.only when: -> (_model) { inner_allows } do
            map.scroll :up, -> { scroll_up_called = true; nil }
          end
        end
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0), model)

    refute scroll_up_called, "Nested guards must ALL pass — inner guard is false so handler should NOT be called"
  end
end
