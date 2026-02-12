# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

module TestObserveChildFragment
  Model = Data.define(:count)
  Init = -> { Model.new(count: 0) }
  Update = -> (msg, model) { [model.with(count: model.count + 1), nil] }
end

class TestRouterObserve < Minitest::Test
  @@observe_called = false
  @@receive_called = false
  @@call_count = 0
  @@order = []

  def setup
    @@observe_called = false
    @@receive_called = false
    @@call_count = 0
    @@order = []
  end

  ObserveHandler = -> (msg, model) { TestRouterObserve.class_variable_set(:@@observe_called, true); model }
  ReceiveHandler = -> (msg, model) { TestRouterObserve.class_variable_set(:@@receive_called, true); model }
  CountHandler = -> (msg, model) { TestRouterObserve.class_variable_set(:@@call_count, TestRouterObserve.class_variable_get(:@@call_count) + 1); model }
  OrderFirstHandler = -> (msg, model) { TestRouterObserve.class_variable_get(:@@order) << :first; model }
  OrderSecondHandler = -> (msg, model) { TestRouterObserve.class_variable_get(:@@order) << :second; model }
  OrderThirdHandler = -> (msg, model) { TestRouterObserve.class_variable_get(:@@order) << :third; model }

  QPredicate = lambda(&:q?)
  XPredicate = lambda(&:x?)
  EscapePredicate = lambda(&:escape?)

  def test_observe_runs_handler_and_continues_processing
    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate, ObserveHandler
      receive_events :q, ReceiveHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert @@observe_called, "observe handler should have been called"
    assert @@receive_called, "receive should ALSO run after observe (unlike intercept)"
  end

  def test_observe_updates_model_and_receive_sees_updated_model
    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate,
        -> (msg, model) { model.merge(observed: true) }

      receive_events :q, ReceiveHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ observed: false }, copy: true)

    new_model, _command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:observed], "observe should update the model"
    assert @@receive_called, "receive should have run"
  end

  def test_observe_returns_command_that_gets_executed
    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate,
        -> (msg, model) { [model.merge(observed: true), Rooibos::Command.custom(:from_observe)] }

      receive_events :q, -> (_msg, _model) { Rooibos::Command.custom(:from_receive) }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ observed: false }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:observed], "observe should update the model"
    refute_kind_of Rooibos::Command::Batch, command, "should NOT be a Batch command"
    assert_respond_to command, :commands, "should have commands accessor"
    assert_equal 2, command.commands.size, "should have 2 commands"
    assert_equal :from_observe, command.commands[0].callable, "first command from observe"
    assert_equal :from_receive, command.commands[1].callable, "second command from receive"
  end

  def test_observe_with_no_match_skips_handler
    test_class = Class.new do
      include Rooibos::Router

      observe XPredicate, ObserveHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    refute @@observe_called, "observe handler should not run when predicate doesn't match"
  end

  def test_observe_events_matches_key
    test_class = Class.new do
      include Rooibos::Router

      observe_events :q, ObserveHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)
    assert @@observe_called
  end

  def test_observe_events_continues_to_receive
    test_class = Class.new do
      include Rooibos::Router

      observe_events :q, ObserveHandler
      receive_events :q, ReceiveHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert @@observe_called, "observe should run"
    assert @@receive_called, "receive should also run"
  end

  def test_observe_all_matches_every_message
    test_class = Class.new do
      include Rooibos::Router

      observe_all CountHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)
    assert_equal 1, @@call_count

    update.call(RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0), model)
    assert_equal 2, @@call_count
  end

  def test_observe_all_runs_before_receive
    test_class = Class.new do
      include Rooibos::Router

      observe_all -> (msg, model) { [model, Rooibos::Command.custom(:from_observe)] }
      receive_events :scroll_up, -> (_msg, _model) { Rooibos::Command.custom(:from_receive) }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    _new_model, command = update.call(RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0), model)

    refute_kind_of Rooibos::Command::Batch, command, "should NOT be a Batch"
    assert_kind_of Rooibos::Command.const_get(:Separate), command, "observe+receive returns Separate"
    assert_equal 2, command.commands.size, "should have 2 commands"
  end

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

  class CustomNotification < Data.define(:message)
    include Rooibos::Message::Predicates
  end

  def test_observe_instances_of_matches_message_class
    test_class = Class.new do
      include Rooibos::Router

      observe_instances_of TestRouterObserve::CustomNotification, ObserveHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(CustomNotification.new(message: "hello"), model)
    assert @@observe_called
  end

  def test_observe_instances_of_does_not_match_other_types
    test_class = Class.new do
      include Rooibos::Router

      observe_instances_of TestRouterObserve::CustomNotification, ObserveHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)
    refute @@observe_called
  end

  def test_observe_routed_matches_envelope
    test_class = Class.new do
      include Rooibos::Router

      observe_routed :notification, ObserveHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    routed_msg = Rooibos::Message::Routed.new(
      envelope: :notification,
      event: RatatuiRuby::Event::Key.new(code: "enter")
    )

    update.call(routed_msg, model)
    assert @@observe_called
  end

  def test_observe_routed_does_not_match_other_envelopes
    test_class = Class.new do
      include Rooibos::Router

      observe_routed :notification, ObserveHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    routed_msg = Rooibos::Message::Routed.new(
      envelope: :other_route,
      event: RatatuiRuby::Event::Key.new(code: "enter")
    )

    update.call(routed_msg, model)
    refute @@observe_called
  end

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

  def test_observe_with_when_guard
    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate, ObserveHandler,
        when: -> (_msg, model) { model[:active] }
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ active: false }, copy: true))
    refute @@observe_called

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ active: true }, copy: true))
    assert @@observe_called
  end
end
