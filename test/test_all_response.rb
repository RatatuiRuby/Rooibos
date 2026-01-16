# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestAllResponse < Minitest::Test
  def test_all_predicate_returns_true
    msg = Rooibos::Message::All.new(
      envelope: :parallel, results: [], nested: false
    )

    assert msg.all?, "AllResponse should return true for all?"
  end

  def test_deconstruct_keys_for_pattern_matching
    msg = Rooibos::Message::All.new(
      envelope: :parallel, results: [1, 2, 3], nested: false
    )

    case msg
    in { type: :all, envelope: :parallel, results:, nested: false }
      assert_equal [1, 2, 3], results
    else
      flunk "Pattern match failed"
    end
  end
end
