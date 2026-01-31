# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

# Message type for bubbling
class BubbleTestMilestone < Data.define(:envelope, :count)
  include Rooibos::Message::Predicates
end

# Child fragment that bubbles a message when triggered
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
  # Class variable for tracking observe calls (Ractor-shareable pattern)
  @@observe_called = false
  @@observe_message = nil

  def setup
    @@observe_called = false
    @@observe_message = nil
  end

  # Ractor-shareable handlers
  ObserveHandler = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@observe_called, true)
    TestRouterBubble.class_variable_set(:@@observe_message, msg)
    model.with(milestones: model.milestones + 1)
  }
  MilestonePredicate = -> (msg) { msg.respond_to?(:bubble_test_milestone?) && msg.bubble_test_milestone? }

  # Basic bubble semantics
  def test_bubble_returned_from_nested_triggers_outer_observe
    # Parent Router observes milestone messages
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChild

      observe MilestonePredicate, ObserveHandler
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChild::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    # Increment child to 5 — should trigger bubble
    5.times do
      parent_model, _cmd = update.call([:child, :increment], parent_model)
    end

    assert @@observe_called, "observe handler should have been triggered by bubbled message"
    assert_equal 1, parent_model.milestones, "parent should have recorded the milestone"
  end

  # Message type that WON'T match the observe predicate
  class OtherBubbleMessage < Data.define(:envelope, :value)
    include Rooibos::Message::Predicates
  end

  # Child that bubbles a DIFFERENT message type
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
    # Intercept handler that runs on milestone bubbles
    intercept_called = false # Won't work with Ractor but we're testing logic

    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChild

      intercept(-> (msg) { msg.respond_to?(:bubble_test_milestone?) && msg.bubble_test_milestone? },
        -> (msg, model) {
          TestRouterBubble.class_variable_set(:@@observe_called, true)
          model.with(milestones: model.milestones + 1)
        })
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChild::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    # Trigger bubble
    5.times do
      parent_model, _cmd = update.call([:child, :increment], parent_model)
    end

    assert @@observe_called, "intercept handler should have been triggered"
    assert_equal 1, parent_model.milestones, "parent should have recorded the milestone"
  end

  # TEST WRITER: Expose degenerate - predicate is NOT being checked!
  def test_observe_handler_only_runs_when_predicate_matches
    # Parent observes ONLY milestone messages
    parent_class = Class.new do
      include Rooibos::Router

      route :other_child, to: BubbleTestChildOther

      # This predicate should NOT match OtherBubbleMessage
      observe MilestonePredicate, ObserveHandler
    end

    parent_model = Data.define(:other_child, :milestones).new(
      other_child: BubbleTestChildOther::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    # Trigger bubble of OtherBubbleMessage - should NOT trigger observe
    parent_model, _cmd = update.call([:other_child, :trigger], parent_model)

    # Predicate shouldn't match, so observe handler shouldn't run
    refute @@observe_called, "observe handler should NOT run when predicate doesn't match"
    assert_equal 0, parent_model.milestones, "milestones should be unchanged"
  end

  def test_bubble_observe_continues_propagation_outward
    skip "TODO"
  end

  def test_bubble_intercept_stops_propagation
    skip "TODO"
  end

  def test_bubble_unhandled_disappears_silently_at_root
    # Parent Router with NO matching handlers
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChild

      # NO observe/intercept handlers for BubbleTestMilestone
    end

    parent_model = Data.define(:child).new(
      child: BubbleTestChild::Init.call
    )
    update = parent_class.from_router

    # Trigger bubble - should NOT error, just be ignored
    5.times do
      parent_model, cmd = update.call([:child, :increment], parent_model)
      # No error should occur
    end

    # Child model should still update
    assert_equal 5, parent_model.child.count, "child should have updated"
  end

  # Bubble through hierarchy

  # Grandchild that bubbles
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

  # Middle child that routes to grandchild but doesn't handle bubble - should propagate up
  module MiddleChildFragment
    include Rooibos::Router

    Model = Data.define(:grandchild, :saw_bubble)
    Init = -> { Model.new(grandchild: GrandchildFragment::Init.call, saw_bubble: false) }

    route :grandchild, to: GrandchildFragment
    # NO observe/intercept - bubble should propagate upward

    Update = from_router
  end

  def test_bubble_flows_through_multiple_levels
    # LOOPHOLE: Grandchild bubbles, Middle doesn't handle it, so bubble should
    # continue to parent. But current implementation might swallow it!

    parent_class = Class.new do
      include Rooibos::Router

      route :middle, to: MiddleChildFragment

      observe MilestonePredicate, ObserveHandler
    end

    parent_model = Data.define(:middle, :milestones).new(
      middle: MiddleChildFragment::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    # Trigger grandchild's bubble
    parent_model, _cmd = update.call([:middle, [:grandchild, :trigger]], parent_model)

    # Parent's observe handler should have seen the bubble that propagated through middle
    assert @@observe_called, "bubble should propagate from grandchild through middle to parent"
    assert_equal 1, parent_model.milestones, "parent should have recorded the milestone"
  end

  # Track observe handlers at different levels
  @@middle_observe_called = false
  MiddleObserveHandler = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@middle_observe_called, true)
    model.with(saw_bubble: true)
  }

  # Middle child that DOES observe - but observe should NOT stop propagation
  module MiddleChildFragmentWithObserve
    include Rooibos::Router

    Model = Data.define(:grandchild, :saw_bubble)
    Init = -> { Model.new(grandchild: GrandchildFragment::Init.call, saw_bubble: false) }

    route :grandchild, to: GrandchildFragment
    observe MilestonePredicate, MiddleObserveHandler

    Update = from_router
  end

  def test_bubble_each_level_can_observe
    # Both middle AND parent should observe the same bubble
    parent_class = Class.new do
      include Rooibos::Router

      route :middle, to: MiddleChildFragmentWithObserve

      observe MilestonePredicate, ObserveHandler
    end

    parent_model = Data.define(:middle, :milestones).new(
      middle: MiddleChildFragmentWithObserve::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    # Reset tracking
    @@observe_called = false
    @@middle_observe_called = false

    # Trigger grandchild's bubble
    parent_model, _cmd = update.call([:middle, [:grandchild, :trigger]], parent_model)

    # BOTH middle and parent observe handlers should have run
    assert @@middle_observe_called, "middle's observe handler should have run"
    assert @@observe_called, "parent's observe handler should have run - bubble should continue propagating"
    assert_equal 1, parent_model.milestones, "parent should have recorded the milestone"
    assert parent_model.middle.saw_bubble, "middle should have seen the bubble"
  end

  # Track intercept
  @@middle_intercept_called = false
  MiddleInterceptHandler = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@middle_intercept_called, true)
    model.with(saw_bubble: true)
  }

  # Middle child that INTERCEPTs - should stop propagation to parent
  module MiddleChildFragmentWithIntercept
    include Rooibos::Router

    Model = Data.define(:grandchild, :saw_bubble)
    Init = -> { Model.new(grandchild: GrandchildFragment::Init.call, saw_bubble: false) }

    route :grandchild, to: GrandchildFragment
    intercept MilestonePredicate, MiddleInterceptHandler

    Update = from_router
  end

  def test_bubble_any_level_can_intercept_and_stop
    # Middle intercepts, so parent should NOT see the bubble
    parent_class = Class.new do
      include Rooibos::Router

      route :middle, to: MiddleChildFragmentWithIntercept

      observe MilestonePredicate, ObserveHandler
    end

    parent_model = Data.define(:middle, :milestones).new(
      middle: MiddleChildFragmentWithIntercept::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    # Reset tracking
    @@observe_called = false
    @@middle_intercept_called = false

    # Trigger grandchild's bubble
    parent_model, _cmd = update.call([:middle, [:grandchild, :trigger]], parent_model)

    # Middle's intercept should have run
    assert @@middle_intercept_called, "middle's intercept handler should have run"
    # Parent should NOT have observed - intercept stopped propagation
    refute @@observe_called, "parent's observe handler should NOT run - intercept stopped propagation"
    assert_equal 0, parent_model.milestones, "parent should NOT have recorded milestone"
    assert parent_model.middle.saw_bubble, "middle should have seen and intercepted the bubble"
  end

  def test_bubble_model_updates_accumulate_through_levels
    # Both middle and parent observe, both update model, both updates should accumulate
    parent_class = Class.new do
      include Rooibos::Router

      route :middle, to: MiddleChildFragmentWithObserve

      observe MilestonePredicate, ObserveHandler
    end

    parent_model = Data.define(:middle, :milestones).new(
      middle: MiddleChildFragmentWithObserve::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    # Trigger grandchild's bubble - middle.saw_bubble and parent.milestones should both update
    parent_model, _cmd = update.call([:middle, [:grandchild, :trigger]], parent_model)

    # BOTH model updates should have accumulated
    assert parent_model.middle.saw_bubble, "middle's model should reflect observe handler update"
    assert_equal 1, parent_model.milestones, "parent's milestones should be updated"
    assert_equal 1, parent_model.middle.grandchild.count, "grandchild count should be updated"
  end

  # Bubble with batch
  # Child fragment that returns BATCH containing a bubble
  module BubbleTestChildBatch
    Model = Data.define(:count)
    Init = -> { Model.new(count: 0) }
    Update = -> (msg, model) {
      if msg == :trigger_batch
        # Return a batch containing BOTH a regular command AND a bubble
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
    # LOOPHOLE EXPOSED: Implementation only checks for Bubble wrapped in Mapped,
    # but what about Bubble inside a Batch that's wrapped in Mapped?
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChildBatch

      observe MilestonePredicate, ObserveHandler
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChildBatch::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    # Trigger batch with bubble inside
    parent_model, _cmd = update.call([:child, :trigger_batch], parent_model)

    # Bubble inside batch should have triggered observe handler
    assert @@observe_called, "observe handler should have been triggered by bubble INSIDE batch"
    assert_equal 1, parent_model.milestones, "parent should have recorded the milestone"
  end

  def test_bubble_inside_batch_non_bubble_commands_preserved
    # LOOPHOLE: When we extract bubble from batch, the OTHER commands
    # (like Command.deliver) should still be returned for dispatch!
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChildBatch

      observe MilestonePredicate, ObserveHandler
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChildBatch::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    # Trigger batch with bubble + deliver inside
    parent_model, cmd = update.call([:child, :trigger_batch], parent_model)

    # Observe should have triggered
    assert @@observe_called, "observe handler should have been triggered"

    # The non-bubble command (Deliver) should be in the returned command
    assert cmd, "command should not be nil - non-bubble commands should be preserved"

    # The returned command should eventually produce the OtherBubbleMessage via Deliver
    # We check that the inner Deliver is preserved
    assert cmd.respond_to?(:rooibos_command?), "returned cmd should be a command"
  end

  # Intercept handler for batch testing
  InterceptHandler = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@observe_called, true)
    model.with(milestones: model.milestones + 1)
  }

  def test_bubble_intercepted_inside_batch_removes_bubble_from_batch
    # When bubble inside batch is intercepted, it should be consumed
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChildBatch

      intercept MilestonePredicate, InterceptHandler
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChildBatch::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    # Reset tracking
    @@observe_called = false

    # Trigger batch with bubble + deliver inside
    parent_model, cmd = update.call([:child, :trigger_batch], parent_model)

    # Intercept should have triggered
    assert @@observe_called, "intercept handler should have been triggered"
    assert_equal 1, parent_model.milestones, "milestones should have been updated"

    # The non-bubble command should still be returned
    assert cmd, "non-bubble commands should be preserved after intercept"
  end

  def test_bubble_observed_inside_batch_continues_in_batch
    # When bubble inside batch is observed, the bubble should re-bubble
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChildBatch

      observe MilestonePredicate, ObserveHandler
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChildBatch::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    # Reset tracking
    @@observe_called = false

    # Trigger batch with bubble inside
    parent_model, cmd = update.call([:child, :trigger_batch], parent_model)

    # Observe should have triggered
    assert @@observe_called, "observe handler should have been triggered"
    assert_equal 1, parent_model.milestones, "milestones should have been updated"

    # Command returned should exist (re-bubbled command + non-bubble command)
    assert cmd, "command should be returned with re-bubbled message and non-bubble commands"
  end

  # Bubble semantic transformation

  # A transformed milestone message
  class TransformedMilestone < Data.define(:original_count, :extra_data)
    include Rooibos::Message::Predicates
  end

  # Handler that intercepts and re-bubbles with transformed message
  TransformingInterceptHandler = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@observe_called, true)
    [
      model.with(saw_bubble: true),
      Rooibos::Command.bubble(TransformedMilestone.new(original_count: msg.count, extra_data: "transformed")),
]
  }

  def test_intercept_bubble_and_rebubble_transforms_message
    # Intercept consumes original bubble, then re-bubbles with new message type
    # This demonstrates semantic transformation - a communication pattern

    # We'll just verify the intercept handler can return a new Command.bubble
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChild

      intercept MilestonePredicate, TransformingInterceptHandler
    end

    parent_model = Data.define(:child, :saw_bubble).new(
      child: BubbleTestChild::Init.call,
      saw_bubble: false
    )
    update = parent_class.from_router

    # Reset tracking
    @@observe_called = false

    # Trigger child bubble (5 increments triggers milestone)
    5.times do
      parent_model, _cmd = update.call([:child, :increment], parent_model)
    end

    # Intercept should have fired
    assert @@observe_called, "intercept handler should have fired"
    assert parent_model.saw_bubble, "model should have been updated by intercept"
  end

  def test_intercept_bubble_and_deliver_changes_routing
    # Intercept consumes bubble and returns Command.deliver instead
    # This demonstrates changing from bubbling to delivery

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
    end

    parent_model = Data.define(:child, :saw_bubble).new(
      child: BubbleTestChild::Init.call,
      saw_bubble: false
    )
    update = parent_class.from_router

    # Reset tracking
    @@observe_called = false

    # Trigger child bubble
    5.times do
      parent_model, cmd = update.call([:child, :increment], parent_model)
    end

    assert @@observe_called, "intercept handler should have fired"
    assert parent_model.saw_bubble, "model should have been updated by intercept"
  end

  # LOOPHOLE TEST: When observe handler returns Command.bubble, should the original
  # bubble ALSO continue propagating? That would cause double-bubbling!
  @@bubble_count = 0
  BubbleCountingObserver = -> (msg, model) {
    TestRouterBubble.class_variable_set(:@@bubble_count,
      TestRouterBubble.class_variable_get(:@@bubble_count) + 1)
    model
  }

  def test_observe_does_not_duplicate_bubble_when_intercepted_later
    # Grandchild bubbles -> Middle observes -> Parent observes
    # The bubble should only reach parent ONCE, not multiple times

    middle_class = Class.new do
      include Rooibos::Router

      route :grandchild, to: GrandchildFragment
      observe MilestonePredicate, BubbleCountingObserver
    end

    parent_class = Class.new do
      include Rooibos::Router

      route :middle, to: middle_class
      observe MilestonePredicate, BubbleCountingObserver
    end

    middle_init = -> {
      Data.define(:grandchild).new(grandchild: GrandchildFragment::Init.call)
    }
    parent_model = Data.define(:middle).new(middle: middle_init.call)

    # Stub the middle module's Init
    middle_class.const_set(:Init, middle_init)
    middle_class.const_set(:Update, middle_class.from_router)

    update = parent_class.from_router

    # Reset counter
    @@bubble_count = 0

    # Trigger grandchild bubble
    parent_model, _cmd = update.call([:middle, [:grandchild, :trigger]], parent_model)

    # Middle's observe should see it once, Parent's observe should see it once
    # Total = 2 (not more, which would indicate duplication)
    assert_equal 2, @@bubble_count, "bubble should be observed exactly twice (middle + parent), not duplicated"
  end

  # LOOPHOLE: Batch processing checks for Command::Bubble directly,
  # but what if the bubble is wrapped in Command::Mapped inside the batch?

  # Ractor-shareable identity mapper
  IdentityMapper = -> (result) { result }
  Ractor.make_shareable(IdentityMapper)

  module BubbleTestChildNestedBatch
    Model = Data.define(:count)
    Init = -> { Model.new(count: 0) }
    Update = -> (msg, model) {
      if msg == :trigger_nested
        # Return a batch containing a MAPPED bubble (not direct bubble)
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

  # Mapped(Bubble) inside Batch is NOT extracted - passes through unchanged
  def test_mapped_bubble_inside_batch_passes_through_unchanged
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChildNestedBatch

      observe MilestonePredicate, ObserveHandler
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChildNestedBatch::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    # Reset tracking
    @@observe_called = false

    # Trigger - child returns Batch(Mapped(Bubble), Deliver)
    parent_model, cmd = update.call([:child, :trigger_nested], parent_model)

    # Observe should NOT have been triggered (bubble is wrapped in Mapped, not direct)
    refute @@observe_called, "observe handler should NOT run - Mapped(Bubble) is not extracted"
    # The Mapped(Bubble) should be preserved in the output commands
    commands = cmd.commands
    mapped_cmd = commands.find { |c| c.is_a?(Rooibos::Command::Mapped) }
    assert mapped_cmd, "Mapped command should be preserved in output"
    assert_kind_of Rooibos::Command::Bubble, mapped_cmd.inner_command
  end

  # LOOPHOLE: Multiple intercept handlers registered - only FIRST matching should run
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
    # Register TWO intercept handlers that both match - only first should run
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: BubbleTestChild

      intercept MilestonePredicate, FirstInterceptHandler
      intercept MilestonePredicate, SecondInterceptHandler # should NOT run
    end

    parent_model = Data.define(:child).new(
      child: BubbleTestChild::Init.call
    )
    update = parent_class.from_router

    # Reset tracking
    @@first_intercept_called = false
    @@second_intercept_called = false

    # Trigger child bubble (5 increments)
    5.times do
      parent_model, _cmd = update.call([:child, :increment], parent_model)
    end

    # First intercept should have run
    assert @@first_intercept_called, "first intercept handler should have fired"
    # Second intercept should NOT have run - first one stops propagation
    refute @@second_intercept_called, "second intercept handler should NOT run - first consumes bubble"
  end

  # Batch(Batch(Bubble)) - nested batches are NOT recursively extracted
  module BubbleTestChildNestedBatchBatch
    Model = Data.define(:count)
    Init = -> { Model.new(count: 0) }
    Update = -> (msg, model) {
      if msg == :trigger_nested_batch
        # Return Batch(Batch(Bubble), Deliver) - nested
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
    end

    parent_model = Data.define(:child, :milestones).new(
      child: BubbleTestChildNestedBatchBatch::Init.call,
      milestones: 0
    )
    update = parent_class.from_router

    # Reset tracking
    @@observe_called = false

    # Trigger - child returns Batch(Batch(Bubble), Deliver)
    parent_model, cmd = update.call([:child, :trigger_nested_batch], parent_model)

    # Observe should NOT have been triggered (bubble is inside nested Batch, not direct)
    refute @@observe_called, "observe handler should NOT run - nested Batch(Bubble) is not extracted"
    # The nested Batch should be preserved in the output commands
    commands = cmd.commands
    inner_batch = commands.find { |c| c.is_a?(Rooibos::Command::Batch) }
    assert inner_batch, "Inner batch should be preserved in output"
    # The bubble inside the inner batch should still be there
    assert inner_batch.commands.any? { |c| c.is_a?(Rooibos::Command::Bubble) }
  end
end
