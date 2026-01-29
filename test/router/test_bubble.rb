# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterBubble < Minitest::Test
  # Basic bubble semantics
  def test_bubble_returned_from_nested_triggers_outer_observe
    skip "TODO"
  end

  def test_bubble_returned_from_nested_triggers_outer_intercept
    skip "TODO"
  end

  def test_bubble_observe_continues_propagation_outward
    skip "TODO"
  end

  def test_bubble_intercept_stops_propagation
    skip "TODO"
  end

  def test_bubble_unhandled_disappears_silently_at_root
    skip "TODO"
  end

  # Bubble through hierarchy
  def test_bubble_flows_through_multiple_levels
    skip "TODO"
  end

  def test_bubble_each_level_can_observe
    skip "TODO"
  end

  def test_bubble_any_level_can_intercept_and_stop
    skip "TODO"
  end

  def test_bubble_model_updates_accumulate_through_levels
    skip "TODO"
  end

  # Bubble with batch
  def test_bubble_inside_batch_is_extracted_and_processed
    skip "TODO"
  end

  def test_bubble_inside_batch_non_bubble_commands_preserved
    skip "TODO"
  end

  def test_bubble_intercepted_inside_batch_removes_bubble_from_batch
    skip "TODO"
  end

  def test_bubble_observed_inside_batch_continues_in_batch
    skip "TODO"
  end

  # Bubble semantic transformation
  def test_intercept_bubble_and_rebubble_transforms_message
    skip "TODO"
  end

  def test_intercept_bubble_and_deliver_changes_routing
    skip "TODO"
  end
end
