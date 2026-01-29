# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterAction < Minitest::Test
  # Fake child module for testing
  module FakeChild
    INITIAL = :child_initial
    Update = -> (msg, model) { [model, nil] }
  end

  # action defines a named action that can be referenced by keymap/mousemap.
  # Actions are normalized via .to_s.to_sym.
  def test_action_defines_named_action
    handler = -> { [:scroll, -1] }

    test_class = Class.new do
      include Rooibos::Router

      action :scroll_up, handler
      action "scroll_down", -> { [:scroll, 1] } # String works too
    end

    assert_equal handler, test_class.actions[:scroll_up]
    assert test_class.actions[:scroll_down].is_a?(Proc)
  end

  def test_action_keyword_syntax_with_handler
    handler = -> { [:scroll, -1] }

    test_class = Class.new do
      include Rooibos::Router

      action scroll_up: handler
    end

    assert_equal handler, test_class.actions[:scroll_up]
  end

  # action with Module value registers as routed action
  def test_action_with_module_registers_routed_action
    test_class = Class.new do
      include Rooibos::Router

      action go_back: TestRouterAction::FakeChild
    end

    assert_equal FakeChild, test_class.routed_actions[:go_back]
  end

  # action with keymap: option registers key bindings
  def test_action_keymap_option_registers_keys
    handler_called = false

    test_class = Class.new do
      include Rooibos::Router

      action scroll_up: -> { handler_called = true; nil }, keymap: %i[up k]
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    # Test 'up' key
    update.call(RatatuiRuby::Event::Key.new(code: "up"), model)
    assert handler_called, "'up' key should trigger scroll_up action"

    # Test 'k' key
    handler_called = false
    update.call(RatatuiRuby::Event::Key.new(code: "k"), model)
    assert handler_called, "'k' key should also trigger scroll_up action"
  end

  # action accepts key: as singular alias for keymap:
  def test_action_key_alias_for_keymap
    handler_called = false

    test_class = Class.new do
      include Rooibos::Router

      action quit: -> { handler_called = true; nil }, key: :q
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)
    assert handler_called, "key: should work as keymap: alias"
  end

  # action accepts keys: as plural alias for keymap:
  def test_action_keys_alias_for_keymap
    handler_called = false

    test_class = Class.new do
      include Rooibos::Router

      action move: -> { handler_called = true; nil }, keys: %i[down j]
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "down"), model)
    assert handler_called, "'down' key via keys: should work"

    handler_called = false
    update.call(RatatuiRuby::Event::Key.new(code: "j"), model)
    assert handler_called, "'j' key via keys: should also work"
  end

  # action with mousemap: option registers scroll handlers
  def test_action_mousemap_option_registers_scroll
    handler_called = false

    test_class = Class.new do
      include Rooibos::Router

      action scroll_handler: -> { handler_called = true; nil }, mousemap: %i[scroll_up]
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    scroll_event = RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0)
    update.call(scroll_event, model)
    assert handler_called, "scroll_up event should trigger scroll_handler action"
  end
end
