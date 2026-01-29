# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterKeymap < Minitest::Test
  # Fake child module for testing
  module FakeChild
    INITIAL = :child_initial
    Update = -> (msg, model) { [model, nil] }
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

  # ============================================================================
  # [ADD] Key route option tests
  # ============================================================================

  def test_keymap_key_route_option_wraps_in_message_routed
    skip "TODO"
  end

  def test_keymap_key_route_option_routes_to_correct_fragment
    skip "TODO"
  end

  def test_keymap_key_route_option_with_action_reference
    skip "TODO"
  end

  def test_keymap_key_route_option_with_lambda_handler
    skip "TODO"
  end
end

