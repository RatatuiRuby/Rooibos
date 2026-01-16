# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "ratatui_ruby/test_helper"
require "concurrent-edge"

class TestOutlet < Minitest::Test
  include RatatuiRuby::TestHelper

  private def make_outlet(channel)
    lifecycle = Rooibos::Command::Lifecycle.new
    Rooibos::Command::Outlet.new(channel, lifecycle:)
  end

  def test_live_accessor_returns_injected_lifecycle
    channel = Concurrent::Promises::Channel.new
    lifecycle = Rooibos::Command::Lifecycle.new
    outlet = Rooibos::Command::Outlet.new(channel, lifecycle:)

    assert_same lifecycle, outlet.live
  end

  def test_put_sends_one_message
    channel = Concurrent::Promises::Channel.new
    out = make_outlet(channel)

    out.put(:done)

    assert_equal :done, channel.pop
  end

  User = Data.define(:name)
  def test_put_sends_frozen_array_messages
    channel = Concurrent::Promises::Channel.new
    out = make_outlet(channel)

    alice = User.new("Alice")
    out.put([:user, alice].freeze)

    assert_equal [:user, alice], channel.pop
  end

  def test_put_wraps_multiple_params_in_frozen_array_for_you
    channel = Concurrent::Promises::Channel.new
    out = make_outlet(channel)

    out.put(:hello, :world)

    assert_equal [:hello, :world], channel.pop
  end

  def test_put_raises_in_debug_mode_for_non_shareable_payload
    channel = Concurrent::Promises::Channel.new
    out = make_outlet(channel)
    mutable_hash = { data: "not frozen" } # NOT Ractor-shareable

    error = assert_raises(RatatuiRuby::Error::Invariant) do
      out.put(:bad, mutable_hash)
    end

    assert_match(/ractor|shareable/i, error.message)
  end

  def test_put_allows_non_shareable_in_production_mode
    channel = Concurrent::Promises::Channel.new
    out = make_outlet(channel)
    mutable_hash = { data: "not frozen" }

    RatatuiRuby::Debug.suppress_debug_mode do
      out.put(:ok, mutable_hash) # Should NOT raise
    end

    assert_equal [:ok, mutable_hash], channel.pop
  end

  # Outlet#source tests
  def test_source_runs_command_and_returns_result
    channel = Concurrent::Promises::Channel.new
    out = make_outlet(channel)
    token = Rooibos::Command.uncancellable

    # Simple command that immediately puts a result
    simple_command = -> (out, _tok) { out.put(:result, 42) }

    result = out.source(simple_command, token)

    assert_equal [:result, 42], result
  end

  def test_source_returns_nil_when_cancelled
    channel = Concurrent::Promises::Channel.new
    out = make_outlet(channel)

    origin = Concurrent::Promises.resolvable_event
    token = Concurrent::Cancellation.new(origin)
    origin.resolve # Already cancelled

    command = -> (out, _tok) { out.put(:should_not_see_this) }

    result = out.source(command, token)

    assert_nil result
  end

  def test_source_returns_nil_when_timeout_expires
    channel = Concurrent::Promises::Channel.new
    out = make_outlet(channel)
    token = Rooibos::Command.uncancellable

    # Command that never puts anything (simulates a hung command)
    hung_command = -> (_out, _tok) { sleep 10 }

    start = Time.now
    result = out.source(hung_command, token, timeout: 0.05)
    elapsed = Time.now - start

    assert_nil result
    assert_in_delta 0.05, elapsed, 0.03 # Should return quickly, not wait 10s
  end

  def test_source_propagates_exceptions_from_failed_commands
    channel = Concurrent::Promises::Channel.new
    out = make_outlet(channel)
    token = Rooibos::Command.uncancellable

    failing_command = -> (_out, _tok) { raise ArgumentError, "something went wrong" }

    error = assert_raises(ArgumentError) do
      out.source(failing_command, token, timeout: 0.1)
    end

    assert_equal "something went wrong", error.message
  end

  def test_source_returns_nil_if_cancelled_during_execution
    channel = Concurrent::Promises::Channel.new
    out = make_outlet(channel)

    origin = Concurrent::Promises.resolvable_event
    token = Concurrent::Cancellation.new(origin)

    # Command that puts a result, then token gets cancelled
    command = -> (out, _tok) {
      out.put(:result, 42)
      origin.resolve # Cancel AFTER putting result
    }

    result = out.source(command, token)

    assert_nil result # Should be nil because token was cancelled
  end

  def test_source_returns_immediately_when_cancelled_mid_wait
    channel = Concurrent::Promises::Channel.new
    out = make_outlet(channel)

    origin = Concurrent::Promises.resolvable_event
    token = Concurrent::Cancellation.new(origin)

    # Child that blocks for 10s (doesn't check token)
    blocking_child = -> (_out, _tok) { sleep 10 }

    # Cancel after 50ms in another thread
    Thread.new { sleep 0.05; origin.resolve }

    start = Time.now
    result = out.source(blocking_child, token, timeout: 30.0)
    elapsed = Time.now - start

    assert_nil result
    assert_operator elapsed, :<, 1.0, "Should return quickly when cancelled, not wait 10s or 30s"
  end
end
