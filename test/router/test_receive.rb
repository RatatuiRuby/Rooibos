# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterReceive < Minitest::Test
  def test_receive_events_matches_key_event_by_symbol
    received = false

    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) { received = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert received, "receive_events should match key event by symbol"
  end

  def test_receive_events_with_action_reference
    test_class = Class.new do
      include Rooibos::Router

      action :quit, -> { Rooibos::Command.exit }
      receive_events :q, :quit
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    _new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_kind_of Rooibos::Command::Exit, command
  end

  def test_receive_events_stops_further_processing
    first_called = false
    second_called = false

    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) { first_called = true; model }
      receive_events :q, -> (_msg, model) { second_called = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert first_called, "first receive should run"
    refute second_called, "second receive should NOT run - first stopped processing"
  end

  def test_receive_events_with_multiple_keys
    received = false

    test_class = Class.new do
      include Rooibos::Router

      receive_events [:q, :ctrl_c], -> (_msg, model) { received = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "c", modifiers: ["ctrl"]), model)

    assert received, "receive_events with array should match any listed key"
  end

  def test_receive_routed_matches_by_envelope
    received_envelope = nil

    test_class = Class.new do
      include Rooibos::Router

      receive_routed :panel_self, -> (msg, model) {
        received_envelope = msg.envelope
        model
      }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    routed_msg = Rooibos::Message::Routed.new(
      envelope: :panel_self,
      event: RatatuiRuby::Event::Key.new(code: "enter")
    )

    update.call(routed_msg, model)

    assert_equal :panel_self, received_envelope
  end

  def test_receive_routed_stops_processing
    first_called = false
    second_called = false

    test_class = Class.new do
      include Rooibos::Router

      receive_routed :submit, -> (_msg, model) { first_called = true; model }
      receive_routed :submit, -> (_msg, model) { second_called = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    routed_msg = Rooibos::Message::Routed.new(
      envelope: :submit,
      event: RatatuiRuby::Event::Key.new(code: "enter")
    )

    update.call(routed_msg, model)

    assert first_called
    refute second_called
  end

  class FatalError < Data.define(:message)
    include Rooibos::Message::Predicates
  end

  class ThemeChanged < Data.define(:theme)
    include Rooibos::Message::Predicates
  end

  def test_receive_instances_of_matches_by_class
    received_message = nil

    test_class = Class.new do
      include Rooibos::Router

      receive_instances_of TestRouterReceive::FatalError,
        -> (msg, model) { received_message = msg; [model, Rooibos::Command.exit] }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    error = FatalError.new(message: "crash")
    _new_model, command = update.call(error, model)

    assert_equal error, received_message
    assert_kind_of Rooibos::Command::Exit, command
  end

  def test_receive_instances_of_stops_processing
    first_called = false
    second_called = false

    test_class = Class.new do
      include Rooibos::Router

      receive_instances_of TestRouterReceive::ThemeChanged,
        -> (_msg, model) { first_called = true; model }
      receive_instances_of TestRouterReceive::ThemeChanged,
        -> (_msg, model) { second_called = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(ThemeChanged.new(theme: :dark), model)

    assert first_called
    refute second_called
  end

  def test_receive_all_matches_any_message
    received = false

    test_class = Class.new do
      include Rooibos::Router

      receive_all -> (_msg, model) { received = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "x"), model)

    assert received
  end

  def test_receive_all_with_guard_blocks_when_guard_fails
    received = false

    test_class = Class.new do
      include Rooibos::Router

      receive_all -> (_msg, model) { received = true; model },
        when: -> (_msg, model) { model[:active] }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ active: false }, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "x"), model)

    refute received, "receive_all should not run when guard fails"
  end

  def test_receive_with_predicate_lambda
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

  def test_receive_handler_returns_nil_for_no_change
    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, _model) { nil }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ count: 42 }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal model, new_model
    assert_nil command
  end

  def test_receive_handler_returns_model_only
    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) { model.merge(count: model[:count] + 1) }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ count: 0 }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal 1, new_model[:count]
    assert_nil command
  end

  def test_receive_handler_returns_command_only
    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, _model) { Rooibos::Command.exit }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ count: 42 }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal model, new_model
    assert_kind_of Rooibos::Command::Exit, command
  end

  def test_receive_handler_returns_tuple
    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) {
        [model.merge(quit: true), Rooibos::Command.exit]
      }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ quit: false }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:quit]
    assert_kind_of Rooibos::Command::Exit, command
  end

  def test_receive_events_with_when_guard
    received = false

    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) { received = true; model },
        when: -> (_msg, model) { model[:active] }
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ active: false }, copy: true))
    refute received

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ active: true }, copy: true))
    assert received
  end

  def test_receive_events_with_unless_guard
    received = false

    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) { received = true; model },
        unless: -> (_msg, model) { model[:locked] }
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ locked: true }, copy: true))
    refute received

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ locked: false }, copy: true))
    assert received
  end

  def test_receive_handler_validates_ractor_shareable_in_debug_mode
  end

  def test_receive_handler_allows_non_ractor_shareable_with_suppress_debug_mode
  end

  def test_receive_handler_with_arity_1_raises_descriptive_error_at_definition_time
  end

  def test_receive_handler_with_arity_3_plus_raises_descriptive_error_at_definition_time
  end

  def test_receive_with_non_callable_handler_raises_argument_error_at_definition_time
  end

  def test_receive_events_with_empty_array_matches_nothing
  end

  def test_receive_events_with_duplicate_keys_in_array_handles_once
  end
end
