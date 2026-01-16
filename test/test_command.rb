# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestCommand < Minitest::Test
  def test_command_quit_is_sentinel
    result = Rooibos::Command.exit
    assert_kind_of Rooibos::Command::Exit, result
  end

  def test_command_system_creates_execute_command
    command = Rooibos::Command.system("echo hello", :got_output)
    assert_kind_of Rooibos::Command::System, command
    assert_equal "echo hello", command.command
    assert_equal :got_output, command.envelope
  end

  def test_command_system_defaults_to_non_streaming
    command = Rooibos::Command.system("echo hello", :got_output)
    refute command.stream?, "stream? should default to false"
  end

  def test_command_system_accepts_stream_kwarg
    command = Rooibos::Command.system("echo hello", :got_output, stream: true)
    assert command.stream?, "stream? should be true when passed"
  end

  def test_command_system_is_ractor_shareable
    command = Rooibos::Command.system("ls", :files)
    # The command itself should be shareable (no Proc captures)
    assert Ractor.shareable?(command), "Command::System should be Ractor-shareable"
  end

  def test_command_map_creates_mapped_command
    inner = Rooibos::Command.system("echo hello", :inner_tag)

    command = Rooibos::Command.map(inner) { |message| [:parent, message] }

    assert_kind_of Rooibos::Command::Mapped, command
  end

  def test_command_map_stores_inner_and_mapper
    inner = Rooibos::Command.system("echo hello", :inner_tag)
    mapper = -> (message) { [:parent, message] }

    command = Rooibos::Command.map(inner, &mapper)

    assert_equal inner, command.inner_command
    assert_equal mapper, command.mapper
  end

  def test_uncancellable_returns_fresh_cancellation_each_time
    token1 = Rooibos::Command.uncancellable
    token2 = Rooibos::Command.uncancellable

    refute_same token1, token2, "Each call should return a fresh instance"
    refute token1.canceled?, "Fresh uncancellable token should not be canceled"
    refute token2.canceled?, "Fresh uncancellable token should not be canceled"
  end
end
