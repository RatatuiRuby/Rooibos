# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestMessageTripleEquals < Minitest::Test
  def test_message_matches_builtin_system_batch_in_case_when
    msg = Rooibos::Message::System::Batch.new(
      envelope: :test,
      stdout: "",
      stderr: "",
      status: 0
    )

    matched = case msg
              when Rooibos::Message then true
              else false
              end

    assert matched, "Rooibos::Message should === builtin System::Batch"
  end

  def test_message_does_not_match_key_events
    msg = RatatuiRuby::Event::Key.new(code: "q")

    matched = case msg
              when Rooibos::Message then true
              else false
              end

    refute matched, "Rooibos::Message should NOT === RatatuiRuby::Event::Key"
  end

  def test_message_does_not_match_user_defined_types_with_predicates
    user_msg = Class.new do
      include Rooibos::Message::Predicates
    end.new

    matched = case user_msg
              when Rooibos::Message then true
              else false
              end

    refute matched, "Rooibos::Message should NOT === user-defined classes with Predicates"
  end

  def test_message_does_not_match_named_user_defined_types
    user_msg = UserAppMessage.new

    matched = case user_msg
              when Rooibos::Message then true
              else false
              end

    refute matched, "Rooibos::Message should NOT === named user-defined classes"
  end

  # Named class to test against (not anonymous)
  class UserAppMessage
    include Rooibos::Message::Predicates
  end

  def test_message_matches_builtin_timer
    msg = Rooibos::Message::Timer.new(envelope: :tick, elapsed: 0.016)

    matched = case msg
              when Rooibos::Message then true
              else false
              end

    assert matched, "Rooibos::Message should === builtin Timer"
  end

  def test_message_matches_builtin_error
    msg = Rooibos::Message::Error.new(
      command: :test,
      exception: RuntimeError.new("oops")
    )

    matched = case msg
              when Rooibos::Message then true
              else false
              end

    assert matched, "Rooibos::Message should === builtin Error"
  end

  def test_message_matches_builtin_canceled
    msg = Rooibos::Message::Canceled.new(command: :test)

    matched = case msg
              when Rooibos::Message then true
              else false
              end

    assert matched, "Rooibos::Message should === builtin Canceled"
  end

  def test_message_matches_builtin_system_stream
    msg = Rooibos::Message::System::Stream.new(
      envelope: :test,
      stream: :stdout,
      content: "output",
      status: nil
    )

    matched = case msg
              when Rooibos::Message then true
              else false
              end

    assert matched, "Rooibos::Message should === builtin System::Stream"
  end
end
