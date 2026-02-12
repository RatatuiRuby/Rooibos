# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterIntegrationFlat < Minitest::Test
  def test_observe_runs_before_receive
    order = []

    test_class = Class.new do
      include Rooibos::Router

      observe_events :q, -> (_msg, model) { order << :observe; model }
      receive_events :q, -> (_msg, model) { order << :receive; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal [:observe, :receive], order
  end

  def test_receive_stops_further_receive
    order = []

    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) { order << :first; model }
      receive_events :q, -> (_msg, model) { order << :second; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal [:first], order, "first receive should stop further processing"
  end

  def test_receive_runs_before_forward
    order = []

    child = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        order << :forward
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :child, to: child

      receive_events :q, -> (_msg, model) { order << :receive; model }
      forward_events :q, to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: child::Init.call)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal [:receive], order, "receive should prevent forward"
  end

  def test_forward_runs_before_otherwise
    order = []

    forward_child = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        order << :forward
        [model, nil]
      }
    end

    otherwise_child = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        order << :otherwise
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :forward_child, to: forward_child
      route :otherwise_child, to: otherwise_child

      forward_events :q, to: :forward_child
      otherwise route_to: :otherwise_child
    end

    update = test_class.from_router
    model_class = Data.define(:forward_child, :otherwise_child)
    model = model_class.new(
      forward_child: forward_child::Init.call,
      otherwise_child: otherwise_child::Init.call
    )

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal [:forward], order, "forward should prevent otherwise"
  end

  def test_unhandled_falls_through_to_otherwise
    order = []

    otherwise_child = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        order << :otherwise
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :child, to: otherwise_child

      receive_events :q, -> (_msg, model) { order << :receive; model }
      otherwise route_to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: otherwise_child::Init.call)

    update.call(RatatuiRuby::Event::Key.new(code: "x"), model)

    assert_equal [:otherwise], order
  end

  def test_full_pipeline_observe_receive_forward_otherwise
    order = []

    child = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :child) }
      const_set :Update, -> (msg, model) {
        order << :child_update
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :child, to: child

      observe_events :q, -> (_msg, model) { order << :observe; model }
      receive_events :q, -> (_msg, model) { order << :receive; model }
      forward_events :q, to: :child
      otherwise route_to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: child::Init.call)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal [:observe, :receive], order
  end

  def test_observe_and_receive_commands_accumulate_separately
    test_class = Class.new do
      include Rooibos::Router

      observe_events :q, -> (_msg, model) {
        [model, Rooibos::Command.wait(0.1, :waited)]
      }

      receive_events :q, -> (_msg, model) {
        [model, Rooibos::Command.exit]
      }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    _new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    refute_kind_of Rooibos::Command::Batch, command
    assert_kind_of Rooibos::Command.const_get(:Separate), command
    assert_respond_to command, :commands
  end

  def test_model_updates_flow_through_pipeline
    test_class = Class.new do
      include Rooibos::Router

      observe_events :q, -> (_msg, model) { model.merge(step1: true) }
      observe_events :q, -> (_msg, model) { model.merge(step2: model[:step1]) }
      receive_events :q, -> (_msg, model) { model.merge(step3: model[:step2]) }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:step1]
    assert_equal true, new_model[:step2]
    assert_equal true, new_model[:step3]
  end
end
