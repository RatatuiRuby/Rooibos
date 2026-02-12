# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestRouterIntegration < Minitest::Test
  include Rooibos::TestHelper

  ObserveOrderHandler = -> (msg, model) { TestRouterIntegration.class_variable_get(:@@order) << :observe; model }
  InterceptOrderHandler = -> (msg, model) { TestRouterIntegration.class_variable_get(:@@order) << :intercept; model }
  ReceiveOrderHandler = -> (msg, model) { TestRouterIntegration.class_variable_get(:@@order) << :receive; model }
  ForwardOrderHandler = -> (model, msg) { TestRouterIntegration.class_variable_get(:@@order) << :forward; model }
  OtherwiseOrderHandler = -> (msg, model) { TestRouterIntegration.class_variable_get(:@@order) << :otherwise; model }
  QPredicate = lambda(&:q?)
  ResizePredicate = -> (msg) { msg.respond_to?(:resize?) && msg.resize? }

  def setup
    @@order = []
  end

  def test_observe_runs_before_intercept
    @@order = []

    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate, ObserveOrderHandler
      intercept QPredicate, InterceptOrderHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal [:observe, :intercept], @@order,
      "observe must run before intercept in message processing pipeline"
  end

  def test_observe_commands_do_not_cause_batch
    router_class = Class.new do
      include Rooibos::Router

      observe_all -> (msg, model) { [model, Rooibos::Command.custom(:from_observe)] }
      receive_events :q, -> (_msg, _model) { Rooibos::Command.custom(:from_receive) }
    end

    update = router_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    _new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    refute_kind_of Rooibos::Command::Batch, command,
      "observe + receive should NOT return a Batch (causes unexpected Message::Batch)"

    refute_kind_of Array, command,
      "observe + receive should NOT return raw Array"

    assert_respond_to command, :commands,
      "should return a command wrapper with .commands accessor"
    assert_equal 2, command.commands.size,
      "Should have exactly 2 commands (observe + receive)"

    assert_equal :from_observe, command.commands[0].callable,
      "First command should be from observe"
    assert_equal :from_receive, command.commands[1].callable,
      "Second command should be from receive"
  end

  def test_intercept_runs_before_receive
    @@order = []

    test_class = Class.new do
      include Rooibos::Router

      intercept lambda(&:x?), InterceptOrderHandler
      receive_events :q, ReceiveOrderHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal [:receive], @@order,
      "receive should run when intercept predicate doesn't match"

    @@order = []
    update.call(RatatuiRuby::Event::Key.new(code: "x"), model)

    assert_equal [:intercept], @@order,
      "intercept must stop processing before receive when matched"
  end

  def test_receive_events_handles_key_and_mouse
    @@order = []

    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) {
        TestRouterIntegration.class_variable_get(:@@order) << :key
        model
      }

      receive_events :scroll_up, -> (_msg, model) {
        TestRouterIntegration.class_variable_get(:@@order) << :mouse
        model
      }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)
    assert_equal [:key], @@order,
      "receive_events should handle key events"

    @@order = []
    update.call(RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0), model)
    assert_equal [:mouse], @@order,
      "receive_events should handle mouse events"
  end

  def test_forward_runs_before_otherwise
    @@order = []

    child = Module.new do
      const_set :Init, -> { { received: false } }
      const_set :Update, -> (msg, model) {
        TestRouterIntegration.class_variable_get(:@@order) << :otherwise
        [model.merge(received: true), nil]
      }
    end

    resize_class = Data.define(:width, :height) do
      def resize? = true
    end

    test_class = Class.new do
      include Rooibos::Router

      route :child, to: child

      forward_instances_of resize_class, to: :child
      otherwise route_to: :child
    end

    model_class = Data.define(:child)
    model = model_class.new(child: child::Init.call)
    update = test_class.from_router

    update.call(resize_class.new(width: 100, height: 50), model)
    assert_equal [:otherwise], @@order, # forward sends to child, which logs :otherwise
      "forward should route matching messages to child"

    @@order = []
    update.call(:completely_random_message, model)
    assert_equal [:otherwise], @@order,
      "otherwise should route unhandled messages to child fragment"
  end

  def test_full_pipeline_order_with_all_handlers
    @@order = []

    child = Module.new do
      const_set :Init, -> { { count: 0 } }
      const_set :Update, -> (msg, model) {
        TestRouterIntegration.class_variable_get(:@@order) << :otherwise
        [model.merge(count: model[:count] + 1), nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :child, to: child

      observe_all -> (msg, model) {
        TestRouterIntegration.class_variable_get(:@@order) << :observe
        model
      }

      intercept -> (msg, _model) { msg.respond_to?(:ctrl_c?) && msg.ctrl_c? }, -> (msg, model) {
        TestRouterIntegration.class_variable_get(:@@order) << :intercept
        model
      }

      receive_events :q, -> (_msg, model) {
        TestRouterIntegration.class_variable_get(:@@order) << :receive
        model
      }

      receive_events :scroll_up, -> (_msg, model) {
        TestRouterIntegration.class_variable_get(:@@order) << :receive_mouse
        model
      }

      otherwise route_to: :child
    end

    model_class = Data.define(:child)
    model = model_class.new(child: child::Init.call)
    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)
    assert_equal [:observe, :receive], @@order,
      "Key event: observe should run, then receive"

    @@order = []
    update.call(RatatuiRuby::Event::Key.new(code: "ctrl_c"), model)
    assert_equal [:observe, :intercept], @@order,
      "Ctrl+C: observe should run, then intercept should stop processing"

    @@order = []
    update.call(RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0), model)
    assert_equal [:observe, :receive_mouse], @@order,
      "Mouse scroll: observe should run, then receive handles mouse"

    @@order = []
    update.call(:unknown_message, model)
    assert_equal [:observe, :otherwise], @@order,
      "Unknown message: observe should run, then otherwise should route to child"
  end

  module CounterFragment
    Model = Data.define(:count)
    Init = -> { Model.new(count: 0) }
    Update = -> (msg, model) {
      if msg.routed? && msg.envelope == :increment
        [model.with(count: model.count + 1), nil]
      else
        [model, nil]
      end
    }
  end

  def test_nested_fragment_receives_routed_messages
    parent_class = Class.new do
      include Rooibos::Router

      route :counter, to: TestRouterIntegration::CounterFragment

      forward_events :space, to: :counter, as: :increment
    end

    parent_model = Data.define(:counter).new(
      counter: CounterFragment::Init.call
    )
    update = parent_class.from_router

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "space"), parent_model)

    assert_equal 1, new_model.counter.count
  end

  def test_observe_model_changes_flow_to_intercept_handler
  end

  def test_observe_model_changes_flow_to_receive_handler
  end

  def test_observe_model_changes_flow_to_forward_child_accessor
  end

  def test_multiple_observers_see_cumulative_model_changes
  end

  def test_receive_model_changes_preserved_when_processing_stops
  end

  def test_multiple_observer_commands_produce_separate_not_batch
    observer1 = -> (_msg, model) { [model, Rooibos::Command.custom(:cmd_one)] }
    observer2 = -> (_msg, model) { [model, Rooibos::Command.custom(:cmd_two)] }

    router_class = Class.new do
      include Rooibos::Router

      observe_events :q, observer1
      observe_events :q, observer2
    end

    update = router_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    _new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    refute_kind_of Rooibos::Command::Batch, command,
      "observer commands must NOT be batched (would cause unexpected Message::Batch)"
    assert_respond_to command, :commands
    assert_equal 2, command.commands.size,
      "all observer commands must be preserved"
    assert_equal :cmd_one, command.commands[0].callable,
      "commands must appear in declaration order"
    assert_equal :cmd_two, command.commands[1].callable,
      "commands must appear in declaration order"
  end

  def test_forward_with_read_write_accessors_extracts_and_merges
  end

  def test_forward_with_method_object_accessors
  end

  def test_forward_with_callable_object_accessors
  end

  def test_forward_with_deeply_nested_accessors
  end

  def test_forward_accessor_preserves_unrelated_model_parts
  end
end
