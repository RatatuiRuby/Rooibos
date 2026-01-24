# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestMessageError < Minitest::Test
  def test_error_predicate_returns_true
    error = Rooibos::Message::Error.new(command: :some_cmd, exception: RuntimeError.new("boom"))

    assert error.error?, "Message::Error should return true for error?"
  end

  def test_includes_predicates_mixin
    error = Rooibos::Message::Error.new(command: :some_cmd, exception: RuntimeError.new("boom"))

    # Should respond to unknown predicates via Predicates mixin
    refute error.ctrl_c?, "error? message should respond to ctrl_c? via Predicates"
    refute error.http?,   "error? message should respond to http? via Predicates"
  end

  def test_deconstruct_keys_for_pattern_matching
    error = Rooibos::Message::Error.new(command: :some_cmd, exception: RuntimeError.new("boom"))
    keys = error.deconstruct_keys(nil)

    assert_equal :error, keys[:type]
    assert_equal :some_cmd, keys[:command]
    assert_kind_of RuntimeError, keys[:exception]
  end

  def test_pattern_matching
    error = Rooibos::Message::Error.new(command: :fetch, exception: RuntimeError.new("timeout"))

    matched = case error
              in { type: :error, command:, exception: }
                { command:, message: exception.message }
              else
                nil
    end

    assert_equal :fetch, matched[:command]
    assert_equal "timeout", matched[:message]
  end
end
