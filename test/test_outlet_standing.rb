# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

# Tests for out.standing and out.wait — parallel streaming commands.
class TestOutletStanding < Minitest::Test
  include Rooibos::TestHelper

  # Class-scope state for lambda-based updates
  def setup
    @@messages = []
    @@command = nil
    @@stubborn = nil
    @@transformer = nil
  end

  def teardown
    @@messages = []
    @@command = nil
    @@stubborn = nil
    @@transformer = nil
  end

  # Shared view - just clears terminal
  ClearView = -> (_m, t) { t.clear }

  # Shared update for tests that dispatch @@command on "s", exit on "q", capture messages
  StandingUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      if msg.code == "s"
        cmd = TestOutletStanding.class_variable_get(:@@command)
        [m, cmd.respond_to?(:new) ? cmd.new : cmd]
      elsif msg.q?
        [m, Rooibos::Command.exit]
      else
        [m, nil]
      end
    else
      TestOutletStanding.class_variable_get(:@@messages) << msg
      [m, nil]
    end
  end

  # A command that emits multiple messages
  StreamingChild = Data.define do
    include Rooibos::Command::Custom

    def call(out, _token)
      out.put(:chunk, "first")
      out.put(:chunk, "second")
    end
  end

  # Parent command that uses standing
  ParentCommand = Data.define do
    include Rooibos::Command::Custom

    def call(out, token)
      h = out.standing(StreamingChild.new, token)
      out.wait(h)
      out.put(:parent_done)
    end
  end

  def test_standing_spawns_async_and_messages_reach_parent
    model = Ractor.make_shareable({})
    @@command = ParentCommand

    view = ClearView
    update = StandingUpdate

    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(@@messages)

    # Should receive both child chunks AND parent_done
    chunks = @@messages.select { |m| m.is_a?(Array) && m.first == :chunk }
    assert_equal 2, chunks.size, "Should receive 2 chunks, got: #{@@messages.inspect}"
    assert_includes @@messages, :parent_done
  end

  # A child that sleeps before returning
  BlockingChild = Data.define(:delay) do
    include Rooibos::Command::Custom

    def call(_out, _token)
      sleep delay
    end
  end

  def test_standing_returns_immediately_before_child_completes
    # If standing runs synchronously, this test will take 5.0s
    # If standing runs async, the parent continues immediately
    model = Ractor.make_shareable({})

    parent_command = Data.define do
      include Rooibos::Command::Custom

      def call(out, token)
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        # Spawn a slow child
        out.standing(TestOutletStanding::BlockingChild.new(delay: 5.0), token)
        # Don't wait — just note how long standing() took
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
        out.put [:elapsed, elapsed].freeze
      end
    end

    @@command = parent_command
    view = ClearView
    update = StandingUpdate

    with_test_terminal(timeout: 10) do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(@@messages)
    elapsed_msg = @@messages.find { |m| m.is_a?(Array) && m.first == :elapsed }
    assert elapsed_msg, "Expected [:elapsed, _] message, got: #{@@messages.inspect}"
    elapsed = elapsed_msg[1]
    # If async, standing() returns in <0.1s; if sync, it takes 5.0s
    assert_operator elapsed, :<, 2.0, "standing() blocked for #{elapsed}s — should be async!"
  end

  # A deliberately slow child command
  SlowChild = Data.define(:delay) do
    def call(out, _token)
      sleep delay
      out.put [:slow_child_finished].freeze
    end
  end

  def test_wait_actually_blocks_until_child_completes
    # Parent spawns a slow child and waits for it.
    # If wait doesn't actually block, elapsed time proves it!
    model = Ractor.make_shareable({})

    parent_command = Data.define do
      include Rooibos::Command::Custom

      def call(out, token)
        handle = out.standing(TestOutletStanding::SlowChild.new(delay: 0.1), token)
        out.wait(handle)
      end
    end

    @@command = parent_command
    view = ClearView
    update = StandingUpdate

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    assert_no_errors(@@messages)
    # The parent should have waited at least 0.1s for the slow child
    assert_operator elapsed, :>=, 0.08, "wait didn't actually block!"
    assert_includes @@messages, [:slow_child_finished]
  end

  def test_wait_with_no_args_waits_for_all_pending
    # If wait() ignores outstanding handles, elapsed will be near zero
    model = Ractor.make_shareable({})

    parent_command = Data.define do
      include Rooibos::Command::Custom

      def call(out, token)
        # Spawn two slow children, don't save handles
        out.standing(TestOutletStanding::SlowChild.new(delay: 0.05), token)
        out.standing(TestOutletStanding::SlowChild.new(delay: 0.05), token)
        # Wait for ALL pending (should block ~0.05s)
        out.wait
      end
    end

    @@command = parent_command
    view = ClearView
    update = StandingUpdate

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    assert_no_errors(@@messages)
    # Should have waited for the slow children
    assert_operator elapsed, :>=, 0.04, "wait() didn't wait for pending handles!"
    # Both children should have emitted
    slow_messages = @@messages.select { |m| m == [:slow_child_finished] }
    assert_equal 2, slow_messages.size
  end

  # Inner command for composability test
  InnerSyncCommand = Data.define do
    include Rooibos::Command::Custom

    def call(out, _token)
      out.put [:inner_sync_done].freeze
    end
  end

  # Child that uses out.source for sync nested command
  ComposableChild = Data.define do
    include Rooibos::Command::Custom

    def call(out, token)
      out.put [:child_start].freeze
      result = out.source(TestOutletStanding::InnerSyncCommand.new, token) # <-- Returns the value
      out.put result # <-- Forward to parent!
      out.put [:child_end].freeze
    end
  end

  def test_standing_child_can_call_source
    model = Ractor.make_shareable({})

    parent_command = Data.define do
      include Rooibos::Command::Custom

      def call(out, token)
        handle = out.standing(TestOutletStanding::ComposableChild.new, token)
        out.wait(handle)
        out.put [:parent_done].freeze
      end
    end

    @@command = parent_command
    view = ClearView
    update = StandingUpdate

    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(@@messages)
    # Should see all three messages in order
    assert_includes @@messages, [:child_start]
    assert_includes @@messages, [:inner_sync_done]
    assert_includes @@messages, [:child_end]
    assert_includes @@messages, [:parent_done]
  end

  # Child that explodes
  CrashingChild = Data.define do
    include Rooibos::Command::Custom

    def call(_out, _token)
      raise "Boom!"
    end
  end

  def test_standing_child_crash_produces_error_message
    model = Ractor.make_shareable({})

    parent_command = Data.define do
      include Rooibos::Command::Custom

      def call(out, token)
        handle = out.standing(TestOutletStanding::CrashingChild.new, token)
        out.wait(handle)
      end
    end

    @@command = parent_command
    view = ClearView
    update = StandingUpdate

    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    # Should receive a Message::Error, NOT crash the runtime
    error_msg = @@messages.find { |m| m.is_a?(Rooibos::Message::Error) }
    assert error_msg, "Expected a Message::Error, got: #{@@messages.inspect}"
    assert_match(/Boom!/, error_msg.exception.message)
  end

  # Streaming command for mapper tests
  DeltaStream = Data.define do
    include Rooibos::Command::Custom

    def call(out, _token)
      out.put([:delta, 1].freeze)
      out.put([:delta, 2].freeze)
    end
  end

  # Callable mapper for standing tests
  DeltaTransformer = Data.define(:user_id) do
    def call(msg)
      Ractor.make_shareable([user_id, msg])
    end
  end

  def test_standing_with_block_mapper
    model = Ractor.make_shareable({})

    parent_command = Data.define do
      include Rooibos::Command::Custom

      def call(out, token)
        # Wrap streaming command with block mapper
        mapped = Rooibos::Command.map(TestOutletStanding::DeltaStream.new) { |msg| [:tagged, msg].freeze }
        h = out.standing(mapped, token)
        out.wait(h)
        out.put [:parent_done].freeze
      end
    end

    @@command = parent_command
    view = ClearView
    update = StandingUpdate

    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(@@messages)
    tagged = @@messages.select { |m| m.is_a?(Array) && m.first == :tagged }
    assert_equal 2, tagged.size, "Expected 2 tagged deltas, got: #{@@messages.inspect}"
    assert_includes @@messages, [:parent_done]
  end

  # Specialized update for transformer test - needs to pass transformer param on "s"
  TransformerUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      if msg.code == "s"
        cmd = TestOutletStanding.class_variable_get(:@@command)
        transformer = TestOutletStanding.class_variable_get(:@@transformer)
        [m, Ractor.make_shareable(cmd.new(transformer:))]
      elsif msg.q?
        [m, Rooibos::Command.exit]
      else
        [m, nil]
      end
    else
      TestOutletStanding.class_variable_get(:@@messages) << msg
      [m, nil]
    end
  end

  def test_standing_with_callable_mapper
    model = Ractor.make_shareable({})

    @@transformer = Ractor.make_shareable(DeltaTransformer.new(user_id: 42))

    parent_command = Data.define(:transformer) do
      include Rooibos::Command::Custom

      def call(out, token)
        # Wrap streaming command with callable mapper
        mapped = Rooibos::Command.map(TestOutletStanding::DeltaStream.new, transformer)
        h = out.standing(mapped, token)
        out.wait(h)
        out.put [:parent_done].freeze
      end
    end

    @@command = parent_command
    view = ClearView
    update = TransformerUpdate

    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(@@messages)
    tagged = @@messages.select { |m| m.is_a?(Array) && m.first == 42 }
    assert_equal 2, tagged.size, "Expected 2 user-tagged deltas, got: #{@@messages.inspect}"
    assert_includes @@messages, [:parent_done]
  end

  # Specialized update for cancellation test - handles "c" key for cancel
  CancellationUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      if msg.code == "s"
        cmd = TestOutletStanding.class_variable_get(:@@command)
        stubborn = TestOutletStanding.class_variable_get(:@@stubborn)
        cmd_instance = Ractor.make_shareable(cmd.new(stubborn: stubborn.new))
        [Ractor.make_shareable(m.merge(cmd: cmd_instance)), cmd_instance]
      elsif msg.code == "c"
        [m, Rooibos::Command.cancel(m[:cmd])]
      elsif msg.q?
        [m, Rooibos::Command.exit]
      else
        [m, nil]
      end
    else
      TestOutletStanding.class_variable_get(:@@messages) << msg
      [m, nil]
    end
  end

  # wait(token:) should return early when token is canceled
  def test_wait_returns_early_on_cancellation
    model = Ractor.make_shareable({})

    # Stubborn child that sleeps forever
    @@stubborn = Data.define do
      include Rooibos::Command::Custom
      def call(_out, _token)
        sleep 100
      end
    end

    parent_command = Data.define(:stubborn) do
      include Rooibos::Command::Custom

      def call(out, token)
        start = Time.now
        h = out.standing(stubborn, token)
        out.wait(h, token:) # <-- NEW: pass token to race against
        elapsed = Time.now - start
        out.put([:elapsed, elapsed].freeze)
      end
    end

    @@command = parent_command
    view = ClearView
    update = CancellationUpdate

    start = Time.now
    with_test_terminal do
      inject_key("s")
      inject_key("c") # Cancel immediately
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end
    total_elapsed = Time.now - start

    # wait should return early (<1s), not wait for 100s stubborn child
    assert_operator total_elapsed, :<, 5.0, "wait should return early on cancellation"

    # The parent should have emitted elapsed time showing it returned early
    elapsed_msg = @@messages.find { |m| m.is_a?(Array) && m.first == :elapsed }
    assert elapsed_msg, "Expected [:elapsed, _] message"
    assert_operator elapsed_msg[1], :<, 5.0, "wait blocked too long: #{elapsed_msg[1]}s"
  end
end
