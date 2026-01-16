# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestSystemResponse < Minitest::Test
  def test_system_predicate_returns_true
    msg = Rooibos::Message::System::Batch.new(
      envelope: :build, stdout: "", stderr: "", status: 0
    )

    assert msg.system?, "SystemResponse should return true for system?"
  end

  def test_success_predicate_when_status_zero
    msg = Rooibos::Message::System::Batch.new(
      envelope: :build, stdout: "", stderr: "", status: 0
    )

    assert msg.success?, "Status 0 should be success?"
  end

  def test_error_predicate_when_status_nonzero
    msg = Rooibos::Message::System::Batch.new(
      envelope: :build, stdout: "", stderr: "Error", status: 1
    )

    assert msg.error?, "Non-zero status should be error?"
  end

  def test_deconstruct_keys_for_pattern_matching
    msg = Rooibos::Message::System::Batch.new(
      envelope: :build, stdout: "OK", stderr: "", status: 0
    )

    case msg
    in { type: :system, envelope: :build, status: 0, stdout: }
      assert_equal "OK", stdout
    else
      flunk "Pattern match failed"
    end
  end
end
