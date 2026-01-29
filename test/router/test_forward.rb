# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterForward < Minitest::Test
  # with_type tests
  def test_forward_with_type_matches_message_type_predicate
    skip "TODO"
  end

  def test_forward_with_type_dispatches_to_action
    skip "TODO"
  end

  def test_forward_with_type_broadcast_sends_to_all_routes
    skip "TODO"
  end

  def test_forward_with_type_broadcast_to_sends_to_named_routes
    skip "TODO"
  end

  def test_forward_with_type_no_match_falls_through
    skip "TODO"
  end

  # with_envelope tests
  def test_forward_with_envelope_matches_message_envelope
    skip "TODO"
  end

  def test_forward_with_envelope_routes_to_fragment
    skip "TODO"
  end

  def test_forward_with_envelope_no_match_falls_through
    skip "TODO"
  end
end
