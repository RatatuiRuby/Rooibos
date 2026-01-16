# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestUpdateHelpers < Minitest::Test
  # Rooibos.route wraps a command with Command.map, prefixing results.
  # This reduces boilerplate when triggering child commands from parents.
  #
  # Without helper:
  #   Command.map(child.fetch_command) { |result| [:panel, *result] }
  #
  # With helper:
  #   Rooibos.route(child.fetch_command, :panel)
  def test_route_wraps_command_with_prefix
    inner_command = Rooibos::Command.system("echo hello", :done)

    wrapped = Rooibos.route(inner_command, :stats)

    assert_kind_of Rooibos::Command::Mapped, wrapped
    assert_equal inner_command, wrapped.inner_command

    # The mapper should prefix the result
    original_result = Rooibos::Message::System::Batch.new(
      envelope: :done, stdout: "hello", stderr: "", status: 0
    )
    transformed = wrapped.mapper.call(original_result)
    assert_equal [:stats, original_result], transformed
  end

  # Rooibos.delegate routes a prefixed message to a child UPDATE.
  # Returns [new_child_model, wrapped_command] or nil if prefix doesn't match.
  #
  # Without helper:
  #   case message
  #   in [:stats, *rest]
  #     new_child, cmd = StatsPanel::UPDATE.call(rest, model.stats)
  #     mapped = cmd ? Command.map(cmd) { |r| [:stats, *r] } : nil
  #     [new_child, mapped]
  #   end
  #
  # With helper:
  #   Rooibos.delegate(message, :stats, StatsPanel::UPDATE, model.stats)
  def test_delegate_routes_message_to_child_update
    # Simulate a child UPDATE that receives [:system_info, {stdout:}]
    # and returns [new_model, nil]
    child_update = -> (message, model) do
      case message
      in [{ type: :system, envelope: :system_info, stdout: }]
        [model.merge(output: stdout).freeze, nil]
      else
        [model, nil]
      end
    end
    child_model = Ractor.make_shareable({ output: "initial" }, copy: true)

    # Message with :stats prefix
    batch_msg = Rooibos::Message::System::Batch.new(
      envelope: :system_info, stdout: "Darwin", stderr: "", status: 0
    )
    message = [:stats, batch_msg]

    result = Rooibos.delegate(message, :stats, child_update, child_model)

    refute_nil result, "delegate should return result when prefix matches"
    new_child, command = result
    assert_equal({ output: "Darwin" }, new_child)
    assert_nil command
  end

  # When prefix doesn't match, delegate returns nil so caller can try other routes.
  def test_delegate_returns_nil_for_non_matching_prefix
    child_update = -> (message, model) { [model, nil] }
    child_model = Ractor.make_shareable({ output: "initial" }, copy: true)

    # Message has :network prefix, but we're checking for :stats
    message = [:network, :ping, { stdout: "ok" }]

    result = Rooibos.delegate(message, :stats, child_update, child_model)

    assert_nil result, "delegate should return nil when prefix doesn't match"
  end

  # When child UPDATE returns a command, delegate wraps it with the prefix.
  def test_delegate_wraps_child_command_with_prefix
    inner_command = Rooibos::Command.system("ls", :files)
    child_update = -> (message, model) { [model.merge(updated: true).freeze, inner_command] }
    child_model = Ractor.make_shareable({ updated: false }, copy: true)

    message = [:stats, :refresh]

    result = Rooibos.delegate(message, :stats, child_update, child_model)

    refute_nil result
    new_child, wrapped_command = result
    assert_equal({ updated: true }, new_child)
    assert_kind_of Rooibos::Command::Mapped, wrapped_command

    # Verify the command is properly wrapped
    original_result = Rooibos::Message::System::Batch.new(
      envelope: :files, stdout: "a.txt", stderr: "", status: 0
    )
    transformed = wrapped_command.mapper.call(original_result)
    assert_equal [:stats, original_result], transformed
  end
end
