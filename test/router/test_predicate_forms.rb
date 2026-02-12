# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterPredicateForms < Minitest::Test
  module TrackingChild
    Model = Data.define(:messages)
    Init = -> { Model.new(messages: []) }
    Update = -> (msg, model) { [model.with(messages: model.messages + [msg]), nil] }
  end

  def test_receive_with_predicate_matches_on_true
    received = false

    test_class = Class.new do
      include Rooibos::Router

      receive -> (msg, _) { msg.q? },
        -> (_msg, model) { received = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)
    assert received
  end

  def test_receive_with_predicate_skips_on_false
    received = false

    test_class = Class.new do
      include Rooibos::Router

      receive -> (msg, _) { msg.q? },
        -> (_msg, model) { received = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "x"), model)
    refute received
  end

  def test_receive_with_predicate_using_model
    received = false

    test_class = Class.new do
      include Rooibos::Router

      receive -> (msg, model) { msg.key? && model[:mode] == :insert },
        -> (msg, model) { received = true; model }
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "a"),
      Ractor.make_shareable({ mode: :normal }, copy: true))
    refute received

    update.call(RatatuiRuby::Event::Key.new(code: "a"),
      Ractor.make_shareable({ mode: :insert }, copy: true))
    assert received
  end

  def test_receive_with_complex_predicate
    received_chars = []

    test_class = Class.new do
      include Rooibos::Router

      receive -> (msg, model) { msg.key? && msg.text? && model[:mode] == :insert },
        -> (msg, model) {
          received_chars << msg.char
          model.merge(buffer: model[:buffer] + msg.char)
        }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ mode: :insert, buffer: "" }, copy: true)

    new_model = model
    %w[h e l l o].each do |char|
      new_model, _cmd = update.call(
        RatatuiRuby::Event::Key.new(code: char),
        new_model
      )
    end

    assert_equal %w[h e l l o], received_chars
    assert_equal "hello", new_model[:buffer]
  end

  def test_forward_with_predicate_matches_on_true
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterPredicateForms::TrackingChild

      forward -> (msg, _) { msg.key? && msg.ctrl? }, to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(
      RatatuiRuby::Event::Key.new(code: "c", modifiers: ["ctrl"]),
      model
    )
    assert_equal 1, new_model.child.messages.size
  end

  def test_forward_with_predicate_skips_on_false
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterPredicateForms::TrackingChild

      forward -> (msg, _) { msg.key? && msg.ctrl? }, to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(
      RatatuiRuby::Event::Key.new(code: "c"),
      model
    )
    assert_equal 0, new_model.child.messages.size
  end

  def test_forward_with_model_based_predicate
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterPredicateForms::TrackingChild

      forward -> (msg, model) { msg.key? && model.active }, to: :child
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

  def test_observe_with_predicate_matches_on_true
    observed = false

    test_class = Class.new do
      include Rooibos::Router

      observe -> (msg, _) { msg.shift? },
        -> (_msg, model) { observed = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "a", modifiers: ["shift"]), model)
    assert observed
  end

  def test_observe_with_predicate_continues_to_next_handler
    observe_called = false
    receive_called = false

    test_class = Class.new do
      include Rooibos::Router

      observe -> (msg, _) { msg.q? },
        -> (_msg, model) { observe_called = true; model }

      receive_events :q,
        -> (_msg, model) { receive_called = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert observe_called, "observe should run"
    assert receive_called, "receive should also run after observe"
  end

  def test_observe_with_predicate_matching_custom_message_types
    observed_milestone = nil
    observed_reset = nil

    milestone_class = Class.new(Data.define(:name)) do
      include Rooibos::Message::Predicates
    end

    reset_class = Class.new(Data.define(:count)) do
      include Rooibos::Message::Predicates
    end

    test_class = Class.new do
      include Rooibos::Router

      observe -> (msg, _) { msg.is_a?(milestone_class) || msg.is_a?(reset_class) },
        -> (msg, model) {
          if msg.is_a?(milestone_class)
            observed_milestone = msg.name
          else
            observed_reset = msg.count
          end
          model
        }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(milestone_class.new(name: :finished), model)
    assert_equal :finished, observed_milestone

    update.call(reset_class.new(count: 5), model)
    assert_equal 5, observed_reset
  end

  def test_predicate_validates_ractor_shareable_in_debug_mode
  end

  def test_predicate_allows_non_ractor_shareable_with_suppress_debug_mode
  end

  def test_receive_with_non_callable_predicate_raises_at_definition_time
  end

  def test_receive_events_with_invalid_key_type_raises_at_definition_time
  end

  def test_receive_instances_of_with_non_class_raises_at_definition_time
  end

  def test_predicate_lambda_with_arity_1_raises_descriptive_error_at_definition_time
  end

  def test_predicate_lambda_with_arity_3_plus_raises_descriptive_error_at_definition_time
  end

  def test_predicate_returning_truthy_value_matches
  end

  def test_predicate_returning_nil_does_not_match
  end

  def test_predicate_exception_propagates_to_caller
  end
end
