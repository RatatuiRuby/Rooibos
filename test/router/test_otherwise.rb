# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

module OtherwiseTestChild
  Model = Data.define(:received_count)
  Init = -> { Model.new(received_count: 0) }
  Update = -> (msg, model) {
    model.with(received_count: model.received_count + 1)
  }
end

module OtherwiseTestGrandchild
  Model = Data.define(:received_count)
  Init = -> { Model.new(received_count: 0) }
  Update = -> (msg, model) {
    model.with(received_count: model.received_count + 1)
  }
end

class OtherwiseTestMiddle
  include Rooibos::Router

  Model = Data.define(:grandchild)
  Init = -> { Model.new(grandchild: OtherwiseTestGrandchild::Init.call) }

  route :grandchild, to: OtherwiseTestGrandchild
  otherwise route_to: :grandchild

  Update = from_router
end

module OtherwiseCounterTab
  Model = Data.define(:received_count)
  Init = -> { Model.new(received_count: 0) }
  Update = -> (msg, model) { model.with(received_count: model.received_count + 1) }
end

module OtherwiseColorTab
  Model = Data.define(:received_count)
  Init = -> { Model.new(received_count: 0) }
  Update = -> (msg, model) { model.with(received_count: model.received_count + 1) }
end

class TestRouterOtherwise < Minitest::Test
  def test_otherwise_routes_unhandled_messages_to_fragment
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: OtherwiseTestChild

      otherwise route_to: :child
    end

    parent_model = Data.define(:child).new(
      child: OtherwiseTestChild::Init.call
    )
    update = parent_class.from_router

    new_model, _cmd = update.call(:completely_random_message, parent_model)

    assert_equal 1, new_model.child.received_count,
      "otherwise should route unhandled messages to the specified fragment"
  end

  def test_otherwise_does_not_route_receive_handled_messages
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: OtherwiseTestChild

      receive_events :q, -> (_msg, _model) { Rooibos::Command.exit }

      otherwise route_to: :child
    end

    parent_model = Data.define(:child).new(
      child: OtherwiseTestChild::Init.call
    )
    update = parent_class.from_router

    key_message = RatatuiRuby::Event::Key.new(code: "q")
    new_model, cmd = update.call(key_message, parent_model)

    assert_equal 0, new_model.child.received_count,
      "otherwise should NOT route messages that receive already handled"
    assert_kind_of Rooibos::Command::Exit, cmd,
      "receive's exit command should be returned"
  end

  def test_otherwise_does_not_route_forward_handled_messages
    resize_class = Data.define(:width, :height) do
      def resize? = true
    end

    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: OtherwiseTestChild

      forward_instances_of resize_class, to: :child

      otherwise route_to: :child
    end

    parent_model = Data.define(:child).new(
      child: OtherwiseTestChild::Init.call
    )
    update = parent_class.from_router

    resize_msg = resize_class.new(width: 100, height: 50)
    new_model, _cmd = update.call(resize_msg, parent_model)

    assert_equal 1, new_model.child.received_count,
      "forward should route matching messages to child"
  end

  def test_otherwise_receives_message_when_guard_fails
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: OtherwiseTestChild

      receive_events :q, -> (_msg, _model) { Rooibos::Command.exit },
        when: -> (_msg, _model) { false }

      otherwise route_to: :child
    end

    parent_model = Data.define(:child).new(
      child: OtherwiseTestChild::Init.call
    )
    update = parent_class.from_router

    key_message = RatatuiRuby::Event::Key.new(code: "q")
    new_model, cmd = update.call(key_message, parent_model)

    assert_equal 1, new_model.child.received_count,
      "otherwise should route when receive guard fails"
    assert_nil cmd, "no exit command should be returned when guard fails"
  end

  def test_otherwise_to_with_route_to_alias
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: OtherwiseTestChild

      otherwise route_to: :child
    end

    parent_model = Data.define(:child).new(
      child: OtherwiseTestChild::Init.call
    )
    update = parent_class.from_router

    new_model, _cmd = update.call(:random_message, parent_model)
    assert_equal 1, new_model.child.received_count
  end

  def test_otherwise_with_when_guard
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: OtherwiseTestChild

      otherwise route_to: :child,
        when: -> (_msg, model) { model.route_enabled }
    end

    model_class = Data.define(:child, :route_enabled)

    disabled_model = model_class.new(
      child: OtherwiseTestChild::Init.call,
      route_enabled: false
    )
    update = parent_class.from_router

    new_model, _cmd = update.call(:random_message, disabled_model)
    assert_equal 0, new_model.child.received_count,
      "otherwise should NOT route when guard fails"

    enabled_model = model_class.new(
      child: OtherwiseTestChild::Init.call,
      route_enabled: true
    )
    new_model2, _cmd = update.call(:random_message, enabled_model)
    assert_equal 1, new_model2.child.received_count,
      "otherwise should route when guard passes"
  end

  def test_multiple_otherwise_first_guard_wins
    parent_class = Class.new do
      include Rooibos::Router

      route :counter_tab, to: OtherwiseCounterTab
      route :color_tab, to: OtherwiseColorTab

      otherwise route_to: :counter_tab,
        when: -> (_msg, model) { model.active_tab == :counter }

      otherwise route_to: :color_tab,
        when: -> (_msg, model) { model.active_tab == :color }
    end

    model_class = Data.define(:counter_tab, :color_tab, :active_tab)

    counter_active = model_class.new(
      counter_tab: OtherwiseCounterTab::Init.call,
      color_tab: OtherwiseColorTab::Init.call,
      active_tab: :counter
    )
    update = parent_class.from_router

    new_model, _cmd = update.call(:random_message, counter_active)
    assert_equal 1, new_model.counter_tab.received_count, "counter tab should receive"
    assert_equal 0, new_model.color_tab.received_count, "color tab should NOT receive"

    color_active = model_class.new(
      counter_tab: OtherwiseCounterTab::Init.call,
      color_tab: OtherwiseColorTab::Init.call,
      active_tab: :color
    )
    new_model2, _cmd = update.call(:random_message, color_active)
    assert_equal 0, new_model2.counter_tab.received_count, "counter tab should NOT receive"
    assert_equal 1, new_model2.color_tab.received_count, "color tab should receive"
  end

  def test_otherwise_routes_through_deep_hierarchy
    parent_class = Class.new do
      include Rooibos::Router

      route :middle, to: OtherwiseTestMiddle

      otherwise route_to: :middle
    end

    parent_model = Data.define(:middle).new(
      middle: OtherwiseTestMiddle::Init.call
    )
    update = parent_class.from_router

    new_model, _cmd = update.call(:random_message, parent_model)

    assert_equal 1, new_model.middle.grandchild.received_count,
      "otherwise should route through multiple levels to grandchild"
  end

  def test_otherwise_route_to_fragment_module
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: OtherwiseTestChild

      otherwise route_to: OtherwiseTestChild
    end

    parent_model = Data.define(:child).new(
      child: OtherwiseTestChild::Init.call
    )
    update = parent_class.from_router

    new_model, _cmd = update.call(:random_message, parent_model)

    assert_equal 1, new_model.child.received_count,
      "otherwise route_to: Module should resolve by fragment"
  end

  def test_otherwise_route_to_captured_route
    captured_route = nil
    parent_class = Class.new do
      include Rooibos::Router

      captured_route = route :child, to: OtherwiseTestChild

      otherwise route_to: captured_route
    end

    parent_model = Data.define(:child).new(
      child: OtherwiseTestChild::Init.call
    )
    update = parent_class.from_router

    new_model, _cmd = update.call(:random_message, parent_model)

    assert_equal 1, new_model.child.received_count,
      "otherwise route_to: Route should resolve the captured route"
  end
end
