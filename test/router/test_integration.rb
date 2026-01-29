# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterIntegration < Minitest::Test
  # Message processing order contract
  def test_observe_runs_before_intercept
    skip "TODO"
  end

  def test_observe_runs_before_keymap
    skip "TODO"
  end

  def test_intercept_runs_before_keymap
    skip "TODO"
  end

  def test_keymap_runs_before_mousemap
    skip "TODO"
  end

  def test_mousemap_runs_before_forward
    skip "TODO"
  end

  def test_forward_runs_before_otherwise
    skip "TODO"
  end

  def test_full_pipeline_order_with_all_handlers
    skip "TODO"
  end
end
