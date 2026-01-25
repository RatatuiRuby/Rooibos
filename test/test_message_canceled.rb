# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestMessageCanceled < Minitest::Test
  def test_canceled_predicate_returns_true
    canceled = Rooibos::Message::Canceled.new(command: :some_cmd)

    assert canceled.canceled?, "Message::Canceled should return true for canceled?"
  end

  def test_cancelled_british_alias
    canceled = Rooibos::Message::Canceled.new(command: :some_cmd)

    assert canceled.cancelled?, "cancelled? should be an alias for canceled?"
  end

  def test_includes_predicates_mixin
    canceled = Rooibos::Message::Canceled.new(command: :some_cmd)

    # Should respond to unknown predicates via Predicates mixin
    refute canceled.ctrl_c?, "canceled message should respond to ctrl_c? via Predicates"
    refute canceled.http?,   "canceled message should respond to http? via Predicates"
  end

  def test_deconstruct_keys_for_pattern_matching
    canceled = Rooibos::Message::Canceled.new(command: :some_cmd)
    keys = canceled.deconstruct_keys(nil)

    assert_equal :canceled, keys[:type]
    assert_equal :some_cmd, keys[:command]
  end

  def test_pattern_matching
    canceled = Rooibos::Message::Canceled.new(command: :my_timer)

    matched = case canceled
              in { type: :canceled, command: }
                command
              else
                nil
    end

    assert_equal :my_timer, matched
  end

  def test_to_sym
    canceled = Rooibos::Message::Canceled.new(command: :some_cmd)
    assert_equal :message_canceled, canceled.to_sym
  end

  def test_symbol_equality
    canceled = Rooibos::Message::Canceled.new(command: :some_cmd)
    assert_operator canceled, :==, :message_canceled
    refute_operator canceled, :==, :message_timer
  end
end
