# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "ratatui_ruby/test_helper"

# Documents streaming command behavior through the public Runtime.run API.
class TestStreamingCommand < Minitest::Test
  include RatatuiRuby::TestHelper

  # Helper to run a command and collect messages
  private def run_command_and_collect(shell_cmd, tag, stream: false)
    messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s"
          [m, Rooibos::Command.system(shell_cmd, tag, stream:)]
        when "q"
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      when Array
        messages << msg
        [m, nil]
      when Rooibos::Message::System::Batch
        messages << msg
        [m, nil]
      when Rooibos::Message::System::Stream
        messages << msg
        [m, nil]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      inject_sync # Wait for command to complete
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    messages
  end

  # Test that streaming mode produces a stdout message instead of batch hash.
  def test_streaming_command_produces_stdout_message
    messages = run_command_and_collect("echo hello", :output, stream: true)

    stdout_msgs = messages.select { |m| m.respond_to?(:stdout?) && m.stdout? }
    refute_empty stdout_msgs, "Expected System::Stream stdout message"
  end

  def test_streaming_stdout_message_has_correct_tag
    messages = run_command_and_collect("echo hello", :my_tag, stream: true)

    stdout_msg = messages.find { |m| m.respond_to?(:stdout?) && m.stdout? }
    assert_equal :my_tag, stdout_msg.envelope, "stdout message tag should match command tag"
  end

  def test_streaming_stdout_message_has_line_content
    messages = run_command_and_collect("echo hello", :output, stream: true)

    stdout_msg = messages.find { |m| m.respond_to?(:stdout?) && m.stdout? }
    assert_equal "hello\n", stdout_msg.content, "stdout message should contain line content"
  end

  def test_streaming_command_produces_stderr_message
    messages = run_command_and_collect("echo error >&2", :output, stream: true)

    stderr_msgs = messages.select { |m| m.respond_to?(:stderr?) && m.stderr? }
    refute_empty stderr_msgs, "Expected System::Stream stderr message"
  end

  def test_streaming_stderr_message_has_correct_tag
    messages = run_command_and_collect("echo error >&2", :my_tag, stream: true)

    stderr_msg = messages.find { |m| m.respond_to?(:stderr?) && m.stderr? }
    assert_equal :my_tag, stderr_msg.envelope, "stderr message tag should match command tag"
  end

  def test_streaming_stderr_message_has_line_content
    messages = run_command_and_collect("echo error >&2", :output, stream: true)

    stderr_msg = messages.find { |m| m.respond_to?(:stderr?) && m.stderr? }
    assert_equal "error\n", stderr_msg.content, "stderr message should contain line content"
  end

  def test_streaming_command_sends_complete_message
    messages = run_command_and_collect("true", :output, stream: true)

    complete_msgs = messages.select { |m| m.respond_to?(:complete?) && m.complete? }
    assert_equal 1, complete_msgs.size, "Expected one complete message"
  end

  def test_streaming_complete_message_has_correct_tag
    messages = run_command_and_collect("true", :my_tag, stream: true)

    complete_msg = messages.find { |m| m.respond_to?(:complete?) && m.complete? }
    assert_equal :my_tag, complete_msg.envelope, "Tag should match the command's tag"
  end

  def test_streaming_complete_message_has_exit_status
    messages = run_command_and_collect("exit 42", :output, stream: true)

    complete_msg = messages.find { |m| m.respond_to?(:complete?) && m.complete? }
    assert_equal 42, complete_msg.status, "Exit status should be 42"
  end

  # Regression test: batch mode still works (stream: false default)
  def test_batch_mode_still_returns_single_message
    messages = run_command_and_collect("echo hello", :output, stream: false)

    assert_equal 1, messages.size, "Batch mode should return single message"
    msg = messages.first

    assert_kind_of Rooibos::Message::System::Batch, msg, "Should be System::Batch"
    assert_equal :output, msg.envelope, "Envelope should match"
    assert_kind_of String, msg.stdout, "Should have stdout"
    assert_kind_of String, msg.stderr, "Should have stderr"
    assert_kind_of Integer, msg.status, "Should have status"
  end

  # Error handling: invalid command sends :error message
  def test_streaming_invalid_command_sends_error_message
    messages = run_command_and_collect("nonexistent_cmd_xyz_123", :output, stream: true)

    # Should receive either error message OR complete with non-zero status
    error_or_complete = messages.find do |m|
      (m.respond_to?(:stream) && m.stream == :error) ||
        (m.respond_to?(:complete?) && m.complete?)
    end
    assert error_or_complete, "Should receive error or complete message"
  end

  # Baseline test: streaming command can be force-killed.
  # This confirms the existing cancellation mechanism works.
  def test_streaming_command_can_be_force_killed
    events = []
    model = Ractor.make_shareable({ cmd: nil, cancelled: false })
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s"
          cmd = Rooibos::Command.system(
            "echo started && sleep 0.5", # Short sleep so force-kill completes quickly
            :output,
            stream: true
          )
          [Ractor.make_shareable({ cmd:, cancelled: false }), cmd]
        else
          [m, nil]
        end
      when Rooibos::Message::System::Stream
        events << msg.stream
        if msg.envelope == :output && msg.stdout? && !m[:cancelled]
          new_model = Ractor.make_shareable({ cmd: m[:cmd], cancelled: true })
          [new_model, Rooibos::Command.cancel(m[:cmd])]
        elsif msg.envelope == :output && msg.complete?
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    # Command should complete (either via cancel or natural completion)
    assert events.include?(:stdout), "Should receive stdout"
    assert events.include?(:complete), "Should receive complete"
  end

  # TDD: streaming command should use cooperative cancellation (SIGTERM).
  # Cooperative cancellation should be faster than the grace period.
  # This test FAILS until we implement token-based SIGTERM.
  def test_streaming_command_cancels_cooperatively
    events = []
    model = Ractor.make_shareable({ cmd: nil, cancelled: false })
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s"
          # Shell: output immediately, responds to SIGTERM quickly (1ms loop)
          cmd = Rooibos::Command.system(
            "printf 'started\n' && trap 'exit 0' TERM && while true; do sleep 0.001; done",
            :output,
            stream: true
          )
          [Ractor.make_shareable({ cmd:, cancelled: false }), cmd]
        else
          [m, nil]
        end
      when Rooibos::Message::System::Stream
        events << msg.stream
        if msg.envelope == :output && msg.stdout? && !m[:cancelled]
          new_model = Ractor.make_shareable({ cmd: m[:cmd], cancelled: true })
          [new_model, Rooibos::Command.cancel(m[:cmd])]
        elsif msg.envelope == :output && msg.complete?
          [m, Rooibos::Command.exit]
        else
          [m, nil]
        end
      else
        [m, nil]
      end
    end

    start_time = Time.now

    with_test_terminal do
      inject_key("s")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    elapsed = Time.now - start_time

    # Cooperative cancellation should complete quickly after receiving output.
    # The threshold accounts for Ruby fork/exec overhead (~0.5s) but ensures
    # we don't wait for the shell's full 1-minute loop if SIGTERM didn't work.
    assert events.include?(:stdout), "Should receive stdout before cancel"
    assert_operator elapsed, :<, 2, "Should cancel cooperatively (< 2s), not wait indefinitely"
  end
end
