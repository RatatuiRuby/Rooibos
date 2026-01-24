# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

# Tests for streaming-aware Command.map behavior.
# Command.map pumps ALL messages from inner command, not just one.
class TestCommandMap < Minitest::Test
  include Rooibos::TestHelper

  # A streaming command that emits multiple messages
  StreamingCommand = Data.define do
    include Rooibos::Command::Custom

    def call(out, _token)
      out.put(:chunk, "first")
      out.put(:chunk, "second")
      out.put(:chunk, "third")
    end
  end

  def test_map_pumps_all_messages_from_streaming_command
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s"
          cmd = Rooibos::Command.map(StreamingCommand.new) { |msg| [:mapped, msg].freeze }
          [m, cmd]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
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

    assert_no_errors(received_messages)

    # Should receive ALL three messages, each mapped
    mapped_chunks = received_messages.select { |m| m.is_a?(Array) && m.first == :mapped }
    assert_equal 3, mapped_chunks.size, "Expected 3 mapped messages, got: #{received_messages.inspect}"
    assert_equal [:chunk, "first"], mapped_chunks[0].last
    assert_equal [:chunk, "second"], mapped_chunks[1].last
    assert_equal [:chunk, "third"], mapped_chunks[2].last
  end

  # A single-message command (existing behavior)
  SingleShotCommand = Data.define do
    include Rooibos::Command::Custom

    def call(out, _token)
      out.put(:done, "result")
    end
  end

  def test_map_still_works_for_single_shot_commands
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s"
          cmd = Rooibos::Command.map(SingleShotCommand.new) { |msg| [:mapped, msg].freeze }
          [m, cmd]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
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

    assert_no_errors(received_messages)

    mapped = received_messages.find { |m| m.is_a?(Array) && m.first == :mapped }
    refute_nil mapped, "Should receive mapped result"
    assert_equal [:done, "result"], mapped.last
  end

  # Test dual signature: positional callable form
  TagWithUser = Data.define(:user_id) do
    def call(msg)
      Ractor.make_shareable([:tagged, { user_id:, data: msg }])
    end
  end

  def test_map_accepts_positional_callable
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s"
          cmd = Rooibos::Command.map(SingleShotCommand.new, TagWithUser.new(user_id: 42))
          [m, cmd]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
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

    assert_no_errors(received_messages)

    tagged = received_messages.find { |m| m.is_a?(Array) && m.first == :tagged }
    refute_nil tagged, "Should receive tagged result"
    assert_equal 42, tagged.last[:user_id]
    assert_equal [:done, "result"], tagged.last[:data]
  end

  def test_map_raises_when_both_positional_and_block_provided
    inner = SingleShotCommand.new
    callable = TagWithUser.new(user_id: 1)

    error = assert_raises(ArgumentError) do
      Rooibos::Command.map(inner, callable) { |m| m }
    end

    assert_match(/not both/i, error.message)
  end

  def test_map_raises_when_no_mapper_provided
    inner = SingleShotCommand.new

    error = assert_raises(ArgumentError) do
      Rooibos::Command.map(inner)
    end

    assert_match(/mapper/i, error.message)
  end

  # Command.batch + callable mapper (Ractor-safe data capture)
  TagWithContext = Data.define(:context) do
    def call(msg)
      Ractor.make_shareable([context, msg])
    end
  end

  FetchA = Data.define do
    include Rooibos::Command::Custom
    def call(out, _token)
      out.put(:a_result)
    end
  end

  FetchB = Data.define do
    include Rooibos::Command::Custom
    def call(out, _token)
      out.put(:b_result)
    end
  end

  def test_batch_with_callable_mapper
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    # Use class-based commands instead of Data.define for shareability
    fetch_a = Ractor.make_shareable(FetchA.new)
    fetch_b = Ractor.make_shareable(FetchB.new)
    mapper = Ractor.make_shareable(TagWithContext.new(context: :dashboard))

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        if msg.code == "s"
          batch = Rooibos::Command.batch(fetch_a, fetch_b)
          cmd = Rooibos::Command.map(batch, mapper)
          [m, cmd]
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

    assert_no_errors(received_messages)
    tagged = received_messages.select { |m| m.is_a?(Array) && m.first == :dashboard }
    assert_equal 3, tagged.size, "Expected 3 tagged messages, got: #{received_messages.inspect}"
    # 2 results (symbols) + 1 Message::Batch completion
    result_one, result_two, result_three = tagged
    assert_equal [result_one.last, result_two.last].sort, [:a_result, :b_result] # Non-deterministic order
    assert_kind_of Rooibos::Message::Batch, result_three.last # Deterministically last
  end

  # Command.batch emits Message::Batch on completion, enabling composition
  # with Command.map for custom completion signals.
  def test_batch_emits_message_batch_on_completion
    received_messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    fetch_a = Ractor.make_shareable(FetchA.new)
    fetch_b = Ractor.make_shareable(FetchB.new)

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        if msg.code == "s"
          batch = Rooibos::Command.batch(fetch_a, fetch_b)
          [m, batch]
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

    assert_no_errors(received_messages)
    # Should see both results AND a Message::Batch completion
    assert_includes received_messages, :a_result
    assert_includes received_messages, :b_result
    completion = received_messages.find { |m| m.is_a?(Rooibos::Message::Batch) }
    assert completion, "Expected Message::Batch, got: #{received_messages.inspect}"
  end
end
