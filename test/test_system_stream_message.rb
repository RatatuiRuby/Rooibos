# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestSystemStreamMessage < Minitest::Test
  def test_system_predicate_returns_true
    msg = RatatuiRuby::Tea::Message::System::Stream.new(
      envelope: :build, stream: :stdout, content: "line\n", status: nil
    )

    assert msg.system?, "SystemStreamMessage should return true for system?"
  end

  def test_stdout_predicate_for_stdout_stream
    msg = RatatuiRuby::Tea::Message::System::Stream.new(
      envelope: :build, stream: :stdout, content: "line\n", status: nil
    )

    assert msg.stdout?, "Stream :stdout should be stdout?"
  end

  def test_stderr_predicate_for_stderr_stream
    msg = RatatuiRuby::Tea::Message::System::Stream.new(
      envelope: :build, stream: :stderr, content: "error\n", status: nil
    )

    assert msg.stderr?, "Stream :stderr should be stderr?"
  end

  def test_complete_predicate_for_complete_stream
    msg = RatatuiRuby::Tea::Message::System::Stream.new(
      envelope: :build, stream: :complete, content: nil, status: 0
    )

    assert msg.complete?, "Stream :complete should be complete?"
  end

  def test_deconstruct_keys_for_stdout_pattern_matching
    msg = RatatuiRuby::Tea::Message::System::Stream.new(
      envelope: :build, stream: :stdout, content: "OK\n", status: nil
    )

    case msg
    in { type: :system_stream, envelope: :build, stream: :stdout, content: }
      assert_equal "OK\n", content
    else
      flunk "Pattern match failed"
    end
  end

  def test_deconstruct_keys_for_complete_pattern_matching
    msg = RatatuiRuby::Tea::Message::System::Stream.new(
      envelope: :build, stream: :complete, content: nil, status: 0
    )

    case msg
    in { type: :system_stream, envelope: :build, stream: :complete, status: }
      assert_equal 0, status
    else
      flunk "Pattern match failed"
    end
  end
end
