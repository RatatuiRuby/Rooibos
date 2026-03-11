# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestCommandRandom < Minitest::Test
  include Rooibos::TestHelper

  def test_random_command_protocol
    cmd = Rooibos::Command.random(:my_roll)

    validate_rooibos_command!(cmd)
  end

  def test_rand_no_args_delegates_to_random_rand
    cmd = Rooibos::Command.random(:my_roll)
    messages = []
    out = stub_out(messages)

    ::Random.stub(:rand, 0.42) do
      cmd.call(out, stub_token)
    end

    assert_equal 1, messages.size
    msg = messages.first
    assert_kind_of Rooibos::Message::Random, msg
    assert_equal :my_roll, msg.envelope
    assert_equal 0.42, msg.value
  end

  def test_rand_with_max_delegates_argument
    cmd = Rooibos::Command.random(6, :die)
    messages = []
    out = stub_out(messages)

    ::Random.stub(:rand, -> (*args) { assert_equal [6], args; 3 }) do
      cmd.call(out, stub_token)
    end

    msg = messages.first
    assert_equal :die, msg.envelope
    assert_equal 3, msg.value
  end

  def test_method_dispatch_delegates_to_named_method
    cmd = Rooibos::Command.random(:bytes, 16, :key)
    messages = []
    out = stub_out(messages)

    ::Random.stub(:public_send, -> (method, *args) { assert_equal :bytes, method; assert_equal [16], args; "random_bytes_16" }) do
      cmd.call(out, stub_token)
    end

    msg = messages.first
    assert_equal :key, msg.envelope
    assert_equal "random_bytes_16", msg.value
  end

  def test_seeded_random_produces_fixed_value
    srand(42)
    cmd = Rooibos::Command.random(:seeded_roll)
    messages = []
    out = stub_out(messages)

    cmd.call(out, stub_token)

    msg = messages.first
    assert_equal :seeded_roll, msg.envelope
    assert_equal ::Random.new(42).rand, msg.value
  end

  def test_canceled_random_sends_canceled_not_random
    cmd = Rooibos::Command.random(:should_not_arrive)
    messages = []
    out = stub_out(messages)

    cmd.call(out, stub_canceled_token)

    assert_equal 1, messages.size
    msg = messages.first
    assert_kind_of Rooibos::Message::Canceled, msg
    assert_equal cmd, msg.command
  end

  private def stub_out(messages)
    mock = Minitest::Mock.new
    mock.expect(:put, nil) { |msg| messages << msg; true }
    mock
  end

  private def stub_token
    token = Minitest::Mock.new
    token.expect(:canceled?, false)
    token
  end

  private def stub_canceled_token
    token = Minitest::Mock.new
    token.expect(:canceled?, true)
    token
  end
end
