# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

# Tests for Command.deliver — the built-in command for sending messages to Update.
class TestCommandDeliver < Minitest::Test
  include Rooibos::TestHelper

  # Example custom message following the blessed pattern
  TestMessage = Data.define(:envelope, :value) do
    include Rooibos::Message::Predicates
  end

  def test_command_deliver_creates_deliver_command
    message = TestMessage.new(envelope: :test, value: 42)
    command = Rooibos::Command.deliver(message)

    assert_kind_of Rooibos::Command::Deliver, command
    assert_equal message, command.message
  end

  def test_command_deliver_is_ractor_shareable
    message = Ractor.make_shareable(TestMessage.new(envelope: :test, value: 42))
    command = Rooibos::Command.deliver(message)

    assert Ractor.shareable?(command), "Command::Deliver should be Ractor-shareable"
  end

  def test_command_deliver_sends_message_to_update
    received = nil
    message = TestMessage.new(envelope: :profile, value: 99)
    model = Ractor.make_shareable({})
    view = -> (_model, tui) { tui.clear }

    update = -> (msg, model) do
      case msg
      in { type: :key, code: "d" }
        Rooibos::Command.deliver(message)
      in { type: :key, code: "q" }
        Rooibos::Command.exit
      in { type: :test_message, envelope: :profile, value: _ }
        received = msg
        model
      else
        model
      end
    end

    with_test_terminal do
      inject_key("d")  # Trigger deliver
      inject_sync      # Wait for command
      inject_key("q")  # Quit

      Rooibos::Runtime.run(model:, view:, update:)
    end

    refute_nil received, "Update should receive the delivered message"
    assert received.test_message?, "Message should match type predicate"
    assert received.profile?, "Message should match envelope predicate"
    assert_equal 99, received.value
  end
end
