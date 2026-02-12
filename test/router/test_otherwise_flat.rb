# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterOtherwiseFlat < Minitest::Test
  module TrackingNested
    Model = Data.define(:messages)
    Init = -> { Model.new(messages: []) }
    Update = -> (msg, model) {
      [model.with(messages: model.messages + [msg]), nil]
    }
  end

  def test_otherwise_routes_unhandled_to_fragment
    test_class = Class.new do
      include Rooibos::Router

      route :nested, to: TestRouterOtherwiseFlat::TrackingNested

      receive_events :q, -> (_msg, model) { model } # handles :q

      otherwise route_to: :nested
    end

    update = test_class.from_router
    model_class = Data.define(:nested)
    model = model_class.new(nested: TrackingNested::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), model)

    assert_equal 1, new_model.nested.messages.size
  end

  def test_otherwise_skips_handled_messages
    test_class = Class.new do
      include Rooibos::Router

      route :nested, to: TestRouterOtherwiseFlat::TrackingNested

      receive_events :q, -> (_msg, model) { model } # handles :q

      otherwise route_to: :nested
    end

    update = test_class.from_router
    model_class = Data.define(:nested)
    model = model_class.new(nested: TrackingNested::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal 0, new_model.nested.messages.size
  end

  def test_otherwise_with_when_guard
    test_class = Class.new do
      include Rooibos::Router

      route :nested, to: TestRouterOtherwiseFlat::TrackingNested

      otherwise route_to: :nested, when: -> (_msg, model) { model.active }
    end

    update = test_class.from_router
    model_class = Data.define(:nested, :active)
    model = model_class.new(nested: TrackingNested::Init.call, active: false)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), model)
    assert_equal 0, new_model.nested.messages.size

    active_model = model.with(active: true)
    new_model2, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), active_model)
    assert_equal 1, new_model2.nested.messages.size
  end

  def test_otherwise_with_unless_guard
    test_class = Class.new do
      include Rooibos::Router

      route :nested, to: TestRouterOtherwiseFlat::TrackingNested

      otherwise route_to: :nested, unless: -> (_msg, model) { model.locked }
    end

    update = test_class.from_router
    model_class = Data.define(:nested, :locked)

    locked_model = model_class.new(nested: TrackingNested::Init.call, locked: true)
    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), locked_model)
    assert_equal 0, new_model.nested.messages.size

    unlocked_model = model_class.new(nested: TrackingNested::Init.call, locked: false)
    new_model2, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), unlocked_model)
    assert_equal 1, new_model2.nested.messages.size
  end

  module TabA
    Model = Data.define(:received)
    Init = -> { Model.new(received: false) }
    Update = -> (msg, model) { model.with(received: true) }
  end

  module TabB
    Model = Data.define(:received)
    Init = -> { Model.new(received: false) }
    Update = -> (msg, model) { model.with(received: true) }
  end

  def test_multiple_otherwise_first_matching_guard_wins
    test_class = Class.new do
      include Rooibos::Router

      route :tab_a, to: TestRouterOtherwiseFlat::TabA
      route :tab_b, to: TestRouterOtherwiseFlat::TabB

      otherwise route_to: :tab_a, when: -> (_msg, model) { model.active_tab == :a }
      otherwise route_to: :tab_b, when: -> (_msg, model) { model.active_tab == :b }
    end

    update = test_class.from_router
    model_class = Data.define(:tab_a, :tab_b, :active_tab)

    model_a = model_class.new(
      tab_a: TabA::Init.call,
      tab_b: TabB::Init.call,
      active_tab: :a
    )
    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), model_a)
    assert new_model.tab_a.received
    refute new_model.tab_b.received

    model_b = model_class.new(
      tab_a: TabA::Init.call,
      tab_b: TabB::Init.call,
      active_tab: :b
    )
    new_model2, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), model_b)
    refute new_model2.tab_a.received
    assert new_model2.tab_b.received
  end

  def test_otherwise_chains_through_hierarchy
    grandchild = Module.new do
      const_set :Model, Data.define(:messages)
      const_set :Init, -> { self::Model.new(messages: []) }
      const_set :Update, -> (msg, model) {
        [model.with(messages: model.messages + [msg]), nil]
      }
    end
    nested_router = Class.new do
      include Rooibos::Router

      route :grandchild, to: grandchild
      otherwise route_to: :grandchild

      const_set(:Update, from_router)
    end

    root_router = Class.new do
      include Rooibos::Router

      route :nested, to: nested_router
      otherwise route_to: :nested
    end

    update = root_router.from_router

    nested_model_class = Data.define(:grandchild)
    nested_model = nested_model_class.new(grandchild: grandchild::Init.call)

    root_model_class = Data.define(:nested)
    model = root_model_class.new(nested: nested_model)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), model)

    assert_equal 1, new_model.nested.grandchild.messages.size
  end
end
