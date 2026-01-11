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
          [m, RatatuiRuby::Tea::Command.system(shell_cmd, tag, stream:)]
        when "q"
          [m, RatatuiRuby::Tea::Command.exit]
        else
          [m, nil]
        end
      when Array
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
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    messages
  end

  # Test that streaming mode produces a stdout message instead of batch hash.
  def test_streaming_command_produces_stdout_message
    messages = run_command_and_collect("echo hello", :output, stream: true)

    stdout_msgs = messages.select { |m| m[1] == :stdout }
    refute_empty stdout_msgs, "Expected [:output, :stdout, ...] message, got batch mode"
  end

  def test_streaming_stdout_message_has_correct_tag
    messages = run_command_and_collect("echo hello", :my_tag, stream: true)

    stdout_msg = messages.find { |m| m[1] == :stdout }
    assert_equal :my_tag, stdout_msg[0], "stdout message tag should match command tag"
  end

  def test_streaming_stdout_message_has_line_content
    messages = run_command_and_collect("echo hello", :output, stream: true)

    stdout_msg = messages.find { |m| m[1] == :stdout }
    assert_equal "hello\n", stdout_msg[2], "stdout message should contain line content"
  end

  def test_streaming_command_produces_stderr_message
    messages = run_command_and_collect("echo error >&2", :output, stream: true)

    stderr_msgs = messages.select { |m| m[1] == :stderr }
    refute_empty stderr_msgs, "Expected [:output, :stderr, ...] message"
  end

  def test_streaming_stderr_message_has_correct_tag
    messages = run_command_and_collect("echo error >&2", :my_tag, stream: true)

    stderr_msg = messages.find { |m| m[1] == :stderr }
    assert_equal :my_tag, stderr_msg[0], "stderr message tag should match command tag"
  end

  def test_streaming_stderr_message_has_line_content
    messages = run_command_and_collect("echo error >&2", :output, stream: true)

    stderr_msg = messages.find { |m| m[1] == :stderr }
    assert_equal "error\n", stderr_msg[2], "stderr message should contain line content"
  end

  def test_streaming_command_sends_complete_message
    messages = run_command_and_collect("true", :output, stream: true)

    complete_msgs = messages.select { |m| m[1] == :complete }
    assert_equal 1, complete_msgs.size, "Expected one :complete message"
  end

  def test_streaming_complete_message_has_correct_tag
    messages = run_command_and_collect("true", :my_tag, stream: true)

    complete_msg = messages.find { |m| m[1] == :complete }
    assert_equal :my_tag, complete_msg[0], "Tag should match the command's tag"
  end

  def test_streaming_complete_message_has_exit_status
    messages = run_command_and_collect("exit 42", :output, stream: true)

    complete_msg = messages.find { |m| m[1] == :complete }
    assert_equal 42, complete_msg[2][:status], "Exit status should be 42"
  end

  # Regression test: batch mode still works (stream: false default)
  def test_batch_mode_still_returns_single_message
    messages = run_command_and_collect("echo hello", :output, stream: false)

    assert_equal 1, messages.size, "Batch mode should return single message"
    msg = messages.first

    assert_equal :output, msg[0], "Tag should match"
    assert_kind_of Hash, msg[1], "Batch mode should return hash, not :stdout/:stderr symbol"
    assert msg[1].key?(:stdout), "Hash should have :stdout key"
    assert msg[1].key?(:stderr), "Hash should have :stderr key"
    assert msg[1].key?(:status), "Hash should have :status key"
  end

  # Error handling: invalid command sends :error message
  def test_streaming_invalid_command_sends_error_message
    messages = run_command_and_collect("nonexistent_cmd_xyz_123", :output, stream: true)

    # Should receive either :error message OR :complete with non-zero status
    error_or_complete = messages.find { |m| m[1] == :error || m[1] == :complete }
    assert error_or_complete, "Should receive :error or :complete message"
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
          cmd = RatatuiRuby::Tea::Command.system(
            "echo started && sleep 0.5", # Short sleep so force-kill completes quickly
            :output,
            stream: true
          )
          [Ractor.make_shareable({ cmd:, cancelled: false }), cmd]
        else
          [m, nil]
        end
      when Array
        tag, event_type, = msg
        events << event_type
        if tag == :output && event_type == :stdout && !m[:cancelled]
          new_model = Ractor.make_shareable({ cmd: m[:cmd], cancelled: true })
          [new_model, RatatuiRuby::Tea::Command.cancel(m[:cmd])]
        elsif tag == :output && event_type == :complete
          [m, RatatuiRuby::Tea::Command.exit]
        else
          [m, nil]
        end
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
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
          cmd = RatatuiRuby::Tea::Command.system(
            "printf 'started\n' && trap 'exit 0' TERM && while true; do sleep 0.001; done",
            :output,
            stream: true
          )
          [Ractor.make_shareable({ cmd:, cancelled: false }), cmd]
        else
          [m, nil]
        end
      when Array
        tag, event_type, = msg
        events << event_type
        if tag == :output && event_type == :stdout && !m[:cancelled]
          new_model = Ractor.make_shareable({ cmd: m[:cmd], cancelled: true })
          [new_model, RatatuiRuby::Tea::Command.cancel(m[:cmd])]
        elsif tag == :output && event_type == :complete
          [m, RatatuiRuby::Tea::Command.exit]
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
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    elapsed = Time.now - start_time

    # Cooperative cancellation should complete quickly after receiving output.
    # The threshold accounts for Ruby fork/exec overhead (~0.5s) but ensures
    # we don't wait for the shell's full 1-minute loop if SIGTERM didn't work.
    assert events.include?(:stdout), "Should receive stdout before cancel"
    assert_operator elapsed, :<, 1.0, "Should cancel cooperatively (< 1.0s), not wait indefinitely"
  end
end
