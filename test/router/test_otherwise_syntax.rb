# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

module OtherwiseSyntaxTabA
  Model = Data.define(:received)
  Init = -> { Model.new(received: false) }
  Update = -> (msg, model) { [model.with(received: true), nil] }
end

module OtherwiseSyntaxTabB
  Model = Data.define(:received)
  Init = -> { Model.new(received: false) }
  Update = -> (msg, model) { [model.with(received: true), nil] }
end

module OtherwiseSyntaxFallbackTab
  Model = Data.define(:received)
  Init = -> { Model.new(received: false) }
  Update = -> (msg, model) { [model.with(received: true), nil] }
end

class TestRouterOtherwiseSyntax < Minitest::Test
  module TrackingChild
    Model = Data.define(:messages)
    Init = -> { Model.new(messages: []) }
    Update = -> (msg, model) { [model.with(messages: model.messages + [msg]), nil] }
  end

  def test_otherwise_with_route_to_syntax
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterOtherwiseSyntax::TrackingChild
      otherwise route_to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), model)
    assert_equal 1, new_model.child.messages.size
  end

  def test_multiple_otherwise_with_guards_first_wins
    test_class = Class.new do
      include Rooibos::Router

      route :tab_a, to: OtherwiseSyntaxTabA
      route :tab_b, to: OtherwiseSyntaxTabB
      route :fallback, to: OtherwiseSyntaxFallbackTab

      otherwise route_to: :tab_a, when: -> (_msg, model) { model.active_tab == :a }
      otherwise route_to: :tab_b, when: -> (_msg, model) { model.active_tab == :b }
      otherwise route_to: :fallback # catch-all
    end

    update = test_class.from_router
    model_class = Data.define(:tab_a, :tab_b, :fallback, :active_tab)

    model_a = model_class.new(
      tab_a: OtherwiseSyntaxTabA::Init.call,
      tab_b: OtherwiseSyntaxTabB::Init.call,
      fallback: OtherwiseSyntaxFallbackTab::Init.call,
      active_tab: :a
    )
    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), model_a)
    assert new_model.tab_a.received
    refute new_model.tab_b.received
    refute new_model.fallback.received

    model_b = model_class.new(
      tab_a: OtherwiseSyntaxTabA::Init.call,
      tab_b: OtherwiseSyntaxTabB::Init.call,
      fallback: OtherwiseSyntaxFallbackTab::Init.call,
      active_tab: :b
    )
    new_model2, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), model_b)
    refute new_model2.tab_a.received
    assert new_model2.tab_b.received
    refute new_model2.fallback.received

    model_c = model_class.new(
      tab_a: OtherwiseSyntaxTabA::Init.call,
      tab_b: OtherwiseSyntaxTabB::Init.call,
      fallback: OtherwiseSyntaxFallbackTab::Init.call,
      active_tab: :c # neither a nor b
    )
    new_model3, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), model_c)
    refute new_model3.tab_a.received
    refute new_model3.tab_b.received
    assert new_model3.fallback.received
  end

  def test_otherwise_stops_after_first_matching_guard
    first_called = false
    second_called = false

    child1 = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        first_called = true
        [model, nil]
      }
    end

    child2 = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        second_called = true
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :child1, to: child1
      route :child2, to: child2

      otherwise route_to: :child1, when: -> (_msg, model) { true }
      otherwise route_to: :child2, when: -> (_msg, model) { true }
    end

    update = test_class.from_router
    model_class = Data.define(:child1, :child2)
    model = model_class.new(child1: child1::Init.call, child2: child2::Init.call)

    update.call(RatatuiRuby::Event::Key.new(code: "x"), model)

    assert first_called, "first otherwise should run"
    refute second_called, "second otherwise should NOT run"
  end
end
