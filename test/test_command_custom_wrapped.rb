# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestCommandCustomWrapped < Minitest::Test
  # Define callables at class level - they become shareable when wrapped with Command.custom
  SIMPLE_CALLABLE = -> (out, _token) { out.put(:done) }
  SIMPLE_COMMAND = Rooibos::Command.custom(SIMPLE_CALLABLE)

  DELEGATION_CALLABLE = -> (out, token) {
    Thread.current[:delegation_test_args] = [out, token]
  }
  DELEGATION_COMMAND = Rooibos::Command.custom(DELEGATION_CALLABLE)

  def test_custom_returns_callable_command
    assert SIMPLE_COMMAND.rooibos_command?, "Wrapped should be a custom command"
    assert_respond_to SIMPLE_COMMAND, :call
  end

  def test_wrapping_same_proc_twice_produces_distinct_objects
    wrapped_a = Rooibos::Command.custom(SIMPLE_CALLABLE)
    wrapped_b = Rooibos::Command.custom(SIMPLE_CALLABLE)

    refute_same wrapped_a, wrapped_b, "Each wrap should produce a distinct object"
  end

  def test_wrapped_call_delegates_to_callable
    mock_out = Object.new
    mock_token = Object.new
    DELEGATION_COMMAND.call(mock_out, mock_token)

    received_args = Thread.current[:delegation_test_args]
    assert_equal [mock_out, mock_token], received_args
  end

  GRACE_PERIOD_COMMAND = Rooibos::Command.custom(SIMPLE_CALLABLE, grace_period: 10.0)

  def test_custom_grace_period_overrides_default
    assert_equal 10.0, GRACE_PERIOD_COMMAND.rooibos_cancellation_grace_period
  end

  def test_default_grace_period_when_not_specified
    assert_equal 0.1, SIMPLE_COMMAND.rooibos_cancellation_grace_period
  end

  # Block test - blocks defined at class level in production mode
  # rubocop:disable Lint/ConstantDefinitionInBlock
  RatatuiRuby::Debug.suppress_debug_mode do
    BLOCK_COMMAND = Rooibos::Command.custom do |out, token|
      Thread.current[:test_block_args] = [out, token]
    end
  end
  # rubocop:enable Lint/ConstantDefinitionInBlock

  def test_custom_accepts_block
    mock_out = Object.new
    mock_token = Object.new
    BLOCK_COMMAND.call(mock_out, mock_token)

    received_args = Thread.current[:test_block_args]
    assert_equal [mock_out, mock_token], received_args
  end

  # === Documentarian tests: all callable types work ===

  LAMBDA_CALLABLE = -> (out, _token) {
    Thread.current[:lambda_called] = true
  }
  LAMBDA_COMMAND = Rooibos::Command.custom(LAMBDA_CALLABLE)

  def test_accepts_lambda
    LAMBDA_COMMAND.call(Object.new, Object.new)
    assert Thread.current[:lambda_called], "Lambda should be accepted"
  end

  PROC_CALLABLE = proc { |out, _token|
    Thread.current[:proc_called] = true
  }
  PROC_COMMAND = Rooibos::Command.custom(PROC_CALLABLE)

  def test_accepts_proc
    PROC_COMMAND.call(Object.new, Object.new)
    assert Thread.current[:proc_called], "Proc should be accepted"
  end

  # Method objects - wrap at class level in production mode
  class MethodTestHolder
    def self.fetch_data(out, token)
      Thread.current[:method_received] = [out, token]
    end
  end

  # rubocop:disable Lint/ConstantDefinitionInBlock
  RatatuiRuby::Debug.suppress_debug_mode do
    METHOD_COMMAND = Rooibos::Command.custom(MethodTestHolder.method(:fetch_data))
  end
  # rubocop:enable Lint/ConstantDefinitionInBlock

  def test_accepts_method_object
    mock_out = Object.new
    mock_token = Object.new
    METHOD_COMMAND.call(mock_out, mock_token)

    assert_equal [mock_out, mock_token], Thread.current[:method_received], "Method object should be accepted"
  end

  # Callable instance that's shareable
  class ShareableCallable
    def call(out, token)
      Thread.current[:callable_called] = true
    end
  end

  CALLABLE_INSTANCE = ShareableCallable.new
  CALLABLE_INSTANCE_COMMAND = Rooibos::Command.custom(CALLABLE_INSTANCE)

  def test_accepts_callable_instance
    CALLABLE_INSTANCE_COMMAND.call(Object.new, Object.new)
    assert Thread.current[:callable_called], "Callable instance should be accepted"
  end
end
