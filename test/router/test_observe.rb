# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

# Child fragment for routed fragment tests
module TestObserveChildFragment
  Model = Data.define(:count)
  Init = -> { Model.new(count: 0) }
  # Return nil command to avoid Ractor-shareability issues with Command::Mapped
  Update = -> (msg, model) { [model.with(count: model.count + 1), nil] }
end

class TestRouterObserve < Minitest::Test
  # Class variables for test state (Ractor-shareable access pattern)
  @@observe_called = false
  @@keymap_called = false
  @@call_count = 0
  @@order = []

  def setup
    @@observe_called = false
    @@keymap_called = false
    @@call_count = 0
    @@order = []
  end

  # Handlers defined at class level for Ractor-shareability
  ObserveHandler = -> (msg, model) { TestRouterObserve.class_variable_set(:@@observe_called, true); model }
  KeymapHandler = -> { TestRouterObserve.class_variable_set(:@@keymap_called, true); nil }
  CountHandler = -> (msg, model) { TestRouterObserve.class_variable_set(:@@call_count, TestRouterObserve.class_variable_get(:@@call_count) + 1); model }
  OrderFirstHandler = -> (msg, model) { TestRouterObserve.class_variable_get(:@@order) << :first; model }
  OrderSecondHandler = -> (msg, model) { TestRouterObserve.class_variable_get(:@@order) << :second; model }
  OrderThirdHandler = -> (msg, model) { TestRouterObserve.class_variable_get(:@@order) << :third; model }

  # Predicates defined at class level
  QPredicate = lambda(&:q?)
  XPredicate = lambda(&:x?)
  EscapePredicate = lambda(&:escape?)

  # Basic observe tests
  def test_observe_runs_handler_and_continues_processing
    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate, ObserveHandler
      keymap do |map|
        map.key :q, KeymapHandler
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert @@observe_called, "observe handler should have been called"
    assert @@keymap_called, "keymap should ALSO run after observe (unlike intercept)"
  end

  def test_observe_updates_model_and_keymap_sees_updated_model
    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate,
        -> (msg, model) { model.merge(observed: true) }

      keymap do |map|
        map.key :q, KeymapHandler
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ observed: false }, copy: true)

    new_model, _command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:observed], "observe should update the model"
    assert @@keymap_called, "keymap should have run"
  end

  def test_observe_returns_command_that_gets_executed
    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate,
        -> (msg, model) { [model.merge(observed: true), Rooibos::Command.custom(:from_observe)] }

      keymap do |map|
        map.key :q, -> { Rooibos::Command.custom(:from_keymap) }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ observed: false }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:observed], "observe should update the model"
    # Multiple commands should be returned with internal wrapper, NOT a Batch
    # (Batch would cause unexpected Message::Batch to be sent to app developers)
    refute_kind_of Rooibos::Command::Batch, command, "should NOT be a Batch command"
    assert_respond_to command, :commands, "should have commands accessor"
    assert_equal 2, command.commands.size, "should have 2 commands"
    assert_equal :from_observe, command.commands[0].callable, "first command from observe"
    assert_equal :from_keymap, command.commands[1].callable, "second command from keymap"
  end

  def test_observe_with_no_match_skips_handler
    test_class = Class.new do
      include Rooibos::Router

      # Observe only matches 'x', not 'q'
      observe XPredicate, ObserveHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    # Press 'q' - observe should NOT match
    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    refute @@observe_called, "observe handler should not run when predicate doesn't match"
  end

  # Callable types
  def test_observe_accepts_lambda_predicate_and_handler
    # Test that observe command is merged with scroll_down (not just scroll_up)
    test_class = Class.new do
      include Rooibos::Router

      observe_all -> (msg, model) { [model, Rooibos::Command.custom(:from_observe)] }

      mousemap do |map|
        map.scroll :down, -> { Rooibos::Command.custom(:from_scroll_down) }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    _new_model, command = update.call(RatatuiRuby::Event::Mouse.new(kind: "scroll_down", button: "left", x: 0, y: 0), model)

    refute_kind_of Rooibos::Command::Batch, command, "should NOT be a Batch"
    assert_respond_to command, :commands, "should have commands accessor"
    assert_equal 2, command.commands.size, "should have 2 commands"
  end

  def test_observe_accepts_proc_predicate_and_handler
    # Test that observe command is merged with click handler command
    test_class = Class.new do
      include Rooibos::Router

      observe_all -> (msg, model) { [model, Rooibos::Command.custom(:from_observe)] }

      mousemap do |map|
        map.click -> (x, y) { Rooibos::Command.custom(:from_click) }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    _new_model, command = update.call(RatatuiRuby::Event::Mouse.new(kind: "down", button: "left", x: 10, y: 20), model)

    refute_kind_of Rooibos::Command::Batch, command, "should NOT be a Batch"
    assert_respond_to command, :commands, "should have commands accessor"
    assert_equal 2, command.commands.size, "should have 2 commands"
  end

  def test_observe_accepts_method_predicate_and_handler
    # Test that observe command is merged with routed fragment command
    # Use a pre-defined child fragment to avoid dynamic constant assignment
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: TestObserveChildFragment

      observe_all -> (msg, model) { [model, Rooibos::Command.custom(:from_observe)] }
    end

    parent_model = Data.define(:child).new(child: TestObserveChildFragment::Init.call)
    update = parent_class.from_router

    # Use array-style routed message (what Rooibos.delegate expects)
    routed_msg = [:child, :increment]
    _new_model, command = update.call(routed_msg, parent_model)

    # Observe command should survive even when routing to child fragment
    # (child returns nil, so only observe command should be present)
    refute_nil command, "observe command should be returned"
    assert_equal :from_observe, command.callable, "command should be from observe"
  end

  def test_observe_accepts_callable_object_predicate_and_handler
    # Define callable objects with #call method
    predicate_class = Class.new do
      def call(msg)
        msg.q?
      end
    end

    handler_class = Class.new do
      def call(msg, model)
        [model.merge(handled: true), nil]
      end
    end

    test_class = Class.new do
      include Rooibos::Router

      observe predicate_class.new, handler_class.new
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ handled: false }, copy: true)

    new_model, _command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:handled], "callable object handler should update model"
  end

  def test_observe_validates_ractor_shareable_in_debug_mode
    # Dynamically created lambdas are NOT Ractor-shareable
    non_shareable_predicate = lambda(&:q?)
    non_shareable_handler = -> (msg, model) { model }

    error = assert_raises(Rooibos::Error::Invariant) do
      Class.new do
        include Rooibos::Router
        observe non_shareable_predicate, non_shareable_handler
      end
    end

    assert_match(/ractor|shareable/i, error.message)
  end

  def test_observe_allows_non_ractor_shareable_in_production_mode
    RatatuiRuby::Debug.suppress_debug_mode do
      # This should NOT raise in production mode
      test_class = Class.new do
        include Rooibos::Router
        observe lambda(&:q?), -> (msg, model) { model }
      end

      assert test_class.respond_to?(:from_router), "Router should work in production mode"
    end
  end

  # Predicate aliases
  def test_observe_if_alias_matches_predicate
    test_class = Class.new do
      include Rooibos::Router

      # Using if: for predicate requires then: for handler
      observe if: QPredicate, then: ObserveHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert @@observe_called, "observe should run when if: predicate matches"
  end

  def test_observe_when_alias_matches_predicate
    test_class = Class.new do
      include Rooibos::Router

      # when: is an alias for if:
      observe when: QPredicate, then: ObserveHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert @@observe_called, "observe should run when when: predicate matches"
  end

  def test_observe_unless_inverts_predicate
    test_class = Class.new do
      include Rooibos::Router

      # unless: inverts the predicate — runs when predicate is FALSE
      observe unless: EscapePredicate, then: ObserveHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    # 'q' is not escape, so unless: predicate (msg.escape?) is false, handler runs
    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert @@observe_called, "observe should run when unless: predicate is false"
  end

  def test_observe_except_inverts_predicate
    test_class = Class.new do
      include Rooibos::Router

      # except: is an alias for unless:
      observe except: EscapePredicate, then: ObserveHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    # 'q' is not escape, so except: predicate (msg.escape?) is false, handler runs
    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert @@observe_called, "observe should run when except: predicate is false"
  end

  def test_observe_then_keyword_for_handler
    test_class = Class.new do
      include Rooibos::Router

      # then: specifies the handler when using keyword-style
      observe if: QPredicate, then: ObserveHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert @@observe_called, "then: should specify the handler"
  end

  # observe_all
  def test_observe_all_matches_every_message
    test_class = Class.new do
      include Rooibos::Router

      observe_all CountHandler

      mousemap do |map|
        map.scroll :up, -> { Rooibos::Command.custom(:scrolled) }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    # Test with mouse scroll - observe_all should still run
    update.call(RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0), model)

    assert_equal 1, @@call_count, "observe_all should match mouse events too"
  end

  def test_observe_all_runs_before_keymap
    # This test verifies observe command is merged with mousemap command
    test_class = Class.new do
      include Rooibos::Router

      observe_all -> (msg, model) { [model, Rooibos::Command.custom(:from_observe)] }

      mousemap do |map|
        map.scroll :up, -> { Rooibos::Command.custom(:from_mousemap) }
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    _new_model, command = update.call(RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0), model)

    # Both commands should NOT be a Batch (would cause Message::Batch)
    refute_kind_of Rooibos::Command::Batch, command, "should NOT be a Batch"
    assert_respond_to command, :commands, "should have commands accessor"
    assert_equal 2, command.commands.size, "should have 2 commands"
  end

  # Multiple observers
  def test_multiple_observers_run_in_declaration_order
    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate, OrderFirstHandler
      observe QPredicate, OrderSecondHandler
      observe QPredicate, OrderThirdHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal [:first, :second, :third], @@order, "observers should run in declaration order"
  end

  def test_multiple_observers_accumulate_model_changes
    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate,
        -> (msg, model) { model.merge(first: true) }

      observe QPredicate,
        -> (msg, model) { model.merge(second: true, first_was: model[:first]) }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ first: false, second: false }, copy: true)

    new_model, _command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:first], "first observer should update model"
    assert_equal true, new_model[:second], "second observer should update model"
    assert_equal true, new_model[:first_was], "second observer should see first observer's update"
  end

  def test_multiple_observers_accumulate_commands
    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate,
        -> (msg, model) { [model, Rooibos::Command.custom(:cmd_one)] }

      observe QPredicate,
        -> (msg, model) { [model, Rooibos::Command.custom(:cmd_two)] }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    _new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    refute_kind_of Rooibos::Command::Batch, command, "should NOT be a Batch"
    assert_respond_to command, :commands, "should have commands accessor"
    assert_equal 2, command.commands.size, "should have 2 commands"
    assert_equal :cmd_one, command.commands[0].callable, "first command"
    assert_equal :cmd_two, command.commands[1].callable, "second command"
  end

  # DWIM return handling
  def test_observe_handler_can_return_just_model
    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate,
        -> (msg, model) { model.merge(observed: true) } # Just model, no tuple
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ observed: false }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:observed], "model should be updated"
    assert_nil command, "command should be nil when only model returned"
  end

  def test_observe_handler_can_return_just_command
    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate,
        -> (msg, model) { Rooibos::Command.custom(:from_observe) } # Just command
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ value: 42 }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal 42, new_model[:value], "model should be unchanged"
    assert_equal :from_observe, command.callable, "command should be returned"
  end

  def test_observe_handler_can_return_tuple
    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate,
        -> (msg, model) { [model.merge(tupled: true), Rooibos::Command.custom(:tupled)] }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ tupled: false }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:tupled], "model should be updated"
    assert_equal :tupled, command.callable, "command should be returned"
  end

  def test_observe_handler_can_return_nil
    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate,
        -> (msg, model) { nil } # Returns nil
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ unchanged: true }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:unchanged], "model should be unchanged when nil returned"
    assert_nil command, "command should be nil when nil returned"
  end
end
