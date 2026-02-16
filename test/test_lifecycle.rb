# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestLifecycle < Minitest::Test
  def test_run_sync_returns_result_from_child_command
    lifecycle = Rooibos::Command::Lifecycle.new
    token = Rooibos::Command.uncancellable

    # Child command that puts a result
    child = -> (out, _tok) { out.put(:hello, :world) }

    result = lifecycle.run_sync(child, token, timeout: 1.0)

    assert_equal [:hello, :world], result
  end

  def test_run_sync_returns_nil_when_already_canceled
    lifecycle = Rooibos::Command::Lifecycle.new

    # Pre-canceled token
    origin = Concurrent::Promises.resolvable_event
    origin.resolve
    token = Concurrent::Cancellation.new(origin)

    # Child that would put if called
    child = -> (out, _tok) { out.put(:never_called) }

    result = lifecycle.run_sync(child, token, timeout: 1.0)

    assert_nil result
  end

  def test_run_sync_returns_nil_when_timeout_expires
    lifecycle = Rooibos::Command::Lifecycle.new
    token = Rooibos::Command.uncancellable

    # Child that never puts (hangs)
    child = -> (_out, _tok) { sleep 10 }

    start = Time.now
    result = lifecycle.run_sync(child, token, timeout: 0.05)
    elapsed = Time.now - start

    assert_nil result
    assert_operator elapsed, :<, 5.0, "Should timeout quickly"
  end

  def test_run_sync_propagates_exceptions
    lifecycle = Rooibos::Command::Lifecycle.new
    token = Rooibos::Command.uncancellable

    # Child that raises
    child = -> (_out, _tok) { raise ArgumentError, "boom" }

    error = assert_raises(ArgumentError) do
      lifecycle.run_sync(child, token, timeout: 1.0)
    end

    assert_equal "boom", error.message
  end

  def test_run_sync_returns_immediately_when_canceled_mid_wait
    lifecycle = Rooibos::Command::Lifecycle.new

    origin = Concurrent::Promises.resolvable_event
    token = Concurrent::Cancellation.new(origin)

    # Child that blocks for 10s
    child = -> (_out, _tok) { sleep 10 }

    # Cancel after 50ms in another thread
    Thread.new { sleep 0.05; origin.resolve }

    start = Time.now
    result = lifecycle.run_sync(child, token, timeout: 30.0)
    elapsed = Time.now - start

    assert_nil result
    assert_operator elapsed, :<, 5.0, "Should return quickly when canceled, not wait 10s or 30s"
  end

  # --- run_async tests ---

  def test_run_async_runs_command_and_tracks_it
    lifecycle = Rooibos::Command::Lifecycle.new
    channel = Concurrent::Promises::Channel.new

    command = -> (out, _tok) { out.put(:async_result) }

    entry = lifecycle.run_async(command, channel)

    # Should return entry with future and origin
    refute_nil entry.future
    refute_nil entry.origin

    # Wait for completion
    entry.future.wait

    # Check result was pushed to channel
    result = channel.try_pop(:EMPTY)
    assert_equal :async_result, result
  end

  def test_cancel_signals_cancellation_and_waits_grace
    lifecycle = Rooibos::Command::Lifecycle.new
    channel = Concurrent::Promises::Channel.new

    # Command that tracks cancellation
    canceled = Concurrent::AtomicBoolean.new(false)
    command_class = Class.new do
      include Rooibos::Command::Custom
      define_method(:rooibos_cancellation_grace_period) { 0.05 }
      define_method(:initialize) { |flag| @canceled = flag }
      define_method(:call) do |out, token|
        loop do
          if token.canceled?
            @canceled.make_true
            out.put(:canceled)
            break
          end
          sleep 0.01
        end
      end
    end
    command = command_class.new(canceled)

    lifecycle.run_async(command, channel)
    sleep 0.01 # Let command start

    # Cancel it
    lifecycle.cancel(command)

    # Should have signalled cancellation and waited
    assert canceled.true?, "Command should have received cancellation"
    result = channel.try_pop(:EMPTY)
    assert_equal :canceled, result

    # Verify command removed from tracking (shutdown won't try to cancel again)
    lifecycle.shutdown # Should not hang or error
  end

  def test_cancel_removes_command_from_tracking
    lifecycle = Rooibos::Command::Lifecycle.new
    channel = Concurrent::Promises::Channel.new

    command = -> (out, token) do
      loop do
        break out.put(:done) if token.canceled?
        sleep 0.01
      end
    end

    lifecycle.run_async(command, channel)
    sleep 0.01

    lifecycle.cancel(command)

    # Cancelling again should be a no-op (command is no longer tracked)
    lifecycle.cancel(command) # Should not hang or error

    # Shutdown should not try to cancel the already-canceled command
    lifecycle.shutdown
  end

  def test_shutdown_cancels_all_active_commands
    lifecycle = Rooibos::Command::Lifecycle.new
    channel = Concurrent::Promises::Channel.new

    canceled_count = Concurrent::AtomicFixnum.new(0)
    command_class = Class.new do
      include Rooibos::Command::Custom
      define_method(:rooibos_cancellation_grace_period) { 0.05 }
      define_method(:initialize) { |counter| @counter = counter }
      define_method(:call) do |out, token|
        loop do
          if token.canceled?
            @counter.increment
            out.put(:shutdown_received)
            break
          end
          sleep 0.01
        end
      end
    end

    # Start multiple commands
    lifecycle.run_async(command_class.new(canceled_count), channel)
    lifecycle.run_async(command_class.new(canceled_count), channel)
    lifecycle.run_async(command_class.new(canceled_count), channel)
    sleep 0.1 # Let commands start

    # Shutdown should cancel all
    lifecycle.shutdown

    assert_equal 3, canceled_count.value, "All three commands should have been canceled"
  end
end
