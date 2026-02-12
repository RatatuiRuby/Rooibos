# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

# Tests for Rooibos::Transition instance methods.
class TestTransitionInstance < Minitest::Test
  def setup
    @model = { count: 0 }
  end

  def test_initial_creates_outcome_with_nil_command
    result = Rooibos::Transition.initial(@model)

    assert_equal @model, result.model
    assert_nil result.command
  end

  def test_with_model_returns_new_outcome_with_updated_model
    command = Rooibos::Command.exit
    outcome = Rooibos::Transition.new(model: @model, command:)
    new_model = { count: 42 }

    result = outcome.with_model(new_model)

    assert_equal new_model, result.model
    assert_equal command, result.command, "command should be preserved"
  end

  def test_with_model_returns_self_when_nil
    outcome = Rooibos::Transition.new(model: @model, command: nil)

    result = outcome.with_model(nil)

    assert_same outcome, result, "with_model(nil) should return self"
  end

  def test_with_command_returns_new_outcome_with_updated_command
    outcome = Rooibos::Transition.new(model: @model, command: nil)
    command = Rooibos::Command.exit

    result = outcome.with_command(command)

    assert_equal @model, result.model, "model should be preserved"
    assert_equal command, result.command
  end

  def test_with_command_returns_self_when_nil
    command = Rooibos::Command.exit
    outcome = Rooibos::Transition.new(model: @model, command:)

    result = outcome.with_command(nil)

    assert_same outcome, result, "with_command(nil) should return self"
  end

  def test_with_added_command_sets_command_when_nil
    outcome = Rooibos::Transition.new(model: @model, command: nil)
    command = Rooibos::Command.exit

    result = outcome.with_added_command(command)

    assert_equal command, result.command
  end

  def test_with_added_command_batches_when_command_exists
    existing = Rooibos::Command.exit
    outcome = Rooibos::Transition.new(model: @model, command: existing)
    new_command = Rooibos::Command.exit # Another command

    result = outcome.with_added_command(new_command)

    assert_kind_of Rooibos::Command::Batch, result.command
    assert_equal [existing, new_command], result.command.commands
  end

  def test_to_a_returns_model_command_tuple
    command = Rooibos::Command.exit
    outcome = Rooibos::Transition.new(model: @model, command:)

    result = outcome.to_a

    assert_equal [@model, command], result
  end
end
