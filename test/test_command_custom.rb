# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestCommandCustom < Minitest::Test
  include Rooibos::TestHelper

  def test_rooibos_command_returns_true
    klass = Class.new do
      include Rooibos::Command::Custom
    end

    assert klass.new.rooibos_command?, "rooibos_command? should return true"
  end

  def test_default_grace_period_is_two_seconds
    klass = Class.new do
      include Rooibos::Command::Custom
    end

    assert_equal 0.1, klass.new.rooibos_cancellation_grace_period
  end

  def test_grace_period_can_be_overridden
    klass = Class.new do
      include Rooibos::Command::Custom

      def rooibos_cancellation_grace_period
        Float::INFINITY
      end
    end

    assert_equal Float::INFINITY, klass.new.rooibos_cancellation_grace_period
  end

  ShareableProc = Ractor.make_shareable(-> (_out, _token) { :test_message })
  def test_command_custom_is_ractor_shareable
    # App developers should not need to manually wrap Command.custom with Ractor.make_shareable
    cmd = Rooibos::Command.custom(ShareableProc)

    assert Ractor.shareable?(cmd), "Command.custom should return a Ractor-shareable object automatically"
  end

  MutableString = String.new
  class NonShareableCommand
    include Rooibos::Command::Custom
    Closure = -> (out, token) { MutableString << "test" }
    def call(out, token)
      Closure.call(out, token)
    end
  end

  NonShareableProcThatCanBeMadeShareable = -> (_out, _token) { :test_message }
  def test_command_custom_raises_invariant_error_in_debug_mode_if_not_already_ractor_shareable
    # Create proc dynamically so it's not already shareable
    non_shareable_proc = -> (_out, _token) { :test_message }

    error = assert_raises(Rooibos::Error::Invariant) do
      Rooibos::Command.custom(non_shareable_proc)
    end

    assert_match(/ractor-shareable/i, error.message)
  end

  # --- deconstruct_keys tests ---

  class SimpleCommand
    include Rooibos::Command::Custom
  end

  def test_deconstruct_keys_returns_hash_with_type_key
    result = SimpleCommand.new.deconstruct_keys(nil)

    assert_kind_of Hash, result
    assert result.key?(:type), "deconstruct_keys must include :type key"
  end

  def test_deconstruct_keys_type_is_snake_case_of_class_name
    result = SimpleCommand.new.deconstruct_keys(nil)

    assert_equal :simple_command, result[:type]
  end

  def test_deconstruct_keys_anonymous_class_uses_custom_type
    klass = Class.new { include Rooibos::Command::Custom }
    result = klass.new.deconstruct_keys(nil)

    assert_equal :custom, result[:type]
  end

  DataCommand = Data.define(:url, :timeout) do
    include Rooibos::Command::Custom
  end

  def test_deconstruct_keys_includes_data_define_members
    cmd = DataCommand.new(url: "https://example.com", timeout: 30)
    result = cmd.deconstruct_keys(nil)

    assert_equal "https://example.com", result[:url]
    assert_equal 30, result[:timeout]
  end

  class CommandWithQueryMethod
    include Rooibos::Command::Custom

    def status
      :running
    end
  end

  def test_deconstruct_keys_includes_custom_query_methods
    cmd = CommandWithQueryMethod.new
    result = cmd.deconstruct_keys(nil)

    assert_equal :running, result[:status]
  end

  class CommandWithSetter
    include Rooibos::Command::Custom

    attr_accessor :value
  end

  def test_deconstruct_keys_excludes_setters
    cmd = CommandWithSetter.new
    cmd.value = 42
    result = cmd.deconstruct_keys(nil)

    assert_equal 42, result[:value], "getter should be included"
    refute result.key?(:value=), "setter should be excluded"
  end

  class CommandWithBangMethod
    include Rooibos::Command::Custom

    def reset!
      :resetting
    end
  end

  def test_deconstruct_keys_excludes_bang_methods
    cmd = CommandWithBangMethod.new
    result = cmd.deconstruct_keys(nil)

    refute result.key?(:reset!), "bang method should be excluded"
  end

  def test_deconstruct_keys_excludes_data_infrastructure_methods
    cmd = DataCommand.new(url: "https://example.com", timeout: 30)
    result = cmd.deconstruct_keys(nil)

    refute result.key?(:to_h), ":to_h should be excluded"
    refute result.key?(:members), ":members should be excluded"
    refute result.key?(:deconstruct), ":deconstruct should be excluded"
  end

  def test_deconstruct_keys_respects_keys_argument
    cmd = DataCommand.new(url: "https://example.com", timeout: 30)
    result = cmd.deconstruct_keys([:url, :type])

    assert result.key?(:type), ":type should be included when requested"
    assert result.key?(:url), ":url should be included when requested"
    refute result.key?(:timeout), ":timeout should be excluded when not requested"
  end

  class CommandWithPredicate
    include Rooibos::Command::Custom

    def ready?
      true
    end
  end

  def test_deconstruct_keys_includes_predicate_methods
    cmd = CommandWithPredicate.new
    result = cmd.deconstruct_keys(nil)

    assert_equal true, result[:ready?], "predicate methods should be included"
  end

  # Edge case: :method is an infrastructure method but also a valid Data.define member
  HttpRequest = Data.define(:url, :method) do
    include Rooibos::Command::Custom
  end

  def test_deconstruct_keys_includes_method_member_from_data_define
    cmd = HttpRequest.new(url: "https://api.example.com", method: :post)
    result = cmd.deconstruct_keys(nil)

    assert_equal :post, result[:method], ":method member should be included"
    assert_equal "https://api.example.com", result[:url]
  end

  def test_deconstruct_keys_includes_mixin_methods
    cmd = SimpleCommand.new
    result = cmd.deconstruct_keys(nil)

    assert_equal true, result[:rooibos_command?], "rooibos_command? should be included"
    assert_equal 0.1, result[:rooibos_cancellation_grace_period], "grace period should be included"
  end
end
