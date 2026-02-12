# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterIntercept < Minitest::Test
  def test_intercept_stops_further_processing
    receive_called = false
    intercept_called = false

    test_class = Class.new do
      include Rooibos::Router

      intercept lambda(&:q?),
        -> (msg, model) { intercept_called = true; model }

      receive_events :q, -> (_msg, model) { receive_called = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert intercept_called, "intercept handler should have been called"
    refute receive_called, "receive should NOT be called when intercept matches"
  end

  def test_intercept_returns_handler_result
    test_class = Class.new do
      include Rooibos::Router

      intercept lambda(&:q?),
        -> (msg, model) { [model.merge(intercepted: true), Rooibos::Command.exit] }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ intercepted: false }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:intercepted], "handler's model update should be returned"
    assert_kind_of Rooibos::Command::Exit, command, "handler's command should be returned"
  end

  def test_intercept_continues_on_no_match
    receive_called = false

    test_class = Class.new do
      include Rooibos::Router

      intercept lambda(&:x?),
        -> (msg, model) { model }

      receive_events :q, -> (_msg, model) { receive_called = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert receive_called, "receive should run when intercept predicate doesn't match"
  end

  def test_intercept_events_matches_key
    intercepted = false

    test_class = Class.new do
      include Rooibos::Router

      intercept_events :q, -> (_msg, model) { intercepted = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)
    assert intercepted
  end

  def test_intercept_events_does_not_match_other_keys
    intercepted = false

    test_class = Class.new do
      include Rooibos::Router

      intercept_events :q, -> (_msg, model) { intercepted = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "x"), model)
    refute intercepted
  end

  def test_receive_for_inward_messages
    received = false

    test_class = Class.new do
      include Rooibos::Router

      receive_events :enter, -> (_msg, model) { received = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)
    assert received
  end

  class LeafReset < Data.define(:envelope, :count)
    include Rooibos::Message::Predicates
  end

  def test_intercept_instances_of_matches_custom_message
    intercepted = false

    test_class = Class.new do
      include Rooibos::Router

      intercept_instances_of TestRouterIntercept::LeafReset,
        -> (msg, model) { intercepted = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(LeafReset.new(envelope: :leaf, count: 10), model)
    assert intercepted
  end

  def test_intercept_instances_of_stops_processing
    next_handler_called = false

    test_class = Class.new do
      include Rooibos::Router

      intercept_instances_of TestRouterIntercept::LeafReset,
        -> (msg, model) { model }

      receive_all -> (msg, model) { next_handler_called = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(LeafReset.new(envelope: :leaf, count: 10), model)
    refute next_handler_called, "receive_all should not run after intercept"
  end

  def test_intercept_routed_matches_envelope
    intercepted = false

    test_class = Class.new do
      include Rooibos::Router

      intercept_routed :panel_self, -> (_msg, model) { intercepted = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    routed_msg = Rooibos::Message::Routed.new(
      envelope: :panel_self,
      event: RatatuiRuby::Event::Key.new(code: "enter")
    )

    update.call(routed_msg, model)
    assert intercepted
  end

  def test_intercept_routed_does_not_match_other_envelopes
    intercepted = false

    test_class = Class.new do
      include Rooibos::Router

      intercept_routed :panel_self, -> (_msg, model) { intercepted = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    routed_msg = Rooibos::Message::Routed.new(
      envelope: :other_route,
      event: RatatuiRuby::Event::Key.new(code: "enter")
    )

    update.call(routed_msg, model)
    refute intercepted
  end

  def test_intercept_all_matches_any_message
    intercepted = false

    test_class = Class.new do
      include Rooibos::Router

      intercept_all -> (_msg, model) { intercepted = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "x"), model)
    assert intercepted
  end

  def test_intercept_handler_receives_message_and_model
    received_message = nil
    received_model = nil

    test_class = Class.new do
      include Rooibos::Router

      intercept lambda(&:q?),
        -> (msg, model) {
          received_message = msg
          received_model = model
          model
        }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ count: 42 }, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_kind_of RatatuiRuby::Event::Key, received_message
    assert_equal 42, received_model[:count]
  end

  def test_intercept_events_with_guard
    intercepted = false

    test_class = Class.new do
      include Rooibos::Router

      intercept_events :q, -> (_msg, model) { intercepted = true; model },
        when: -> (_msg, model) { model[:can_intercept] }
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ can_intercept: false }, copy: true))
    refute intercepted

    update.call(RatatuiRuby::Event::Key.new(code: "q"),
      Ractor.make_shareable({ can_intercept: true }, copy: true))
    assert intercepted
  end

  def test_intercept_nil_return_preserves_model
    test_class = Class.new do
      include Rooibos::Router

      intercept lambda(&:q?), -> (_msg, _model) { nil }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ count: 42 }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal 42, new_model[:count]
    assert_nil command
  end

  def test_intercept_returns_model_only
    test_class = Class.new do
      include Rooibos::Router

      intercept lambda(&:q?),
        -> (_msg, model) { model.merge(intercepted: true) }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:intercepted]
    assert_nil command
  end

  def test_intercept_returns_command_only
    test_class = Class.new do
      include Rooibos::Router

      intercept lambda(&:q?), -> (_msg, _model) { Rooibos::Command.exit }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ value: 42 }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal 42, new_model[:value], "model should be unchanged"
    assert_kind_of Rooibos::Command::Exit, command
  end
end
