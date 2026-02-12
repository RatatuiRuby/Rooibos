# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterObserveFlat < Minitest::Test
  def test_observe_events_runs_handler_and_continues
    observed = false
    received = false

    test_class = Class.new do
      include Rooibos::Router

      observe_events :q, -> (_msg, model) {
        observed = true
        model.merge(observed: true)
      }

      receive_events :q, -> (_msg, model) {
        received = true
        model
      }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ observed: false }, copy: true)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert observed, "observe handler should run"
    assert received, "receive handler should run AFTER observe"
    assert_equal true, new_model[:observed], "model update from observe should persist"
  end

  def test_observe_events_with_action_reference
    @@observed = false

    test_class = Class.new do
      include Rooibos::Router

      action :log_quit, -> { @@observed = true; nil }
      observe_events :q, :log_quit
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert @@observed, "observe should dispatch to named action"
  end

  def test_observe_events_returns_command_alongside_flow
    test_class = Class.new do
      include Rooibos::Router

      observe_events :q, -> (_msg, model) {
        [model, Rooibos::Command.wait(0.01, :observed)]
      }

      receive_events :q, -> (_msg, model) {
        [model, Rooibos::Command.exit]
      }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    _new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal "Rooibos::Command::Separate", command.class.name
  end

  def test_observe_routed_observes_by_envelope
    observed_envelope = nil

    test_class = Class.new do
      include Rooibos::Router

      observe_routed :analytics, -> (msg, model) {
        observed_envelope = msg.envelope
        model
      }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    routed_msg = Rooibos::Message::Routed.new(
      envelope: :analytics,
      event: RatatuiRuby::Event::Key.new(code: "enter")
    )

    update.call(routed_msg, model)

    assert_equal :analytics, observed_envelope
  end

  class Milestone < Data.define(:name)
    include Rooibos::Message::Predicates
  end

  class LeafReset < Data.define(:count)
    include Rooibos::Message::Predicates
  end

  def test_observe_instances_of_observes_by_class
    observed_milestone = nil

    test_class = Class.new do
      include Rooibos::Router

      observe_instances_of TestRouterObserveFlat::Milestone,
        -> (msg, model) {
          observed_milestone = msg.name
          model.merge(milestones: (model[:milestones] || 0) + 1)
        }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(Milestone.new(name: :finished), model)

    assert_equal :finished, observed_milestone
  end

  def test_observe_instances_of_accumulates_count
    test_class = Class.new do
      include Rooibos::Router

      observe_instances_of TestRouterObserveFlat::LeafReset,
        -> (msg, model) {
          model.merge(resets: (model[:resets] || 0) + msg.count)
        }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ resets: 0 }, copy: true)

    new_model, _cmd = update.call(LeafReset.new(count: 5), model)

    assert_equal 5, new_model[:resets]
  end

  def test_observe_all_observes_every_message
    message_count = 0

    test_class = Class.new do
      include Rooibos::Router

      observer = -> (_msg, model) {
        message_count += 1
        model
      }

      observe_all observer
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "a"), model)
    update.call(RatatuiRuby::Event::Key.new(code: "b"), model)
    update.call(RatatuiRuby::Event::Key.new(code: "c"), model)

    assert_equal 3, message_count
  end

  def test_observe_all_with_guard
    observed = false

    test_class = Class.new do
      include Rooibos::Router

      observe_all -> (_msg, model) { observed = true; model },
        when: -> (_msg, model) { model[:debug] }
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "x"),
      Ractor.make_shareable({ debug: false }, copy: true))
    refute observed

    update.call(RatatuiRuby::Event::Key.new(code: "x"),
      Ractor.make_shareable({ debug: true }, copy: true))
    assert observed
  end

  def test_observe_with_predicate_lambda
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

  def test_multiple_observers_run_in_order
    order = []

    test_class = Class.new do
      include Rooibos::Router

      observe_events :q, -> (_msg, model) { order << :first; model }
      observe_events :q, -> (_msg, model) { order << :second; model }
      observe_events :q, -> (_msg, model) { order << :third; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal [:first, :second, :third], order
  end

  def test_multiple_observers_accumulate_model_changes
    test_class = Class.new do
      include Rooibos::Router

      observe_events :q, -> (_msg, model) { model.merge(a: 1) }
      observe_events :q, -> (_msg, model) { model.merge(b: 2) }
      observe_events :q, -> (_msg, model) { model.merge(c: model[:a] + model[:b]) }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal 1, new_model[:a]
    assert_equal 2, new_model[:b]
    assert_equal 3, new_model[:c]
  end

  def test_observe_handler_returns_nil_for_no_change
    test_class = Class.new do
      include Rooibos::Router

      observe_events :q, -> (_msg, _model) { nil }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ count: 42 }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal model, new_model
    assert_nil command
  end
end
