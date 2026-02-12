# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

# Tests for Rooibos::Transition.normalize - DWIM return value handling.
class TestTransitionNormalize < Minitest::Test
  def setup
    @model = { count: 0 }
  end

  def test_nil_preserves_previous_model
    result = Rooibos::Transition.from(nil, @model)

    assert_equal @model, result.model, "nil result should preserve previous model"
    assert_nil result.command, "nil result should have no command"
  end

  def test_model_uses_new_model
    new_model = { count: 42 }

    result = Rooibos::Transition.from(new_model, @model)

    assert_equal new_model, result.model, "model result should use new model"
    assert_nil result.command, "model result should have no command"
  end

  def test_command_preserves_previous_model
    command = Rooibos::Command.exit

    result = Rooibos::Transition.from(command, @model)

    assert_equal @model, result.model, "command result should preserve previous model"
    assert_equal command, result.command, "command result should use command"
  end

  def test_tuple_uses_both
    new_model = { count: 99 }
    command = Rooibos::Command.exit

    result = Rooibos::Transition.from([new_model, command], @model)

    assert_equal new_model, result.model, "tuple result should use new model"
    assert_equal command, result.command, "tuple result should use command"
  end

  def test_tuple_with_nil_command
    new_model = { count: 77 }

    result = Rooibos::Transition.from([new_model, nil], @model)

    assert_equal new_model, result.model, "tuple with nil command should use new model"
    assert_nil result.command, "tuple with nil command should have nil command"
  end

  def test_array_with_invalid_command_treated_as_model
    array_model = [:foo, :bar]

    result = Rooibos::Transition.from(array_model, @model)

    assert_equal array_model, result.model, "array with non-command second element should be treated as model"
    assert_nil result.command, "array treated as model should have nil command"
  end

  def test_warns_in_debug_mode_for_callable_without_rooibos_command
    bad_command = Object.new
    def bad_command.call(_out, _token); end
    model = { test: true }.freeze

    _, warning_output = capture_io do
      Rooibos::Transition.from([model, bad_command], @model)
    end

    assert_match(/WARNING/, warning_output)
    assert_match(/rooibos_command\?/, warning_output)
  end

  def test_no_warning_for_non_callable_second_element
    array_model = [:foo, :bar]

    _, warning_output = capture_io do
      Rooibos::Transition.from(array_model, @model)
    end

    refute_match(/WARNING/, warning_output)
  end

  def test_no_warning_when_debug_disabled
    bad_command = Object.new
    def bad_command.call(_out, _token); end
    model = { test: true }.freeze

    _, warning_output = capture_io do
      RatatuiRuby::Debug.suppress_debug_mode do
        Rooibos::Transition.from([model, bad_command], @model)
      end
    end

    refute_match(/WARNING/, warning_output)
  end

  def test_no_warning_for_ractor_shareable_tuple
    callable_data = Data.define do
      def call(x); x + 1; end
    end
    callable = callable_data.new
    model = { test: true }
    shareable_tuple = Ractor.make_shareable([model, callable])

    _, warning_output = capture_io do
      RatatuiRuby::Debug.enable!(source: :test)
      Rooibos::Transition.from(shareable_tuple, @model)
    end

    refute_match(/WARNING/, warning_output)
  end

  def test_no_warning_for_proper_command
    good_command = Class.new do
      include Rooibos::Command::Custom
      def call = nil
    end
    model = { test: true }.freeze

    _, warning_output = capture_io do
      RatatuiRuby::Debug.enable!(source: :test)
      # This would warn IF we treated it as [model, callable] but it's a valid tuple
      Rooibos::Transition.from([model, good_command], @model)
    end

    refute_match(/WARNING/, warning_output)
  end
end
