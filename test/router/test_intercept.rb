# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterIntercept < Minitest::Test
  # Basic intercept tests
  def test_intercept_stops_further_processing
    skip "TODO"
  end

  def test_intercept_keymap_never_runs_after_match
    skip "TODO"
  end

  def test_intercept_returns_handler_result
    skip "TODO"
  end

  def test_intercept_with_no_match_continues_to_keymap
    skip "TODO"
  end

  # Callable types
  def test_intercept_accepts_lambda_predicate_and_handler
    skip "TODO"
  end

  def test_intercept_accepts_proc_predicate_and_handler
    skip "TODO"
  end

  def test_intercept_accepts_method_predicate_and_handler
    skip "TODO"
  end

  def test_intercept_accepts_callable_object_predicate_and_handler
    skip "TODO"
  end

  def test_intercept_validates_ractor_shareable_in_debug_mode
    skip "TODO"
  end

  def test_intercept_allows_non_ractor_shareable_in_production_mode
    skip "TODO"
  end

  # Predicate aliases
  def test_intercept_if_alias_matches_predicate
    skip "TODO"
  end

  def test_intercept_when_alias_matches_predicate
    skip "TODO"
  end

  def test_intercept_unless_inverts_predicate
    skip "TODO"
  end

  def test_intercept_except_inverts_predicate
    skip "TODO"
  end

  def test_intercept_then_keyword_for_handler
    skip "TODO"
  end

  # intercept_all
  def test_intercept_all_matches_every_message
    skip "TODO"
  end

  def test_intercept_all_stops_all_further_processing
    skip "TODO"
  end

  # Multiple intercepts
  def test_first_matching_intercept_stops_later_intercepts
    skip "TODO"
  end

  def test_intercept_declaration_order_determines_priority
    skip "TODO"
  end

  # DWIM return handling
  def test_intercept_handler_can_return_just_model
    skip "TODO"
  end

  def test_intercept_handler_can_return_just_command
    skip "TODO"
  end

  def test_intercept_handler_can_return_tuple
    skip "TODO"
  end

  def test_intercept_handler_can_return_nil
    skip "TODO"
  end
end
