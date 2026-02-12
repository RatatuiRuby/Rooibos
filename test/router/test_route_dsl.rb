# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterRouteDSL < Minitest::Test
  module SimpleChild
    Model = Data.define(:value)
    Init = -> { Model.new(value: 0) }
    Update = -> (msg, model) {
      if msg.routed? && msg.envelope == :increment
        [model.with(value: model.value + 1), nil]
      else
        [model, nil]
      end
    }
  end

  module SimplerChild
    Init = -> { nil }
    Update = -> (msg, model) { nil }
  end

  def test_route_with_symbol_uses_attribute_accessor
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterRouteDSL::SimpleChild
      forward_events :enter, to: :child, as: :increment
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: SimpleChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert_equal 1, new_model.child.value
  end

  def test_route_with_read_write_lambdas
    test_class = Class.new do
      include Rooibos::Router

      route read: -> (model) { model.panels[:sidebar] },
        write: -> (current, value) {
          current.with(panels: current.panels.merge(sidebar: value))
        },
        to: TestRouterRouteDSL::SimpleChild

      forward_events :enter, to: TestRouterRouteDSL::SimpleChild, as: :increment
    end

    update = test_class.from_router
    model_class = Data.define(:panels)
    model = model_class.new(panels: { sidebar: SimpleChild::Init.call })

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert_equal 1, new_model.panels[:sidebar].value
  end

  def test_route_with_dynamic_read_based_on_model_state
    test_class = Class.new do
      include Rooibos::Router

      route read: -> (model) { model.tabs[model.active_tab] },
        write: -> (current, value) {
          current.with(tabs: current.tabs.merge(current.active_tab => value))
        },
        to: TestRouterRouteDSL::SimpleChild

      forward_events :enter, to: TestRouterRouteDSL::SimpleChild, as: :increment
    end

    update = test_class.from_router
    model_class = Data.define(:tabs, :active_tab)
    model = model_class.new(
      tabs: { tab1: SimpleChild::Init.call, tab2: SimpleChild::Init.call },
      active_tab: :tab1
    )

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)
    assert_equal 1, new_model.tabs[:tab1].value
    assert_equal 0, new_model.tabs[:tab2].value

    switched = new_model.with(active_tab: :tab2)
    new_model2, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), switched)
    assert_equal 1, new_model2.tabs[:tab1].value
    assert_equal 1, new_model2.tabs[:tab2].value
  end

  def test_multiple_routes_with_different_destinations
    left_value = 0
    right_value = 0

    left = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        if msg.routed?
          left_value += 1
          [model.with(x: model.x + 1), nil]
        else
          [model, nil]
        end
      }
    end

    right = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        if msg.routed?
          right_value += 1
          [model.with(x: model.x + 1), nil]
        else
          [model, nil]
        end
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :left_panel, to: left
      route :right_panel, to: right

      forward_events :a, to: :left_panel, as: :activate
      forward_events :b, to: :right_panel, as: :activate
    end

    update = test_class.from_router
    model_class = Data.define(:left_panel, :right_panel)
    model = model_class.new(left_panel: left::Init.call, right_panel: right::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "a"), model)
    assert_equal 1, left_value
    assert_equal 0, right_value

    update.call(RatatuiRuby::Event::Key.new(code: "b"), new_model)
    assert_equal 1, left_value
    assert_equal 1, right_value
  end

  def test_route_with_explicit_name_and_read_write
    test_class = Class.new do
      include Rooibos::Router

      route :sidebar,
        read: -> (model) { model.panels[:sidebar] },
        write: -> (current, value) {
          current.with(panels: current.panels.merge(sidebar: value))
        },
        to: TestRouterRouteDSL::SimpleChild

      forward_events :s, to: :sidebar, as: :increment
    end

    update = test_class.from_router
    model_class = Data.define(:panels)
    model = model_class.new(panels: { sidebar: SimpleChild::Init.call })

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "s"), model)

    assert_equal 1, new_model.panels[:sidebar].value
  end

  def test_from_router_raises_when_forward_target_is_ambiguous_by_fragment
    test_class = Class.new do
      include Rooibos::Router

      route :first, to: TestRouterRouteDSL::SimpleChild
      route :second, to: TestRouterRouteDSL::SimpleChild

      forward_events :enter, to: TestRouterRouteDSL::SimpleChild
    end

    assert_raises(Rooibos::Error::Invariant) do
      test_class.from_router
    end
  end

  def test_from_router_raises_when_otherwise_target_is_ambiguous_by_fragment
    test_class = Class.new do
      include Rooibos::Router

      route :first, to: TestRouterRouteDSL::SimpleChild
      route :second, to: TestRouterRouteDSL::SimpleChild

      otherwise route_to: TestRouterRouteDSL::SimpleChild
    end

    assert_raises(Rooibos::Error::Invariant) do
      test_class.from_router
    end
  end

  def test_from_router_raises_when_forward_target_is_ambiguous_by_prefix
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterRouteDSL::SimpleChild
      route :child, to: TestRouterRouteDSL::SimplerChild

      forward_events :enter, to: :child
    end

    assert_raises(Rooibos::Error::Invariant) do
      test_class.from_router
    end
  end

  def test_from_router_works_when_ambiguity_resolved_by_capturing_route
    first = nil
    second = nil
    child = nil
    simpler_child = nil
    test_class = Class.new do
      include Rooibos::Router

      first = route :first, to: TestRouterRouteDSL::SimpleChild
      second = route :second, to: TestRouterRouteDSL::SimpleChild
      child = route :child, to: TestRouterRouteDSL::SimpleChild
      simpler_child = route :child, to: TestRouterRouteDSL::SimplerChild

      forward_events :enter, to: first, as: :increment
      forward_events :spacebar, to: second, as: :increment
      forward_events :a, to: child, as: :increment
      forward_events :b, to: simpler_child
    end

    update = test_class.from_router
    model_class = Data.define(:first, :second, :child)
    model = model_class.new(
      first: SimpleChild::Init.call,
      second: SimpleChild::Init.call,
      child: SimpleChild::Init.call
    )

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert_equal 1, new_model.first.value,
      "Captured route disambiguates: :enter forwards to first"
  end

  def test_forward_to_captured_binding_from_unnamed_route
    active_tab = nil
    test_class = Class.new do
      include Rooibos::Router

      active_tab = route read: -> (model) { model.panels[:sidebar] },
        write: -> (current, value) {
          current.with(panels: current.panels.merge(sidebar: value))
        },
        to: TestRouterRouteDSL::SimpleChild

      forward_events :enter, to: active_tab, as: :increment
    end

    update = test_class.from_router
    model_class = Data.define(:panels)
    model = model_class.new(panels: { sidebar: SimpleChild::Init.call })

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert_equal 1, new_model.panels[:sidebar].value,
      "Captured binding from unnamed read:/write: route should forward correctly"
  end
end
