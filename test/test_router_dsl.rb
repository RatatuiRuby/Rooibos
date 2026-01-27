# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterDsl < Minitest::Test
  # Fake child module for testing
  module FakeChild
    INITIAL = :child_initial
    Update = -> (msg, model) { [model, nil] }
  end

  # route registers a child with a prefix.
  # The prefix is normalized to a symbol via .to_s.to_sym.
  def test_route_registers_child_with_prefix
    test_class = Class.new do
      include Rooibos::Router

      route :stats, to: TestRouterDsl::FakeChild
      route "network", to: TestRouterDsl::FakeChild # String works too
    end

    assert_equal FakeChild, test_class.routes[:stats]
    assert_equal FakeChild, test_class.routes[:network]
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

      action go_back: TestRouterDsl::FakeChild
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

  # keys binds multiple keys to one action
  def test_keys_binds_multiple_keys_to_action
    handler_called = false

    test_class = Class.new do
      include Rooibos::Router

      action :move_down, -> { handler_called = true; nil }

      keymap do
        keys :down, :j, action: :move_down
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    # Test 'down' key
    update.call(RatatuiRuby::Event::Key.new(code: "down"), model)
    assert handler_called, "'down' key should trigger move_down"

    # Test 'j' key
    handler_called = false
    update.call(RatatuiRuby::Event::Key.new(code: "j"), model)
    assert handler_called, "'j' key should also trigger move_down"
  end

  # key accepts hash syntax for metaprogramming
  def test_key_hash_syntax_for_metaprogramming
    q_called = false
    esc_called = false

    # Hashes enable metaprogramming keymaps!
    exit_bindings = { q: -> { q_called = true }, esc: -> { esc_called = true } }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        key(exit_bindings) # Splat a hash of bindings
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)
    assert q_called, "q key from hash should work"

    update.call(RatatuiRuby::Event::Key.new(code: "esc"), model)
    assert esc_called, "esc key from hash should work"
  end

  # keys with multiple keyword pairs
  def test_keys_multi_keyword_syntax
    ctrl_c_called = false
    q_called = false

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        keys ctrl_c: -> { ctrl_c_called = true }, q: -> { q_called = true }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "ctrl_c"), model)
    assert ctrl_c_called, "ctrl_c key from multi-keyword should work"

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)
    assert q_called, "q key from multi-keyword should work"
  end

  # keymap dispatching to routed action synthesizes Message::Routed
  def test_keymap_routed_action_dispatches_message_routed
    received_message = nil

    # Fragment that captures the message it receives
    child_fragment = Module.new do
      define_singleton_method(:const_get) do |name|
        return -> (msg, model) { received_message = msg; [model, nil] } if name == :Update
        super(name)
      end
    end

    model_class = Data.define(:some_container)
    model = model_class.new(some_container: :any_value)

    test_class = Class.new do
      include Rooibos::Router

      route :some_container, to: child_fragment
      action go_back: child_fragment

      keymap do
        key :backspace, :go_back
      end
    end

    update = test_class.from_router
    event = RatatuiRuby::Event::Key.new(code: "backspace")

    update.call(event, model)

    assert_instance_of Rooibos::Message::Routed, received_message
    assert_equal event, received_message.event
    assert_equal :go_back, received_message.envelope
  end

  def test_keymap_registers_key_handlers_that_respond_to_key_events
    q_called = false

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        key "q", -> { q_called = true; nil }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "q")

    update.call(event, model)

    assert q_called, "Handler should be called when key matches"
  end

  def test_keymap_delegates_to_named_action
    action_called = false

    test_class = Class.new do
      include Rooibos::Router

      action :scroll_up, -> { action_called = true; nil }

      keymap do
        key :up, :scroll_up # Delegate to action
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "up")

    update.call(event, model)

    assert action_called, "Action should be called via delegation"
  end

  def test_mousemap_registers_mouse_handlers_that_respond_to_scroll_events
    scroll_up_called = false
    scroll_down_called = false

    test_class = Class.new do
      include Rooibos::Router

      mousemap do
        scroll :up, -> { scroll_up_called = true; nil }
        scroll :down, -> { scroll_down_called = true; nil }
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

      mousemap do
        scroll :up, :scroll_up_action # Delegate to action
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)
    scroll_up_event = RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0)

    update.call(scroll_up_event, model)

    assert action_called, "Action should be called via delegation"
  end

  def test_from_router_returns_callable
    test_class = Class.new do
      include Rooibos::Router
    end

    update = test_class.from_router

    assert update.respond_to?(:call)
  end

  def test_generated_update_routes_prefixed_messages_to_child_update
    # FakeChild is defined at class level with proper UPDATE constant
    test_class = Class.new do
      include Rooibos::Router
      route :child, to: TestRouterDsl::FakeChild
    end

    update = test_class.from_router

    # Create a model with a :child accessor (using Data.define)
    model_class = Data.define(:child)
    model = model_class.new(child: { output: "initial" }.freeze)

    message = [:child, :system_info, { stdout: "Darwin" }]

    new_model, _cmd = update.call(message, model)

    # Verify it delegated and returned updated model
    refute_nil new_model
  end

  def test_keymap_key_when_guard_prevents_execution
    handler_called = false
    guard_proc = -> (model) { model[:allowed] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        key "x", -> { handler_called = true; nil }, when: guard_proc
      end
    end

    update = test_class.from_router

    model = Ractor.make_shareable({ allowed: false }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")

    _new_model, _cmd = update.call(event, model)

    refute handler_called, "Handler should not be called when guard returns false"
  end

  # when: guard allows handler execution when true
  def test_keymap_key_when_guard_allows_execution
    handler_called = false
    guard_proc = -> (model) { model[:allowed] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        key "x", -> { handler_called = true; nil }, when: guard_proc
      end
    end

    update = test_class.from_router

    model = Ractor.make_shareable({ allowed: true }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")

    _new_model, _cmd = update.call(event, model)

    assert handler_called, "Handler should be called when guard returns true"
  end

  # if: is an alias for when:
  def test_keymap_key_if_alias_for_when
    handler_called = false
    guard_proc = -> (model) { model[:allowed] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        key "x", -> { handler_called = true; nil }, if: guard_proc
      end
    end

    update = test_class.from_router

    model = Ractor.make_shareable({ allowed: false }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")

    _new_model, _cmd = update.call(event, model)

    refute handler_called, "Handler should not be called when if: guard returns false"
  end

  # unless: is a negative alias (runs when guard is false)
  def test_keymap_key_unless_runs_when_guard_false
    handler_called = false
    guard_proc = -> (model) { model[:blocked] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        key "x", -> { handler_called = true; nil }, unless: guard_proc
      end
    end

    update = test_class.from_router

    model = Ractor.make_shareable({ blocked: false }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")

    _new_model, _cmd = update.call(event, model)

    assert handler_called, "Handler should run when unless: guard returns false"
  end

  # only: is an alias for when:
  def test_keymap_key_only_alias_for_when
    handler_called = false
    guard_proc = -> (model) { model[:allowed] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        key "x", -> { handler_called = true; nil }, only: guard_proc
      end
    end

    update = test_class.from_router

    model = Ractor.make_shareable({ allowed: false }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")

    _new_model, _cmd = update.call(event, model)

    refute handler_called, "Handler should not be called when only: guard returns false"

    model = Ractor.make_shareable({ allowed: true }, copy: true)
    _new_model, _cmd = update.call(event, model)
    assert handler_called, "Handler should be called when only: guard returns true"
  end

  # skip: is an alias for unless:
  def test_keymap_key_skip_alias_for_unless
    handler_called = false
    guard_proc = -> (model) { model[:blocked] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        key "x", -> { handler_called = true; nil }, skip: guard_proc
      end
    end

    update = test_class.from_router

    model = Ractor.make_shareable({ blocked: true }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")

    _new_model, _cmd = update.call(event, model)

    refute handler_called, "Handler should not be called when skip: guard returns true"

    model = Ractor.make_shareable({ blocked: false }, copy: true)
    _new_model, _cmd = update.call(event, model)
    assert handler_called, "Handler should be called when skip: guard returns false"
  end

  # guard: is an alias for when:
  def test_keymap_key_guard_alias_for_when
    handler_called = false
    guard_proc = -> (model) { model[:allowed] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        key "x", -> { handler_called = true; nil }, guard: guard_proc
      end
    end

    update = test_class.from_router

    model = Ractor.make_shareable({ allowed: false }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")

    _new_model, _cmd = update.call(event, model)

    refute handler_called, "Handler should not be called when guard: guard returns false"

    model = Ractor.make_shareable({ allowed: true }, copy: true)
    _new_model, _cmd = update.call(event, model)
    assert handler_called, "Handler should be called when guard: guard returns true"
  end

  # except: is an alias for unless:
  def test_keymap_key_except_alias_for_unless
    handler_called = false
    guard_proc = -> (model) { model[:blocked] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        key "x", -> { handler_called = true; nil }, except: guard_proc
      end
    end

    update = test_class.from_router

    model = Ractor.make_shareable({ blocked: true }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")

    _new_model, _cmd = update.call(event, model)

    refute handler_called, "Handler should not be called when except: guard returns true"

    model = Ractor.make_shareable({ blocked: false }, copy: true)
    _new_model, _cmd = update.call(event, model)
    assert handler_called, "Handler should be called when except: guard returns false"
  end

  # nested only: block applies guard to all keys within
  def test_keymap_nested_only_block_prevents_execution
    handler_called = false
    guard_proc = -> (model) { model[:allowed] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        only guard: guard_proc do
          key "x", -> { handler_called = true; nil }
        end
      end
    end

    update = test_class.from_router

    model = Ractor.make_shareable({ allowed: false }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")
    _new_model, _cmd = update.call(event, model)
    refute handler_called, "Handler should not be called when nested only: guard returns false"
  end

  def test_keymap_nested_only_block_when_argument
    handler_called = false
    guard_proc = -> (model) { model[:allowed] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        only when: guard_proc do
          key "x", -> { handler_called = true; nil }
        end
      end
    end

    update = test_class.from_router

    model = Ractor.make_shareable({ allowed: false }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")
    # This should fail if when: raises ArgumentError or is ignored
    begin
      _new_model, _cmd = update.call(event, model)
    rescue ArgumentError
      flunk "ArgumentError raised, likely due to missing keyword argument"
    end
    refute handler_called, "Handler should not be called when nested only when: guard returns false"
  end

  def test_keymap_nested_only_block_allows_only_one_argument
    guard_proc_one = -> (model) { model[:allowed] }
    guard_proc_two = -> (model) { model[:allowed] }

    assert_raises ArgumentError do
      Class.new do
        include Rooibos::Router

        keymap do
          only when: guard_proc_one, guard: guard_proc_two do
            key "x", -> { puts "this will error" }
          end
        end
      end
    end
  end

  def test_keymap_nested_only_block_if_argument
    handler_called = false
    guard_proc = -> (model) { model[:allowed] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        only if: guard_proc do
          key "x", -> { handler_called = true; nil }
        end
      end
    end

    update = test_class.from_router

    model = Ractor.make_shareable({ allowed: false }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")
    _new_model, _cmd = update.call(event, model)
    refute handler_called, "Handler should not be called when nested only if: guard returns false"
  end

  def test_keymap_nested_only_block_only_argument
    handler_called = false
    guard_proc = -> (model) { model[:allowed] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        only only: guard_proc do
          key "x", -> { handler_called = true; nil }
        end
      end
    end

    update = test_class.from_router

    model = Ractor.make_shareable({ allowed: false }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")
    _new_model, _cmd = update.call(event, model)
    refute handler_called, "Handler should not be called when nested only only: guard returns false"
  end

  # skip block: skips keys when guard is true (inverse of only)
  def test_keymap_nested_skip_block_when_argument
    handler_called = false
    guard_proc = -> (model) { model[:blocked] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        skip when: guard_proc do
          key "x", -> { handler_called = true; nil }
        end
      end
    end

    update = test_class.from_router

    # When blocked is true, handler should NOT be called
    model = Ractor.make_shareable({ blocked: true }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")
    _new_model, _cmd = update.call(event, model)
    refute handler_called, "Handler should be skipped when skip when: guard returns true"
  end

  def test_keymap_nested_skip_block_if_argument
    handler_called = false
    guard_proc = -> (model) { model[:blocked] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        skip if: guard_proc do
          key "x", -> { handler_called = true; nil }
        end
      end
    end

    update = test_class.from_router

    model = Ractor.make_shareable({ blocked: true }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")
    _new_model, _cmd = update.call(event, model)
    refute handler_called, "Handler should be skipped when skip if: guard returns true"
  end

  def test_keymap_nested_skip_block_skip_argument
    handler_called = false
    guard_proc = -> (model) { model[:blocked] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        skip skip: guard_proc do
          key "x", -> { handler_called = true; nil }
        end
      end
    end

    update = test_class.from_router

    model = Ractor.make_shareable({ blocked: true }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")
    _new_model, _cmd = update.call(event, model)
    refute handler_called, "Handler should be skipped when skip skip: guard returns true"
  end

  def test_keymap_nested_skip_block_allows_only_one_argument
    guard_proc_one = -> (model) { model[:blocked] }
    guard_proc_two = -> (model) { model[:blocked] }

    assert_raises ArgumentError do
      Class.new do
        include Rooibos::Router

        keymap do
          skip when: guard_proc_one, if: guard_proc_two do
            key "x", -> { nil }
          end
        end
      end
    end
  end

  def test_keymap_nested_skip_block_guard_argument
    handler_called = false
    guard_proc = -> (model) { model[:blocked] }

    test_class = Class.new do
      include Rooibos::Router

      keymap do
        skip guard: guard_proc do
          key "x", -> { handler_called = true; nil }
        end
      end
    end

    update = test_class.from_router

    model = Ractor.make_shareable({ blocked: true }, copy: true)
    event = RatatuiRuby::Event::Key.new(code: "x")
    _new_model, _cmd = update.call(event, model)
    refute handler_called, "Handler should be skipped when skip guard: guard returns true"
  end
end
