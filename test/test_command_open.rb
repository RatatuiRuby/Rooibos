# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "open3"

class TestCommandOpen < Minitest::Test
  def test_command_open_returns_open_instance
    cmd = Rooibos::Command.open("/tmp/test.txt")
    assert_kind_of Rooibos::Command::Open, cmd
  end

  def test_sends_message_open_on_success
    cmd = Rooibos::Command.open("/tmp/test.txt", :my_envelope)
    messages = []
    out = stub_out(messages)

    mock_status = Minitest::Mock.new
    mock_status.expect(:exitstatus, 0)

    Open3.stub(:capture3, ["", "", mock_status]) do
      cmd.call(out, stub_token)
    end

    assert_equal 1, messages.size
    assert_kind_of Rooibos::Message::Open, messages.first
    assert_equal :my_envelope, messages.first.envelope
    mock_status.verify
  end

  def test_sends_message_error_on_failure
    cmd = Rooibos::Command.open("/tmp/test.txt", :my_envelope)
    messages = []
    out = stub_out(messages)

    mock_status = Minitest::Mock.new
    mock_status.expect(:exitstatus, 1)

    Open3.stub(:capture3, ["", "No application knows how to open this file", mock_status]) do
      cmd.call(out, stub_token)
    end

    assert_equal 1, messages.size
    assert_kind_of Rooibos::Message::Error, messages.first
    assert_equal :my_envelope, messages.first.command
    assert_match(/application/, messages.first.exception.message)
    mock_status.verify
  end

  private

  def stub_out(messages)
    out = Object.new
    out.define_singleton_method(:put) { |msg| messages << msg }
    out
  end

  def stub_token
    token = Minitest::Mock.new
    token.expect(:canceled?, false)
    token
  end
end

