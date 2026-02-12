# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestRouterBubbleFlat < Minitest::Test
  include Rooibos::TestHelper

  class Milestone < Data.define(:envelope, :count)
    include Rooibos::Message::Predicates
  end

  class LeafReset < Data.define(:envelope, :count)
    include Rooibos::Message::Predicates
  end

  class PanelReset < Data.define(:envelope, :count)
    include Rooibos::Message::Predicates
  end

  def test_observe_instances_of_sees_bubbled_message
    observed_count = nil

    leaf = Module.new do
      const_set :Model, Data.define(:count)
      const_set :Init, -> { self::Model.new(count: 0) }
      const_set :Update, -> (msg, model) {
        if msg == :trigger
          [model, Rooibos::Command.bubble(TestRouterBubbleFlat::LeafReset.new(envelope: :leaf, count: 42))]
        else
          [model, nil]
        end
      }
    end

    root = Class.new do
      include Rooibos::Router

      route :leaf, to: leaf

      observe_instances_of TestRouterBubbleFlat::LeafReset,
        -> (msg, model) {
          observed_count = msg.count
          model.with(resets: model.resets + 1)
        }

      forward_all to: :leaf
    end

    update = root.from_router
    model_class = Data.define(:leaf, :resets)
    model = model_class.new(leaf: leaf::Init.call, resets: 0)

    new_model, _cmd = update.call(:trigger, model)

    assert_equal 42, observed_count, "observe should see bubbled message"
    assert_equal 1, new_model.resets, "model should be updated by observer"
  end

  def test_observe_continues_bubble_propagation
    first_observed = false
    second_observed = false

    leaf = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        if msg == :trigger
          [model, Rooibos::Command.bubble(TestRouterBubbleFlat::Milestone.new(envelope: :leaf, count: 1))]
        else
          [model, nil]
        end
      }
    end

    root = Class.new do
      include Rooibos::Router

      route :leaf, to: leaf

      observe_instances_of TestRouterBubbleFlat::Milestone,
        -> (msg, model) { first_observed = true; model }

      observe_instances_of TestRouterBubbleFlat::Milestone,
        -> (msg, model) { second_observed = true; model }

      forward_all to: :leaf
    end

    update = root.from_router
    model_class = Data.define(:leaf)
    model = model_class.new(leaf: leaf::Init.call)

    update.call(:trigger, model)

    assert first_observed, "first observer should run"
    assert second_observed, "second observer should also run"
  end

  def test_intercept_instances_of_stops_bubble
    mid_observed = false
    mid_intercepted = false
    outer_saw_it = false

    leaf = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        if msg == :trigger
          [model, Rooibos::Command.bubble(TestRouterBubbleFlat::LeafReset.new(envelope: :leaf, count: 10))]
        else
          [model, nil]
        end
      }
    end

    mid = Class.new do
      include Rooibos::Router

      route :leaf, to: leaf

      observe_instances_of TestRouterBubbleFlat::LeafReset,
        -> (msg, model) { mid_observed = true; model }

      intercept_instances_of TestRouterBubbleFlat::LeafReset,
        -> (msg, model) { mid_intercepted = true; model }

      forward_all to: :leaf

      const_set :Update, from_router
    end

    outer = Class.new do
      include Rooibos::Router

      route :mid, to: mid

      observe_instances_of TestRouterBubbleFlat::LeafReset,
        -> (msg, model) { outer_saw_it = true; model }

      forward_all to: :mid
    end

    update = outer.from_router
    model_class = Data.define(:mid)
    model = model_class.new(mid: Data.define(:leaf).new(leaf: leaf::Init.call))

    update.call(:trigger, model)

    assert mid_observed, "mid's observe should run (phase 1 before intercept)"
    assert mid_intercepted, "mid's intercept should run"
    refute outer_saw_it, "bubble should not propagate past mid's intercept"
  end

  def test_intercept_and_rebubble_transforms_message
    final_message = nil

    leaf = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        if msg == :trigger
          [model, Rooibos::Command.bubble(TestRouterBubbleFlat::LeafReset.new(envelope: :leaf, count: 5))]
        else
          [model, nil]
        end
      }
    end

    panel = Class.new do
      include Rooibos::Router

      route :leaf, to: leaf

      intercept_instances_of TestRouterBubbleFlat::LeafReset,
        -> (msg, model) {
          transformed = TestRouterBubbleFlat::PanelReset.new(envelope: :panel, count: msg.count)
          [model, Rooibos::Command.bubble(transformed)]
        }

      forward_all to: :leaf

      const_set :Update, from_router
    end

    root = Class.new do
      include Rooibos::Router

      route :panel, to: panel

      observe_instances_of TestRouterBubbleFlat::PanelReset,
        -> (msg, model) { final_message = msg; model }

      forward_all to: :panel
    end

    update = root.from_router
    panel_model = Data.define(:leaf).new(leaf: leaf::Init.call)
    root_model = Data.define(:panel).new(panel: panel_model)

    update.call(:trigger, root_model)

    assert_kind_of PanelReset, final_message, "Root should see transformed message"
    assert_equal :panel, final_message.envelope
    assert_equal 5, final_message.count
  end

  def test_deliver_skips_intermediate_fragments
    @@panel_saw_milestone = false
    @@root_saw_milestone = false

    leaf = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        case msg
        in { type: :key, code: "t" }
          [model, Rooibos::Command.deliver(TestRouterBubbleFlat::Milestone.new(envelope: :leaf, count: 5))]
        else
          [model, nil]
        end
      }
    end

    panel = Class.new do
      include Rooibos::Router

      route :leaf, to: leaf

      observe_instances_of TestRouterBubbleFlat::Milestone,
        -> (msg, model) { TestRouterBubbleFlat.class_variable_set(:@@panel_saw_milestone, true); model }

      otherwise route_to: :leaf

      const_set :Update, from_router
    end

    root = Class.new do
      include Rooibos::Router

      route :panel, to: panel
      forward_events :t, to: :panel

      action :quit, -> { Rooibos::Command.exit }
      receive_events :q, :quit

      observe_instances_of TestRouterBubbleFlat::Milestone,
        -> (msg, model) { TestRouterBubbleFlat.class_variable_set(:@@root_saw_milestone, true); model }

      const_set :Update, from_router
    end

    update = root.from_router
    panel_model = Data.define(:leaf).new(leaf: leaf::Init.call)
    root_model = Data.define(:panel).new(panel: panel_model)
    view = ClearView

    with_test_terminal do
      inject_key("t") # Trigger deliver
      inject_sync # Wait for command
      inject_key("q") # Quit
      Rooibos::Runtime.run(model: root_model, view:, update:)
    end

    refute @@panel_saw_milestone, "Panel should NOT see delivered message"
    assert @@root_saw_milestone, "Root should see delivered message"
  end

  def test_observe_with_predicate_matches_bubble
    observed = false

    leaf = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        if msg == :trigger
          [model, Rooibos::Command.bubble(TestRouterBubbleFlat::LeafReset.new(envelope: :leaf, count: 1))]
        else
          [model, nil]
        end
      }
    end

    root = Class.new do
      include Rooibos::Router

      route :leaf, to: leaf

      observe -> (msg, _) { msg.respond_to?(:leaf_reset?) && msg.leaf_reset? },
        -> (msg, model) { observed = true; model }

      forward_all to: :leaf
    end

    update = root.from_router
    model_class = Data.define(:leaf)
    model = model_class.new(leaf: leaf::Init.call)

    update.call(:trigger, model)

    assert observed, "observe with predicate should match bubbled message"
  end
end
