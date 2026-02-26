# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterRouteToBlocks < Minitest::Test
  module CounterChild
    Model = Data.define(:count, :last_envelope)
    Init = -> { Model.new(count: 0, last_envelope: nil) }
    Update = -> (msg, model) {
      if msg.routed?
        [model.with(count: model.count + 1, last_envelope: msg.envelope), nil]
      else
        [model, nil]
      end
    }
  end

  def test_route_to_block_scopes_destination_for_forward_events
    test_class = Class.new do
      include Rooibos::Router

      route :counter, to: TestRouterRouteToBlocks::CounterChild

      route_to :counter do
        forward_events :enter, as: :increment
        forward_events :space, as: :increment
        forward_events :backspace, as: :decrement
      end
    end

    update = test_class.from_router
    model_class = Data.define(:counter)
    model = model_class.new(counter: CounterChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)
    assert_equal 1, new_model.counter.count
    assert_equal :increment, new_model.counter.last_envelope

    new_model2, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "space"), new_model)
    assert_equal 2, new_model2.counter.count

    new_model3, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "backspace"), new_model2)
    assert_equal 3, new_model3.counter.count
    assert_equal :decrement, new_model3.counter.last_envelope
  end

  def test_route_to_block_with_multiple_destinations
    left_count = 0
    right_count = 0

    left = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        left_count += 1 if msg.routed?
        [model, nil]
      }
    end

    right = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        right_count += 1 if msg.routed?
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :left_panel, to: left
      route :right_panel, to: right

      route_to :left_panel do
        forward_events :a, as: :panel_self
        forward_events :"1", as: :leaf_1
        forward_events :"2", as: :leaf_2
      end

      route_to :right_panel do
        forward_events :b, as: :panel_self
        forward_events :"3", as: :leaf_1
        forward_events :"4", as: :leaf_2
      end
    end

    update = test_class.from_router
    model_class = Data.define(:left_panel, :right_panel)
    model = model_class.new(left_panel: left::Init.call, right_panel: right::Init.call)

    update.call(RatatuiRuby::Event::Key.new(code: "a"), model)
    update.call(RatatuiRuby::Event::Key.new(code: "1"), model)
    assert_equal 2, left_count
    assert_equal 0, right_count

    update.call(RatatuiRuby::Event::Key.new(code: "b"), model)
    update.call(RatatuiRuby::Event::Key.new(code: "3"), model)
    assert_equal 2, left_count
    assert_equal 2, right_count
  end

  def test_route_to_block_inside_only_block
    test_class = Class.new do
      include Rooibos::Router

      route :counter, to: TestRouterRouteToBlocks::CounterChild

      only when: -> (_msg, model) { model.active_tab == :counter } do
        route_to :counter do
          forward_events :"1", as: :counter_1
          forward_events :"2", as: :counter_2
        end
      end
    end

    update = test_class.from_router
    model_class = Data.define(:counter, :active_tab)

    inactive = model_class.new(counter: CounterChild::Init.call, active_tab: :other)
    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "1"), inactive)
    assert_equal 0, new_model.counter.count

    active = model_class.new(counter: CounterChild::Init.call, active_tab: :counter)
    new_model2, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "1"), active)
    assert_equal 1, new_model2.counter.count
    assert_equal :counter_1, new_model2.counter.last_envelope
  end

  def test_route_to_block_with_forward_routed
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterRouteToBlocks::CounterChild

      route_to :child do
        forward_routed :submit, as: :form_submit
        forward_routed :cancel, as: :form_cancel
      end
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: CounterChild::Init.call)

    routed_msg = Rooibos::Message::Routed.new(
      envelope: :submit,
      event: RatatuiRuby::Event::Key.new(code: "enter")
    )

    new_model, _cmd = update.call(routed_msg, model)

    assert_equal 1, new_model.child.count
    assert_equal :form_submit, new_model.child.last_envelope
  end

  def test_route_to_block_with_fragment_module
    test_class = Class.new do
      include Rooibos::Router

      route :counter, to: TestRouterRouteToBlocks::CounterChild

      route_to TestRouterRouteToBlocks::CounterChild do
        forward_events :enter, as: :increment
      end
    end

    update = test_class.from_router
    model_class = Data.define(:counter)
    model = model_class.new(counter: CounterChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert_equal 1, new_model.counter.count,
      "route_to with Module should resolve the fragment"
  end

  def test_route_to_block_with_captured_route
    captured_route = nil
    test_class = Class.new do
      include Rooibos::Router

      captured_route = route :counter, to: TestRouterRouteToBlocks::CounterChild

      route_to captured_route do
        forward_events :enter, as: :increment
      end
    end

    update = test_class.from_router
    model_class = Data.define(:counter)
    model = model_class.new(counter: CounterChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert_equal 1, new_model.counter.count,
      "route_to with captured Route should resolve correctly"
  end

  class DataFetchedMessage < Data.define(:rows)
    include Rooibos::Message::Predicates
  end

  module TrackingChild
    Model = Data.define(:received_count)
    Init = -> { Model.new(received_count: 0) }
    Update = -> (msg, model) {
      [model.with(received_count: model.received_count + 1), nil]
    }
  end

  def test_route_to_block_with_forward_instances_of
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterRouteToBlocks::TrackingChild

      route_to :child do
        forward_instances_of TestRouterRouteToBlocks::DataFetchedMessage
      end
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(
      DataFetchedMessage.new(rows: [1, 2, 3]),
      model
    )

    assert_equal 1, new_model.child.received_count,
      "forward_instances_of inside route_to block must pick up the scoped target"
  end

  def test_route_to_block_with_forward_custom_predicate
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterRouteToBlocks::TrackingChild

      route_to :child do
        forward -> (msg, _) { msg.is_a?(TestRouterRouteToBlocks::DataFetchedMessage) }
      end
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(
      DataFetchedMessage.new(rows: [1, 2, 3]),
      model
    )

    assert_equal 1, new_model.child.received_count,
      "forward with custom predicate inside route_to block must pick up the scoped target"
  end

  def test_route_to_block_with_forward_all
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterRouteToBlocks::TrackingChild

      route_to :child do
        forward_all
      end
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(
      DataFetchedMessage.new(rows: [1, 2, 3]),
      model
    )

    assert_equal 1, new_model.child.received_count,
      "forward_all inside route_to block must pick up the scoped target"
  end
end
