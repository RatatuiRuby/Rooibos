# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/shortcuts"

class TestShortcuts < Minitest::Test
  include Rooibos::Shortcuts

  def test_cmd_exit_returns_exit_command
    result = Cmd.exit

    assert_kind_of Rooibos::Command::Exit, result
  end

  def test_cmd_sh_returns_system_command
    result = Cmd.sh(%q(ruby -e "puts 'hello'"), :got_output)

    assert_kind_of Rooibos::Command::System, result
    assert_equal %q(ruby -e "puts 'hello'"), result.command
    assert_equal :got_output, result.envelope
  end

  def test_cmd_map_returns_mapped_command
    inner = Cmd.sh("ls", :files)
    mapper = -> (message) { [:wrapped, message] }

    result = Cmd.map(inner, &mapper)

    assert_kind_of Rooibos::Command::Mapped, result
    assert_equal inner, result.inner_command
    assert_equal mapper, result.mapper
  end

  def test_including_shortcuts_provides_cmd_module
    # self.class already includes Shortcuts (see top of class)
    # This test documents the expected usage pattern
    assert defined?(Cmd), "Cmd module should be available after including Shortcuts"
  end

  def test_cmd_map_with_block_syntax
    inner = Cmd.sh("ls", :files)

    result = Cmd.map(inner) { |message| [:parent, *message] }

    assert_kind_of Rooibos::Command::Mapped, result
    # Verify the mapper works
    transformed = result.mapper.call([:files, { stdout: "a.txt" }])
    assert_equal [:parent, :files, { stdout: "a.txt" }], transformed
  end

  def test_msg_provides_timer_constant
    assert_equal Rooibos::Message::Timer, Msg::Timer
  end

  def test_msg_provides_http_constant
    assert_equal Rooibos::Message::HttpResponse, Msg::Http
  end

  def test_msg_provides_system_batch_constant
    assert_equal Rooibos::Message::System::Batch, Msg::Sh::Batch
  end

  def test_msg_provides_system_stream_constant
    assert_equal Rooibos::Message::System::Stream, Msg::Sh::Stream
  end

  def test_msg_provides_all_constant
    assert_equal Rooibos::Message::All, Msg::All
  end

  def test_msg_provides_batch_constant
    assert_equal Rooibos::Message::Batch, Msg::Batch
  end

  def test_including_shortcuts_provides_msg_module
    assert defined?(Msg), "Msg module should be available after including Shortcuts"
  end

  def test_msg_timer_works_in_pattern_matching
    timer_msg = Rooibos::Message::Timer.new(envelope: :dismiss, elapsed: 1.5)

    result = case timer_msg
             in Msg::Timer[envelope: :dismiss]
               :matched
             else
               :no_match
    end

    assert_equal :matched, result
  end

  def test_msg_http_works_in_pattern_matching
    http_msg = Rooibos::Message::HttpResponse.new(
      envelope: :users,
      status: 200,
      body: '{"name":"Alice"}',
      headers: {},
      error: nil
    )

    result = case http_msg
             in Msg::Http[status: 200, body:]
               body
             else
               :no_match
    end

    assert_equal '{"name":"Alice"}', result
  end

  def test_msg_sh_batch_works_in_pattern_matching
    shell_msg = Rooibos::Message::System::Batch.new(
      envelope: :build,
      stdout: "Success",
      stderr: "",
      status: 0
    )

    result = case shell_msg
             in Msg::Sh::Batch[status: 0, stdout:]
               stdout
             else
               :no_match
    end

    assert_equal "Success", result
  end

  def test_msg_sh_stream_works_in_pattern_matching
    stream_msg = Rooibos::Message::System::Stream.new(
      envelope: :log,
      stream: :stdout,
      content: "Log line",
      status: nil
    )

    result = case stream_msg
             in Msg::Sh::Stream[stream: :stdout, content:]
               content
             else
               :no_match
    end

    assert_equal "Log line", result
  end

  def test_msg_all_works_in_pattern_matching
    all_msg = Rooibos::Message::All.new(
      envelope: :parallel,
      results: [:result1, :result2],
      nested: false
    )

    result = case all_msg
             in Msg::All[envelope: :parallel, results:]
               results
             else
               :no_match
    end

    assert_equal [:result1, :result2], result
  end

  def test_msg_batch_works_in_pattern_matching
    batch_cmd = Rooibos::Command.batch(Ractor.make_shareable(Rooibos::Command.exit))
    batch_msg = Rooibos::Message::Batch.new(command: batch_cmd)

    result = case batch_msg
             in Msg::Batch[command: command]
               :matched
             else
               :no_match
    end

    assert_equal :matched, result
    assert_same batch_cmd, command
  end

  def test_msg_provides_clock_constant
    assert_equal Rooibos::Message::Clock, Msg::Clock
  end

  def test_msg_clock_works_in_pattern_matching
    clock_msg = Rooibos::Message::Clock.new(envelope: :refresh, time: Time.now)

    result = case clock_msg
             in Msg::Clock[envelope: :refresh]
               :matched
             else
               :no_match
    end

    assert_equal :matched, result
  end

  def test_msg_provides_rand_constant
    assert_equal Rooibos::Message::Random, Msg::Rand
  end

  def test_msg_rand_works_in_pattern_matching
    rand_msg = Rooibos::Message::Random.new(envelope: :die, value: 4)

    result = case rand_msg
             in Msg::Rand[envelope: :die, value:]
               value
             else
               :no_match
    end

    assert_equal 4, result
  end
end
