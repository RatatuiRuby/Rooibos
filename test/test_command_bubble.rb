# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

# Tests for Command.bubble — the built-in command for outward message propagation.
class TestCommandBubble < Minitest::Test
  def test_command_bubble_creates_bubble_command
    message = { envelope: :test, value: 42 }
    command = Rooibos::Command.bubble(message)

    assert_kind_of Rooibos::Command::Bubble, command
  end

  def test_command_bubble_stores_message
    message = { envelope: :profile, value: 99 }
    command = Rooibos::Command.bubble(message)

    assert_equal message, command.message
  end

  def test_command_bubble_responds_to_rooibos_command_predicate
    command = Rooibos::Command.bubble(:any_message)

    assert command.rooibos_command?, "Bubble should be recognized as a Rooibos command"
  end

  def test_command_bubble_is_ractor_shareable
    message = Ractor.make_shareable({ envelope: :test, value: 42 })
    command = Rooibos::Command.bubble(message)

    assert Ractor.shareable?(command), "Command::Bubble should be Ractor-shareable"
  end
end
