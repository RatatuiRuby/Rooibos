# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterObserve < Minitest::Test
  # Basic observe tests
  def test_observe_runs_handler_and_continues_processing
    skip "TODO"
  end

  def test_observe_updates_model_and_keymap_sees_updated_model
    skip "TODO"
  end

  def test_observe_returns_command_that_gets_executed
    skip "TODO"
  end

  def test_observe_with_no_match_skips_handler
    skip "TODO"
  end

  # Callable types
  def test_observe_accepts_lambda_predicate_and_handler
    skip "TODO"
  end

  def test_observe_accepts_proc_predicate_and_handler
    skip "TODO"
  end

  def test_observe_accepts_method_predicate_and_handler
    skip "TODO"
  end

  def test_observe_accepts_callable_object_predicate_and_handler
    skip "TODO"
  end

  def test_observe_validates_ractor_shareable_in_debug_mode
    skip "TODO"
  end

  def test_observe_allows_non_ractor_shareable_in_production_mode
    skip "TODO"
  end

  # Predicate aliases
  def test_observe_if_alias_matches_predicate
    skip "TODO"
  end

  def test_observe_when_alias_matches_predicate
    skip "TODO"
  end

  def test_observe_unless_inverts_predicate
    skip "TODO"
  end

  def test_observe_except_inverts_predicate
    skip "TODO"
  end

  def test_observe_then_keyword_for_handler
    skip "TODO"
  end

  # observe_all
  def test_observe_all_matches_every_message
    skip "TODO"
  end

  def test_observe_all_runs_before_keymap
    skip "TODO"
  end

  # Multiple observers
  def test_multiple_observers_run_in_declaration_order
    skip "TODO"
  end

  def test_multiple_observers_accumulate_model_changes
    skip "TODO"
  end

  def test_multiple_observers_accumulate_commands
    skip "TODO"
  end

  # DWIM return handling
  def test_observe_handler_can_return_just_model
    skip "TODO"
  end

  def test_observe_handler_can_return_just_command
    skip "TODO"
  end

  def test_observe_handler_can_return_tuple
    skip "TODO"
  end

  def test_observe_handler_can_return_nil
    skip "TODO"
  end
end
