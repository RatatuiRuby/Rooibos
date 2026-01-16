# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "ratatui_ruby/test_helper"

class TestCommandCustom < Minitest::Test
  include RatatuiRuby::TestHelper

  def test_rooibos_command_returns_true
    klass = Class.new do
      include Rooibos::Command::Custom
    end

    assert klass.new.rooibos_command?, "rooibos_command? should return true"
  end

  def test_default_grace_period_is_two_seconds
    klass = Class.new do
      include Rooibos::Command::Custom
    end

    assert_equal 0.1, klass.new.rooibos_cancellation_grace_period
  end

  def test_grace_period_can_be_overridden
    klass = Class.new do
      include Rooibos::Command::Custom

      def rooibos_cancellation_grace_period
        Float::INFINITY
      end
    end

    assert_equal Float::INFINITY, klass.new.rooibos_cancellation_grace_period
  end

  ShareableProc = Ractor.make_shareable(-> (_out, _token) { :test_message })
  def test_command_custom_is_ractor_shareable
    # App developers should not need to manually wrap Command.custom with Ractor.make_shareable
    cmd = Rooibos::Command.custom(ShareableProc)

    assert Ractor.shareable?(cmd), "Command.custom should return a Ractor-shareable object automatically"
  end

  MutableString = String.new
  class NonShareableCommand
    include Rooibos::Command::Custom
    Closure = -> (out, token) { MutableString << "test" }
    def call(out, token)
      Closure.call(out, token)
    end
  end

  NonShareableProcThatCanBeMadeShareable = -> (_out, _token) { :test_message }
  def test_command_custom_raises_invariant_error_in_debug_mode_if_not_already_ractor_shareable
    # Create proc dynamically so it's not already shareable
    non_shareable_proc = -> (_out, _token) { :test_message }

    error = assert_raises(RatatuiRuby::Error::Invariant) do
      Rooibos::Command.custom(non_shareable_proc)
    end

    assert_match(/ractor-shareable/i, error.message)
  end
end
