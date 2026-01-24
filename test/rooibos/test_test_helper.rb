# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestTeaTestHelper < Minitest::Test
  include Rooibos::TestHelper

  # TDD Step 1: Test that validate_rooibos_command! raises for missing rooibos_command?
  def test_validate_rooibos_command_raises_for_missing_rooibos_command_predicate
    bad_command = Object.new
    def bad_command.call(_out, _token); end
    def bad_command.rooibos_cancellation_grace_period; 0.1; end

    error = assert_raises(Rooibos::Error::Invariant) do
      validate_rooibos_command!(bad_command)
    end

    assert_match(/rooibos_command\?/, error.message)
    assert_match(/Command::Custom/, error.message)
  end

  # TDD Step 2: Test that validate_rooibos_command! raises for missing call
  def test_validate_rooibos_command_raises_for_missing_call_method
    bad_command = Object.new
    def bad_command.rooibos_command?; true; end
    def bad_command.rooibos_cancellation_grace_period; 0.1; end

    error = assert_raises(Rooibos::Error::Invariant) do
      validate_rooibos_command!(bad_command)
    end

    assert_match(/\bcall\b/, error.message)
  end

  # TDD Step 3: Test that validate_rooibos_command! raises for missing grace_period
  def test_validate_rooibos_command_raises_for_missing_grace_period_method
    bad_command = Object.new
    def bad_command.rooibos_command?; true; end
    def bad_command.call(_out, _token); end

    error = assert_raises(Rooibos::Error::Invariant) do
      validate_rooibos_command!(bad_command)
    end

    assert_match(/rooibos_cancellation_grace_period/, error.message)
  end
end
