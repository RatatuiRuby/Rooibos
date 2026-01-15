# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "ratatui_ruby/test_helper"
require "ratatui_ruby/tea/test_helper"

class TestTeaTestHelper < Minitest::Test
  include RatatuiRuby::TestHelper

  # TDD Step 1: Test that validate_tea_command! raises for missing tea_command?
  def test_validate_tea_command_raises_for_missing_tea_command_predicate
    bad_command = Object.new
    def bad_command.call(_out, _token); end
    def bad_command.tea_cancellation_grace_period; 0.1; end

    error = assert_raises(RatatuiRuby::Error::Invariant) do
      validate_tea_command!(bad_command)
    end

    assert_match(/tea_command\?/, error.message)
    assert_match(/Command::Custom/, error.message)
  end

  # TDD Step 2: Test that validate_tea_command! raises for missing call
  def test_validate_tea_command_raises_for_missing_call_method
    bad_command = Object.new
    def bad_command.tea_command?; true; end
    def bad_command.tea_cancellation_grace_period; 0.1; end

    error = assert_raises(RatatuiRuby::Error::Invariant) do
      validate_tea_command!(bad_command)
    end

    assert_match(/\bcall\b/, error.message)
  end

  # TDD Step 3: Test that validate_tea_command! raises for missing grace_period
  def test_validate_tea_command_raises_for_missing_grace_period_method
    bad_command = Object.new
    def bad_command.tea_command?; true; end
    def bad_command.call(_out, _token); end

    error = assert_raises(RatatuiRuby::Error::Invariant) do
      validate_tea_command!(bad_command)
    end

    assert_match(/tea_cancellation_grace_period/, error.message)
  end
end
