# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "ratatui_ruby/test_helper"
require "rooibos/test_helper"

# Tests for out.standing and out.wait — parallel streaming commands.
class TestOutletStanding < Minitest::Test
  include RatatuiRuby::TestHelper

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
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        if msg.code == "s"
          [m, ParentCommand.new]
        elsif msg.q?
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        received_messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_command_errors(received_messages)

    # Should receive both child chunks AND parent_done
    chunks = received_messages.select { |m| m.is_a?(Array) && m.first == :chunk }
    assert_equal 2, chunks.size, "Should receive 2 chunks, got: #{received_messages.inspect}"
    assert_includes received_messages, :parent_done
  end

  # A child that sleeps before returning
  BlockingChild = Data.define(:delay) do
    include Rooibos::Command::Custom

    def call(_out, _token)
      sleep delay
    end
  end

  def test_standing_returns_immediately_before_child_completes
    # If standing runs synchronously, this test will take 0.5s
    # If standing runs async, the parent continues immediately
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    parent_command = Data.define do
      include Rooibos::Command::Custom

      def call(out, token)
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        # Spawn a slow child
        out.standing(BlockingChild.new(delay: 0.5), token)
        # Don't wait — just note how long standing() took
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
        out.put [:elapsed, elapsed].freeze
      end
    end

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        if msg.code == "s"
          [m, parent_command.new]
        elsif msg.q?
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        received_messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_command_errors(received_messages)
    elapsed_msg = received_messages.find { |m| m.is_a?(Array) && m.first == :elapsed }
    assert elapsed_msg, "Expected [:elapsed, _] message, got: #{received_messages.inspect}"
    elapsed = elapsed_msg[1]
    # If async, standing() returns in <0.1s; if sync, it takes 0.5s
    assert_operator elapsed, :<, 0.1, "standing() blocked for #{elapsed}s — should be async!"
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
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    parent_command = Data.define do
      include Rooibos::Command::Custom

      def call(out, token)
        handle = out.standing(SlowChild.new(delay: 0.1), token)
        out.wait(handle)
      end
    end

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        if msg.code == "s"
          [m, parent_command.new]
        elsif msg.q?
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        received_messages << msg
        [m, nil]
      end
    end

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    assert_no_command_errors(received_messages)
    # The parent should have waited at least 0.1s for the slow child
    assert_operator elapsed, :>=, 0.08, "wait didn't actually block!"
    assert_includes received_messages, [:slow_child_finished]
  end

  def test_wait_with_no_args_waits_for_all_pending
    # If wait() ignores outstanding handles, elapsed will be near zero
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    parent_command = Data.define do
      include Rooibos::Command::Custom

      def call(out, token)
        # Spawn two slow children, don't save handles
        out.standing(SlowChild.new(delay: 0.05), token)
        out.standing(SlowChild.new(delay: 0.05), token)
        # Wait for ALL pending (should block ~0.05s)
        out.wait
      end
    end

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        if msg.code == "s"
          [m, parent_command.new]
        elsif msg.q?
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        received_messages << msg
        [m, nil]
      end
    end

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    assert_no_command_errors(received_messages)
    # Should have waited for the slow children
    assert_operator elapsed, :>=, 0.04, "wait() didn't wait for pending handles!"
    # Both children should have emitted
    slow_messages = received_messages.select { |m| m == [:slow_child_finished] }
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
      result = out.source(InnerSyncCommand.new, token) # <-- Returns the value
      out.put result # <-- Forward to parent!
      out.put [:child_end].freeze
    end
  end

  def test_standing_child_can_call_source
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    parent_command = Data.define do
      include Rooibos::Command::Custom

      def call(out, token)
        handle = out.standing(ComposableChild.new, token)
        out.wait(handle)
        out.put [:parent_done].freeze
      end
    end

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        if msg.code == "s"
          [m, parent_command.new]
        elsif msg.q?
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        received_messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_command_errors(received_messages)
    # Should see all three messages in order
    assert_includes received_messages, [:child_start]
    assert_includes received_messages, [:inner_sync_done]
    assert_includes received_messages, [:child_end]
    assert_includes received_messages, [:parent_done]
  end

  # Child that explodes
  CrashingChild = Data.define do
    include Rooibos::Command::Custom

    def call(_out, _token)
      raise "Boom!"
    end
  end

  def test_standing_child_crash_produces_error_message
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    parent_command = Data.define do
      include Rooibos::Command::Custom

      def call(out, token)
        handle = out.standing(CrashingChild.new, token)
        out.wait(handle)
      end
    end

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        if msg.code == "s"
          [m, parent_command.new]
        elsif msg.q?
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        received_messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    # Should receive a Command::Error, NOT crash the runtime
    error_msg = received_messages.find { |m| m.is_a?(Rooibos::Command::Error) }
    assert error_msg, "Expected a Command::Error, got: #{received_messages.inspect}"
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
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    parent_command = Data.define do
      include Rooibos::Command::Custom

      def call(out, token)
        # Wrap streaming command with block mapper
        mapped = Rooibos::Command.map(DeltaStream.new) { |msg| [:tagged, msg].freeze }
        h = out.standing(mapped, token)
        out.wait(h)
        out.put [:parent_done].freeze
      end
    end

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        if msg.code == "s"
          [m, parent_command.new]
        elsif msg.q?
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        received_messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_command_errors(received_messages)
    tagged = received_messages.select { |m| m.is_a?(Array) && m.first == :tagged }
    assert_equal 2, tagged.size, "Expected 2 tagged deltas, got: #{received_messages.inspect}"
    assert_includes received_messages, [:parent_done]
  end

  def test_standing_with_callable_mapper
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    transformer = Ractor.make_shareable(DeltaTransformer.new(user_id: 42))

    parent_command = Data.define(:transformer) do
      include Rooibos::Command::Custom

      def call(out, token)
        # Wrap streaming command with callable mapper
        mapped = Rooibos::Command.map(DeltaStream.new, transformer)
        h = out.standing(mapped, token)
        out.wait(h)
        out.put [:parent_done].freeze
      end
    end

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        if msg.code == "s"
          [m, Ractor.make_shareable(parent_command.new(transformer:))]
        elsif msg.q?
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        received_messages << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_command_errors(received_messages)
    tagged = received_messages.select { |m| m.is_a?(Array) && m.first == 42 }
    assert_equal 2, tagged.size, "Expected 2 user-tagged deltas, got: #{received_messages.inspect}"
    assert_includes received_messages, [:parent_done]
  end

  # wait(token:) should return early when token is cancelled
  def test_wait_returns_early_on_cancellation
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    # Stubborn child that sleeps forever
    stubborn = Data.define do
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

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        if msg.code == "s"
          cmd = Ractor.make_shareable(parent_command.new(stubborn: stubborn.new))
          [Ractor.make_shareable(m.merge(cmd:)), cmd]
        elsif msg.code == "c"
          [m, Rooibos::Command.cancel(m[:cmd])]
        elsif msg.q?
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        received_messages << msg
        [m, nil]
      end
    end

    start = Time.now
    with_test_terminal do
      inject_key("s")
      inject_key("c") # Cancel immediately
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end
    total_elapsed = Time.now - start

    # wait should return early (< 1s), not wait for 100s stubborn child
    assert_operator total_elapsed, :<, 2.0, "wait should return early on cancellation"

    # The parent should have emitted elapsed time showing it returned early
    elapsed_msg = received_messages.find { |m| m.is_a?(Array) && m.first == :elapsed }
    assert elapsed_msg, "Expected [:elapsed, _] message"
    assert_operator elapsed_msg[1], :<, 2.0, "wait blocked too long: #{elapsed_msg[1]}s"
  end
end
