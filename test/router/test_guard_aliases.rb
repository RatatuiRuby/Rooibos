# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterGuardAliases < Minitest::Test
  def test_receive_events_with_when_guard
    called = false

    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) { called = true; model },
        when: -> (_msg, model) { model[:active] }
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ active: false }, copy: true))
    refute called

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ active: true }, copy: true))
    assert called
  end

  def test_receive_events_with_if_guard
    called = false

    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) { called = true; model },
        if: -> (_msg, model) { model[:active] }
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ active: false }, copy: true))
    refute called

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ active: true }, copy: true))
    assert called
  end

  def test_receive_events_with_only_guard
    called = false

    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) { called = true; model },
        only: -> (_msg, model) { model[:active] }
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ active: false }, copy: true))
    refute called

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ active: true }, copy: true))
    assert called
  end

  def test_receive_events_with_guard_guard
    called = false

    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) { called = true; model },
        guard: -> (_msg, model) { model[:active] }
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ active: false }, copy: true))
    refute called

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ active: true }, copy: true))
    assert called
  end

  def test_receive_events_with_unless_guard
    called = false

    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) { called = true; model },
        unless: -> (_msg, model) { model[:locked] }
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ locked: true }, copy: true))
    refute called

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ locked: false }, copy: true))
    assert called
  end

  def test_receive_events_with_except_guard
    called = false

    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) { called = true; model },
        except: -> (_msg, model) { model[:locked] }
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ locked: true }, copy: true))
    refute called

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ locked: false }, copy: true))
    assert called
  end

  def test_receive_events_with_skip_guard
    called = false

    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) { called = true; model },
        skip: -> (_msg, model) { model[:locked] }
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ locked: true }, copy: true))
    refute called

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ locked: false }, copy: true))
    assert called
  end

  module TrackingChild
    Model = Data.define(:messages)
    Init = -> { Model.new(messages: []) }
    Update = -> (msg, model) { [model.with(messages: model.messages + [msg]), nil] }
  end

  def test_forward_events_with_when_guard
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterGuardAliases::TrackingChild

      forward_events :enter, to: :child,
        when: -> (_msg, model) { model.active }
    end

    update = test_class.from_router
    model_class = Data.define(:child, :active)

    inactive = model_class.new(child: TrackingChild::Init.call, active: false)
    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), inactive)
    assert_equal 0, new_model.child.messages.size

    active = model_class.new(child: TrackingChild::Init.call, active: true)
    new_model2, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), active)
    assert_equal 1, new_model2.child.messages.size
  end

  def test_observe_events_with_unless_guard
    observed = false

    test_class = Class.new do
      include Rooibos::Router

      observe_events :q, -> (_msg, model) { observed = true; model },
        unless: -> (_msg, model) { model[:silent] }
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ silent: true }, copy: true))
    refute observed

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ silent: false }, copy: true))
    assert observed
  end

  def test_otherwise_with_when_guard
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterGuardAliases::TrackingChild

      otherwise route_to: :child, when: -> (_msg, model) { model.active }
    end

    update = test_class.from_router
    model_class = Data.define(:child, :active)

    inactive = model_class.new(child: TrackingChild::Init.call, active: false)
    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), inactive)
    assert_equal 0, new_model.child.messages.size

    active = model_class.new(child: TrackingChild::Init.call, active: true)
    new_model2, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), active)
    assert_equal 1, new_model2.child.messages.size
  end

  def test_guard_lambda_validates_ractor_shareable_in_debug_mode
  end

  def test_guard_lambda_allows_non_ractor_shareable_with_suppress_debug_mode
  end

  def test_guard_with_arity_1_raises_descriptive_error_at_definition_time
  end

  def test_guard_with_arity_3_plus_raises_descriptive_error_at_definition_time
  end

  def test_non_callable_guard_raises_argument_error_at_definition_time
  end
end
