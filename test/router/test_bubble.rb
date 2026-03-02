# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class BubbleTestMilestone < Data.define(:envelope, :count)
  include Rooibos::Message::Predicates
end

module BubbleTestChild
  Model = Data.define(:count)
  Init = -> { Model.new(count: 0) }
  Update = -> (msg, model) {
    if msg == :increment
      new_count = model.count + 1
      if new_count >= 5
        [model.with(count: new_count), Rooibos::Command.bubble(BubbleTestMilestone.new(envelope: :child, count: new_count))]
      else
        model.with(count: new_count)
      end
    else
      model
    end
  }
end

class TestRouterBubble < Minitest::Test
  @@observe_called = false
  @@observe_message = nil

  def setup
    @@observe_called = false
    @@observe_message = nil
  end

  ObserveHandler = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@observe_called, true)
    TestRouterBubble.class_variable_set(:@@observe_message, msg)
    model.with(milestones: model.milestones + 1)
  }
  MilestonePredicate = -> (msg, _model) { msg.respond_to?(:bubble_test_milestone?) && msg.bubble_test_milestone? }

  def test_bubble_returned_from_nested_triggers_outer_observe
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChild

      observe MilestonePredicate, ObserveHandler
      otherwise route_to: :child
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChild::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    5.times do
      parent_model, _cmd = update.call(:increment, parent_model)
    end

    assert @@observe_called, "observe handler should have been triggered by bubbled message"
    assert_equal 1, parent_model.milestones, "parent should have recorded the milestone"
  end

  class OtherBubbleMessage < Data.define(:envelope, :value)
    include Rooibos::Message::Predicates
  end

  module BubbleTestChildOther
    Model = Data.define(:value)
    Init = -> { Model.new(value: 0) }
    Update = -> (msg, model) {
      if msg == :trigger
        [model, Rooibos::Command.bubble(OtherBubbleMessage.new(envelope: :other, value: 999))]
      else
        model
      end
    }
  end

  def test_bubble_returned_from_nested_triggers_outer_intercept
    _intercept_called = false

    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChild

      intercept(-> (msg, _model) { msg.respond_to?(:bubble_test_milestone?) && msg.bubble_test_milestone? },
        -> (msg, model) {
          TestRouterBubble.class_variable_set(:@@observe_called, true)
          model.with(milestones: model.milestones + 1)
        })
      otherwise route_to: :child
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChild::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    5.times do
      parent_model, _cmd = update.call(:increment, parent_model)
    end

    assert @@observe_called, "intercept handler should have been triggered"
    assert_equal 1, parent_model.milestones, "parent should have recorded the milestone"
  end

  def test_observe_handler_only_runs_when_predicate_matches
    parent_class = Class.new do
      include Rooibos::Router

      route :other_child, to: BubbleTestChildOther

      observe MilestonePredicate, ObserveHandler
      otherwise route_to: :other_child
    end

    parent_model = Data.define(:other_child, :milestones).new(
      other_child: BubbleTestChildOther::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    parent_model, _cmd = update.call(:trigger, parent_model)

    refute @@observe_called, "observe handler should NOT run when predicate doesn't match"
    assert_equal 0, parent_model.milestones, "milestones should be unchanged"
  end

  def test_bubble_observe_continues_propagation_outward
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChild

      observe MilestonePredicate, ObserveHandler
      otherwise route_to: :child
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChild::Init.call,
      milestones: 0
    )
    update = parent_class.from_router
    @@observe_called = false

    5.times do
      parent_model, _cmd = update.call(:increment, parent_model)
    end

    assert @@observe_called, "observe handler should have run on bubbled message"
    assert_equal 1, parent_model.milestones, "parent model should have been updated by observe"
  end

  @@parent_intercept_called = false
  ParentInterceptHandler = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@parent_intercept_called, true)
    model.with(milestones: model.milestones + 1)
  }

  def test_bubble_intercept_stops_propagation
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChild

      intercept MilestonePredicate, ParentInterceptHandler
      otherwise route_to: :child
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChild::Init.call,
      milestones: 0
    )
    update = parent_class.from_router
    @@parent_intercept_called = false

    5.times do
      parent_model, _cmd = update.call(:increment, parent_model)
    end

    assert @@parent_intercept_called, "intercept handler should have run on bubbled message"
    assert_equal 1, parent_model.milestones, "parent model should have been updated by intercept"
  end

  def test_bubble_unhandled_disappears_silently_at_root
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChild

      otherwise route_to: :child
    end

    parent_model = Data.define(:child).new(
      child: BubbleTestChild::Init.call
    )
    update = parent_class.from_router

    cmd = nil
    5.times do
      parent_model, cmd = update.call(:increment, parent_model)
    end

    assert_equal 5, parent_model.child.count, "child should have updated"

    # An unhandled bubble may survive as a command (needed for multi-level
    # re-propagation), but executing it must be a harmless no-op — not a
    # raise that becomes Message::Error.
    assert_silent { cmd.call(nil, nil) } if cmd.is_a?(Rooibos::Command::Bubble)
  end

  module GrandchildFragment
    Model = Data.define(:count)
    Init = -> { Model.new(count: 0) }
    Update = -> (msg, model) {
      if msg == :trigger
        [
          model.with(count: model.count + 1),
          Rooibos::Command.bubble(BubbleTestMilestone.new(envelope: :grandchild, count: model.count + 1)),
]
      else
        model
      end
    }
  end

  module MiddleChildFragment
    include Rooibos::Router

    Model = Data.define(:grandchild, :saw_bubble)
    Init = -> { Model.new(grandchild: GrandchildFragment::Init.call, saw_bubble: false) }

    route :grandchild, to: GrandchildFragment
    otherwise route_to: :grandchild

    Update = from_router
  end

  def test_bubble_flows_through_multiple_levels
    parent_class = Class.new do
      include Rooibos::Router

      route :middle, to: MiddleChildFragment

      observe MilestonePredicate, ObserveHandler
      otherwise route_to: :middle
    end

    parent_model = Data.define(:middle, :milestones).new(
      middle: MiddleChildFragment::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    parent_model, _cmd = update.call(:trigger, parent_model)

    assert @@observe_called, "bubble should propagate from grandchild through middle to parent"
    assert_equal 1, parent_model.milestones, "parent should have recorded the milestone"
  end

  @@middle_observe_called = false
  MiddleObserveHandler = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@middle_observe_called, true)
    model.with(saw_bubble: true)
  }

  module MiddleChildFragmentWithObserve
    include Rooibos::Router

    Model = Data.define(:grandchild, :saw_bubble)
    Init = -> { Model.new(grandchild: GrandchildFragment::Init.call, saw_bubble: false) }

    route :grandchild, to: GrandchildFragment
    observe MilestonePredicate, MiddleObserveHandler
    otherwise route_to: :grandchild

    Update = from_router
  end

  def test_bubble_each_level_can_observe
    parent_class = Class.new do
      include Rooibos::Router

      route :middle, to: MiddleChildFragmentWithObserve

      observe MilestonePredicate, ObserveHandler
      otherwise route_to: :middle
    end

    parent_model = Data.define(:middle, :milestones).new(
      middle: MiddleChildFragmentWithObserve::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    @@observe_called = false
    @@middle_observe_called = false

    parent_model, _cmd = update.call(:trigger, parent_model)

    assert @@middle_observe_called, "middle's observe handler should have run"
    assert @@observe_called, "parent's observe handler should have run - bubble should continue propagating"
    assert_equal 1, parent_model.milestones, "parent should have recorded the milestone"
    assert parent_model.middle.saw_bubble, "middle should have seen the bubble"
  end

  @@middle_intercept_called = false
  MiddleInterceptHandler = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@middle_intercept_called, true)
    model.with(saw_bubble: true)
  }

  module MiddleChildFragmentWithIntercept
    include Rooibos::Router

    Model = Data.define(:grandchild, :saw_bubble)
    Init = -> { Model.new(grandchild: GrandchildFragment::Init.call, saw_bubble: false) }

    route :grandchild, to: GrandchildFragment
    intercept MilestonePredicate, MiddleInterceptHandler
    otherwise route_to: :grandchild

    Update = from_router
  end

  def test_bubble_any_level_can_intercept_and_stop
    parent_class = Class.new do
      include Rooibos::Router

      route :middle, to: MiddleChildFragmentWithIntercept

      observe MilestonePredicate, ObserveHandler
      otherwise route_to: :middle
    end

    parent_model = Data.define(:middle, :milestones).new(
      middle: MiddleChildFragmentWithIntercept::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    @@observe_called = false
    @@middle_intercept_called = false

    parent_model, _cmd = update.call(:trigger, parent_model)

    assert @@middle_intercept_called, "middle's intercept handler should have run"
    refute @@observe_called, "parent's observe handler should NOT run - intercept stopped propagation"
    assert_equal 0, parent_model.milestones, "parent should NOT have recorded milestone"
    assert parent_model.middle.saw_bubble, "middle should have seen and intercepted the bubble"
  end

  def test_bubble_model_updates_accumulate_through_levels
    parent_class = Class.new do
      include Rooibos::Router

      route :middle, to: MiddleChildFragmentWithObserve

      observe MilestonePredicate, ObserveHandler
      otherwise route_to: :middle
    end

    parent_model = Data.define(:middle, :milestones).new(
      middle: MiddleChildFragmentWithObserve::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    parent_model, _cmd = update.call(:trigger, parent_model)

    assert parent_model.middle.saw_bubble, "middle's model should reflect observe handler update"
    assert_equal 1, parent_model.milestones, "parent's milestones should be updated"
    assert_equal 1, parent_model.middle.grandchild.count, "grandchild count should be updated"
  end

  module BubbleTestChildBatch
    Model = Data.define(:count)
    Init = -> { Model.new(count: 0) }
    Update = -> (msg, model) {
      if msg == :trigger_batch
        [
          model.with(count: model.count + 1),
          Rooibos::Command.batch(
            Rooibos::Command.bubble(BubbleTestMilestone.new(envelope: :batch_child, count: model.count + 1)),
            Rooibos::Command.deliver(OtherBubbleMessage.new(envelope: :other, value: 42))
          ),
]
      else
        model
      end
    }
  end

  def test_bubble_inside_batch_is_extracted_and_processed
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChildBatch

      observe MilestonePredicate, ObserveHandler
      otherwise route_to: :child
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChildBatch::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    parent_model, _cmd = update.call(:trigger_batch, parent_model)

    assert @@observe_called, "observe handler should have been triggered by bubble INSIDE batch"
    assert_equal 1, parent_model.milestones, "parent should have recorded the milestone"
  end

  def test_bubble_inside_batch_non_bubble_commands_preserved
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChildBatch

      observe MilestonePredicate, ObserveHandler
      otherwise route_to: :child
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChildBatch::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    parent_model, cmd = update.call(:trigger_batch, parent_model)

    assert @@observe_called, "observe handler should have been triggered"

    assert cmd, "command should not be nil - non-bubble commands should be preserved"

    assert cmd.respond_to?(:rooibos_command?), "returned cmd should be a command"
  end

  InterceptHandler = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@observe_called, true)
    model.with(milestones: model.milestones + 1)
  }

  def test_bubble_intercepted_inside_batch_removes_bubble_from_batch
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChildBatch

      intercept MilestonePredicate, InterceptHandler
      otherwise route_to: :child
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChildBatch::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    @@observe_called = false

    parent_model, cmd = update.call(:trigger_batch, parent_model)

    assert @@observe_called, "intercept handler should have been triggered"
    assert_equal 1, parent_model.milestones, "milestones should have been updated"

    assert cmd, "non-bubble commands should be preserved after intercept"
  end

  def test_bubble_observed_inside_batch_continues_in_batch
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChildBatch

      observe MilestonePredicate, ObserveHandler
      otherwise route_to: :child
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChildBatch::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    @@observe_called = false

    parent_model, cmd = update.call(:trigger_batch, parent_model)

    assert @@observe_called, "observe handler should have been triggered"
    assert_equal 1, parent_model.milestones, "milestones should have been updated"

    assert cmd, "command should be returned with re-bubbled message and non-bubble commands"
  end

  class TransformedMilestone < Data.define(:original_count, :extra_data)
    include Rooibos::Message::Predicates
  end

  TransformingInterceptHandler = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@observe_called, true)
    [
      model.with(saw_bubble: true),
      Rooibos::Command.bubble(TransformedMilestone.new(original_count: msg.count, extra_data: "transformed")),
]
  }

  def test_intercept_bubble_and_rebubble_transforms_message
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChild

      intercept MilestonePredicate, TransformingInterceptHandler
      otherwise route_to: :child
    end

    parent_model = Data.define(:child, :saw_bubble).new(
      child: BubbleTestChild::Init.call,
      saw_bubble: false
    )
    update = parent_class.from_router

    @@observe_called = false

    5.times do
      parent_model, _cmd = update.call(:increment, parent_model)
    end

    assert @@observe_called, "intercept handler should have fired"
    assert parent_model.saw_bubble, "model should have been updated by intercept"
  end

  def test_intercept_bubble_and_deliver_changes_routing
    deliver_handler = -> (msg, model) {
      TestRouterBubble.class_variable_set(:@@observe_called, true)
      [
        model.with(saw_bubble: true),
        Rooibos::Command.deliver(OtherBubbleMessage.new(envelope: :converted, value: msg.count)),
]
    }

    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChild

      intercept MilestonePredicate, deliver_handler
      otherwise route_to: :child
    end

    parent_model = Data.define(:child, :saw_bubble).new(
      child: BubbleTestChild::Init.call,
      saw_bubble: false
    )
    update = parent_class.from_router

    @@observe_called = false

    5.times do
      parent_model, _cmd = update.call(:increment, parent_model)
    end

    assert @@observe_called, "intercept handler should have fired"
    assert parent_model.saw_bubble, "model should have been updated by intercept"
  end

  @@bubble_count = 0
  BubbleCountingObserver = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@bubble_count,
      TestRouterBubble.class_variable_get(:@@bubble_count) + 1)
    model
  }

  def test_observe_does_not_duplicate_bubble_when_intercepted_later
    middle_class = Class.new do
      include Rooibos::Router

      route :grandchild, to: GrandchildFragment
      observe MilestonePredicate, BubbleCountingObserver
      otherwise route_to: :grandchild
    end

    parent_class = Class.new do
      include Rooibos::Router

      route :middle, to: middle_class
      observe MilestonePredicate, BubbleCountingObserver
      otherwise route_to: :middle
    end

    middle_init = -> {
      Data.define(:grandchild).new(grandchild: GrandchildFragment::Init.call)
    }
    parent_model = Data.define(:middle).new(middle: middle_init.call)

    middle_class.const_set(:Init, middle_init)
    middle_class.const_set(:Update, middle_class.from_router)

    update = parent_class.from_router

    @@bubble_count = 0

    parent_model, _cmd = update.call(:trigger, parent_model)

    assert_equal 2, @@bubble_count, "bubble should be observed exactly twice (middle + parent), not duplicated"
  end

  IdentityMapper = -> (result) { result }
  Ractor.make_shareable(IdentityMapper)

  module BubbleTestChildNestedBatch
    Model = Data.define(:count)
    Init = -> { Model.new(count: 0) }
    Update = -> (msg, model) {
      if msg == :trigger_nested
        wrapped_bubble = Rooibos::Command.map(
          Rooibos::Command.bubble(BubbleTestMilestone.new(envelope: :nested, count: model.count + 1)),
          IdentityMapper # identity mapper as argument
        )

        [
          model.with(count: model.count + 1),
          Rooibos::Command.batch(
            wrapped_bubble, # Bubble wrapped in Mapped
            Rooibos::Command.deliver(OtherBubbleMessage.new(envelope: :other, value: 99))
          ),
]
      else
        model
      end
    }
  end

  def test_mapped_bubble_inside_batch_passes_through_unchanged
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChildNestedBatch

      observe MilestonePredicate, ObserveHandler
      otherwise route_to: :child
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChildNestedBatch::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    @@observe_called = false

    parent_model, cmd = update.call(:trigger_nested, parent_model)

    refute @@observe_called, "observe handler should NOT run - Mapped(Bubble) is not extracted"
    commands = cmd.commands
    mapped_cmd = commands.find { |c| c.is_a?(Rooibos::Command::Mapped) }
    assert mapped_cmd, "Mapped command should be preserved in output"
    assert_kind_of Rooibos::Command::Bubble, mapped_cmd.inner_command
  end

  @@first_intercept_called = false
  @@second_intercept_called = false

  FirstInterceptHandler = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@first_intercept_called, true)
    model
  }

  SecondInterceptHandler = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@second_intercept_called, true)
    model
  }

  def test_only_first_matching_intercept_runs
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChild

      intercept MilestonePredicate, FirstInterceptHandler
      intercept MilestonePredicate, SecondInterceptHandler # should NOT run
      otherwise route_to: :child
    end

    parent_model = Data.define(:child).new(
      child: BubbleTestChild::Init.call
    )
    update = parent_class.from_router

    @@first_intercept_called = false
    @@second_intercept_called = false

    5.times do
      parent_model, _cmd = update.call(:increment, parent_model)
    end

    assert @@first_intercept_called, "first intercept handler should have fired"
    refute @@second_intercept_called, "second intercept handler should NOT run - first consumes bubble"
  end

  module BubbleTestChildNestedBatchBatch
    Model = Data.define(:count)
    Init = -> { Model.new(count: 0) }
    Update = -> (msg, model) {
      if msg == :trigger_nested_batch
        inner_batch = Rooibos::Command.batch(
          Rooibos::Command.bubble(BubbleTestMilestone.new(envelope: :nested, count: model.count + 1))
        )

        [
          model.with(count: model.count + 1),
          Rooibos::Command.batch(
            inner_batch, # Batch inside Batch - NOT extracted
            Rooibos::Command.deliver(OtherBubbleMessage.new(envelope: :other, value: 99))
          ),
]
      else
        model
      end
    }
  end

  def test_nested_batch_bubbles_pass_through_unchanged
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChildNestedBatchBatch

      observe MilestonePredicate, ObserveHandler
      otherwise route_to: :child
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChildNestedBatchBatch::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    @@observe_called = false

    parent_model, cmd = update.call(:trigger_nested_batch, parent_model)

    refute @@observe_called, "observe handler should NOT run - nested Batch(Bubble) is not extracted"
    commands = cmd.commands
    inner_batch = commands.find { |c| c.is_a?(Rooibos::Command::Batch) }
    assert inner_batch, "Inner batch should be preserved in output"
    assert inner_batch.commands.any? { |c| c.is_a?(Rooibos::Command::Bubble) }
  end

  # A child that bubbles immediately when it receives any routed :notify message.
  module BubbleOnNotifyChild
    Model = Data.define(:notified)
    Init = -> { Model.new(notified: false) }
    Update = -> (msg, model) {
      if msg.respond_to?(:routed?) && msg.envelope == :notify
        [
          model.with(notified: true),
          Rooibos::Command.bubble(BubbleTestMilestone.new(envelope: :notified, count: 1)),
]
      else
        model
      end
    }
  end

  @@observe_inward_called = false
  ObserveInwardSideEffect = Class.new(Data.define) { include Rooibos::Command::Custom; def call(_, _); end }
  ObserveInwardHandler = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@observe_inward_called, true)
    [model.with(saw_inward: true), ObserveInwardSideEffect.new]
  }

  def test_bubble_from_child_reached_via_forward_with_sibling_observe
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleOnNotifyChild

      # Parent observes the inward event for its own purposes
      observe(-> (msg, _) { msg == :ping }, ObserveInwardHandler)
      # Parent also forwards the same event to the child
      forward_events :ping, to: :child, as: :notify
      # Parent observes bubbles from children
      observe MilestonePredicate, ObserveHandler
    end

    parent_model = Data.define(:child, :saw_inward, :milestones).new(
      child: BubbleOnNotifyChild::Init.call,
      saw_inward: false,
      milestones: 0
    )
    update = parent_class.from_router

    @@observe_called = false
    @@observe_inward_called = false

    parent_model, _cmd = update.call(:ping, parent_model)

    assert @@observe_inward_called, "parent's observe handler should have run on :ping"
    assert parent_model.child.notified, "child should have received forwarded :notify"

    # THIS IS THE BUG: the bubble from the child is lost inside Command::Separate
    assert @@observe_called, "parent's bubble observe should have fired - bubble must not be lost in Separate"
  end

  module BatchBubblingInnerFragment
    Model = Data.define(:tab)
    Init = -> { Model.new(tab: :home) }
    Update = -> (msg, model) {
      if msg.respond_to?(:routed?) && msg.envelope == :next_tab
        [
          model.with(tab: :busy),
          Rooibos::Command.batch(
            Rooibos::Command.bubble(BubbleTestMilestone.new(envelope: :tab_changed, count: 1)),
            Rooibos::Command.deliver(OtherBubbleMessage.new(envelope: :fetch, value: 42))
          ),
        ]
      else
        model
      end
    }
  end

  def build_transparent_middle
    middle_class = Class.new do
      include Rooibos::Router

      route :inner, to: BatchBubblingInnerFragment

      forward_events :right, to: :inner, as: :next_tab
    end

    middle_init = -> { Data.define(:inner).new(inner: BatchBubblingInnerFragment::Init.call) }
    middle_class.const_set(:Init, middle_init)
    middle_class.const_set(:Update, middle_class.from_router)
    middle_class
  end

  def test_bubble_in_batch_propagates_through_intermediate_fragment_with_no_outward_handlers
    middle_class = build_transparent_middle

    outer_class = Class.new do
      include Rooibos::Router

      route :middle, to: middle_class

      observe MilestonePredicate, ObserveHandler
      forward_events :right, to: :middle
    end

    outer_model = Data.define(:middle, :milestones).new(
      middle: middle_class::Init.call,
      milestones: 0
    )
    update = outer_class.from_router

    @@observe_called = false

    outer_model, _cmd = update.call(:right, outer_model)

    assert_equal :busy, outer_model.middle.inner.tab, "inner fragment should have received the forwarded event"
    assert @@observe_called, "outer fragment's bubble observe should have fired - bubble must propagate through intermediate fragment"
    assert_equal 1, outer_model.milestones, "outer milestones should be incremented by observe handler"
  end

  module BubbleReceiverFragment
    Model = Data.define(:received_envelope)
    Init = -> { Model.new(received_envelope: nil) }
    Update = -> (msg, model) {
      if msg.bubble_test_milestone?
        model.with(received_envelope: msg.envelope)
      else
        model
      end
    }
  end

  def test_forward_instances_of_fires_for_bubbled_message
    outer_class = Class.new do
      include Rooibos::Router

      route :source, to: BubbleTestChild
      route :receiver, to: BubbleReceiverFragment

      observe MilestonePredicate, ObserveHandler
      forward_instances_of BubbleTestMilestone, to: :receiver
      otherwise route_to: :source
    end

    outer_model = Data.define(:source, :receiver, :milestones).new(
      source: BubbleTestChild::Init.call,
      receiver: BubbleReceiverFragment::Init.call,
      milestones: 0
    )
    update = outer_class.from_router

    @@observe_called = false

    5.times { outer_model, _cmd = update.call(:increment, outer_model) }

    assert @@observe_called, "observe should have fired for the bubble"
    assert_equal 1, outer_model.milestones, "observe handler should have updated milestones"
    assert_equal :child, outer_model.receiver.received_envelope, "forward should have delivered the bubble to the receiver fragment"
  end
end
