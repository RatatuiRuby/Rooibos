# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterIntercept < Minitest::Test
  # Basic intercept tests
  def test_intercept_stops_further_processing
    keymap_called = false
    intercept_called = false

    test_class = Class.new do
      include Rooibos::Router

      intercept ->(msg) { msg.q? },
                ->(msg, model) { intercept_called = true; model }

      keymap do |map|
        map.key :q, -> { keymap_called = true; nil }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert intercept_called, "intercept handler should have been called"
    refute keymap_called, "keymap should NOT be called when intercept matches"
  end

  def test_intercept_keymap_never_runs_after_match
    keymap_called = false

    test_class = Class.new do
      include Rooibos::Router

      intercept ->(msg) { msg.enter? },
                ->(msg, model) { model.merge(intercepted: true) }

      keymap do |map|
        map.key :enter, -> { keymap_called = true; nil }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ intercepted: false }, copy: true)

    new_model, _command = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert_equal true, new_model[:intercepted], "intercept should have run"
    refute keymap_called, "keymap handler should never execute when intercept matches"
  end

  def test_intercept_returns_handler_result
    test_class = Class.new do
      include Rooibos::Router

      intercept ->(msg) { msg.q? },
                ->(msg, model) { [model.merge(intercepted: true), Rooibos::Command.exit] }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ intercepted: false }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:intercepted], "handler's model update should be returned"
    assert_kind_of Rooibos::Command::Exit, command, "handler's command should be returned"
  end

  def test_intercept_with_no_match_continues_to_keymap
    keymap_called = false

    test_class = Class.new do
      include Rooibos::Router

      # Intercept only matches 'x', not 'q'
      intercept ->(msg) { msg.x? },
                ->(msg, model) { model }

      keymap do |map|
        map.key :q, -> { keymap_called = true; nil }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    # Press 'q' - intercept should NOT match, keymap should run
    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert keymap_called, "keymap should run when intercept predicate doesn't match"
  end

  # Callable types
  def test_intercept_accepts_lambda_predicate_and_handler
    handler_called = false
    predicate = ->(msg) { msg.q? }
    handler = ->(msg, model) { handler_called = true; model }

    test_class = Class.new do
      include Rooibos::Router
      intercept predicate, handler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert handler_called, "lambda predicate and handler should work"
  end

  def test_intercept_accepts_proc_predicate_and_handler
    handler_called = false
    predicate = Proc.new { |msg| msg.q? }
    handler = Proc.new { |msg, model| handler_called = true; model }

    test_class = Class.new do
      include Rooibos::Router
      intercept predicate, handler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert handler_called, "Proc predicate and handler should work"
  end

  def test_intercept_accepts_method_predicate_and_handler
    handler_called = false

    # Define methods in test scope
    predicate_method = ->(msg) { msg.q? }.method(:call)
    handler_method = ->(msg, model) { handler_called = true; model }.method(:call)

    test_class = Class.new do
      include Rooibos::Router
      intercept predicate_method, handler_method
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert handler_called, "Method objects should work for predicate and handler"
  end

  def test_intercept_accepts_callable_object_predicate_and_handler
    # Callable objects with #call method
    predicate_object = Class.new do
      def call(msg)
        msg.q?
      end
    end.new

    handler_object = Class.new do
      def initialize(tracker)
        @tracker = tracker
      end

      def call(msg, model)
        @tracker[:called] = true
        model
      end
    end.new(tracker = { called: false })

    test_class = Class.new do
      include Rooibos::Router
      intercept predicate_object, handler_object
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert tracker[:called], "Callable objects should work for predicate and handler"
  end

  # Predicate aliases
  def test_intercept_if_alias_matches_predicate
    handler_called = false

    test_class = Class.new do
      include Rooibos::Router

      intercept if: ->(msg) { msg.q? },
                then: ->(msg, model) { handler_called = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert handler_called, "if: alias should work as predicate"
  end

  def test_intercept_when_alias_matches_predicate
    handler_called = false

    test_class = Class.new do
      include Rooibos::Router

      intercept when: ->(msg) { msg.enter? },
                then: ->(msg, model) { handler_called = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert handler_called, "when: alias should work as predicate"
  end

  def test_intercept_unless_inverts_predicate
    handler_called = false

    test_class = Class.new do
      include Rooibos::Router

      # unless: inverts - should match when predicate is FALSE
      intercept unless: ->(msg) { msg.q? },
                then: ->(msg, model) { handler_called = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    # Press 'x' - predicate returns false, so inverted = true, handler should run
    update.call(RatatuiRuby::Event::Key.new(code: "x"), model)

    assert handler_called, "unless: should invert predicate (run when predicate is false)"
  end

  def test_intercept_except_inverts_predicate
    handler_called = false

    test_class = Class.new do
      include Rooibos::Router

      # except: inverts - should match when predicate is FALSE
      intercept except: ->(msg) { msg.enter? },
                then: ->(msg, model) { handler_called = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    # Press 'q' - predicate returns false (not enter), so inverted = true
    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert handler_called, "except: should invert predicate"
  end

  def test_intercept_then_keyword_for_handler
    # Already covered by if:/when:/unless: tests above
    # This test verifies then: works with positional predicate
    handler_called = false

    test_class = Class.new do
      include Rooibos::Router

      intercept ->(msg) { msg.q? },
                then: ->(msg, model) { handler_called = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert handler_called, "then: should work with positional predicate"
  end

  # intercept_all
  def test_intercept_all_matches_every_message
    call_count = 0

    test_class = Class.new do
      include Rooibos::Router

      intercept_all ->(msg, model) { call_count += 1; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    # Test with different message types
    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)
    update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)
    update.call(RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0), model)

    assert_equal 3, call_count, "intercept_all should match every message"
  end

  def test_intercept_all_stops_all_further_processing
    keymap_called = false

    test_class = Class.new do
      include Rooibos::Router

      intercept_all ->(msg, model) { model }

      keymap do |map|
        map.key :q, -> { keymap_called = true; nil }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    refute keymap_called, "intercept_all should stop all further processing including keymap"
  end

  # Multiple intercepts
  def test_first_matching_intercept_stops_later_intercepts
    first_called = false
    second_called = false

    test_class = Class.new do
      include Rooibos::Router

      # Both intercepts match 'q'
      intercept ->(msg) { msg.q? },
                ->(msg, model) { first_called = true; model }

      intercept ->(msg) { msg.q? },
                ->(msg, model) { second_called = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert first_called, "first intercept should run"
    refute second_called, "second intercept should NOT run after first matches"
  end

  def test_intercept_declaration_order_determines_priority
    order = []

    test_class = Class.new do
      include Rooibos::Router

      # Both intercepts match 'q', but first should win
      intercept ->(msg) { msg.key? },
                ->(msg, model) { order << :first; model }

      intercept ->(msg) { msg.q? },
                ->(msg, model) { order << :second; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal [:first], order, "first-declared intercept should run, second should not"
  end

  # DWIM return handling
  def test_intercept_handler_can_return_just_model
    test_class = Class.new do
      include Rooibos::Router

      intercept ->(msg) { msg.q? },
                ->(msg, model) { model.merge(handled: true) }  # Returns just model, no tuple
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ handled: false }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:handled], "model should be updated"
    assert_nil command, "command should be nil when handler returns just model"
  end

  def test_intercept_handler_can_return_just_command
    test_class = Class.new do
      include Rooibos::Router

      intercept ->(msg) { msg.q? },
                ->(msg, model) { Rooibos::Command.exit }  # Returns just command
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ original: true }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:original], "original model should be preserved"
    assert_kind_of Rooibos::Command::Exit, command, "command should be returned"
  end

  def test_intercept_handler_can_return_tuple
    test_class = Class.new do
      include Rooibos::Router

      intercept ->(msg) { msg.q? },
                ->(msg, model) { [model.merge(handled: true), Rooibos::Command.exit] }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ handled: false }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:handled], "model should be updated"
    assert_kind_of Rooibos::Command::Exit, command, "command should be returned"
  end

  def test_intercept_handler_can_return_nil
    test_class = Class.new do
      include Rooibos::Router

      intercept ->(msg) { msg.q? },
                ->(msg, model) { nil }  # Returns nil
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ original: true }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:original], "original model should be preserved when handler returns nil"
    assert_nil command, "command should be nil"
  end
end
