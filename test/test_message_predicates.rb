# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestMessagePredicates < Minitest::Test
  include Rooibos::TestHelper

  # Test stub that includes Predicates mixin
  StubMessage = Data.define(:value) do
    include Rooibos::Message::Predicates
  end

  def test_unknown_predicate_returns_false
    msg = StubMessage.new(value: 42)

    refute msg.http?,        "Unknown predicate http? should return false"
    refute msg.scroll_down?, "Unknown predicate scroll_down? should return false"
  end

  def test_non_predicate_method_raises_no_method_error
    msg = StubMessage.new(value: 42)

    assert_raises(NoMethodError) { msg.some_random_method }
  end

  def test_predicate_with_arguments_raises_no_method_error
    msg = StubMessage.new(value: 42)

    assert_raises(NoMethodError) { msg.success?(:arg) }
  end

  def test_predicate_with_keyword_arguments_raises_no_method_error
    msg = StubMessage.new(value: 42)

    assert_raises(NoMethodError) { msg.http?(key: :val) }
  end

  def test_responds_to_unknown_predicates
    msg = StubMessage.new(value: 42)

    assert msg.respond_to?(:http?), "Should respond_to? unknown predicate"
  end

  def test_does_not_respond_to_non_predicates
    msg = StubMessage.new(value: 42)

    refute msg.respond_to?(:some_random_method), "Should not respond_to? non-predicates"
  end

  # === to_sym and == tests ===

  # Test stub with proper deconstruct_keys for symbol comparison
  TypedStub = Data.define(:value) do
    include Rooibos::Message::Predicates

    def deconstruct_keys(_keys)
      { type: :custom, value: }
    end
  end

  def test_to_sym_returns_type
    msg = TypedStub.new(value: 42)
    assert_equal :message_custom, msg.to_sym
  end

  def test_symbol_equality
    msg = TypedStub.new(value: 42)
    assert_operator msg, :==, :message_custom
    refute_operator msg, :==, :message_timer
  end

  def test_symbol_equality_preserves_data_equality
    msg1 = TypedStub.new(value: 42)
    msg2 = TypedStub.new(value: 42)
    msg3 = TypedStub.new(value: 99)

    assert_equal msg1, msg2, "Same values should be equal"
    refute_equal msg1, msg3, "Different values should not be equal"
  end

  # === Default deconstruct_keys tests ===

  # Simple stub relying on default deconstruct_keys (no override)
  class SimpleMessage
    include Rooibos::Message::Predicates
  end

  # CamelCase name for snake_case conversion test
  class MyCustomMessage
    include Rooibos::Message::Predicates
  end

  def test_default_deconstruct_keys_derives_type_from_class_name
    msg = SimpleMessage.new
    keys = msg.deconstruct_keys(nil)

    assert_equal :simple_message, keys[:type]
  end

  def test_default_deconstruct_keys_converts_camel_case_to_snake_case
    msg = MyCustomMessage.new
    keys = msg.deconstruct_keys(nil)

    assert_equal :my_custom_message, keys[:type]
  end

  def test_default_deconstruct_keys_uses_only_basename
    # Namespace prefix should be stripped
    msg = SimpleMessage.new
    # TestMessagePredicates::SimpleMessage -> simple_message
    assert_equal :simple_message, msg.deconstruct_keys(nil)[:type]
  end

  def test_default_deconstruct_keys_anonymous_class_fallback
    anon_class = Class.new { include Rooibos::Message::Predicates }
    msg = anon_class.new
    keys = msg.deconstruct_keys(nil)

    assert_equal :custom, keys[:type], "Anonymous classes should default to :custom"
  end

  def test_to_sym_uses_default_deconstruct_keys
    msg = MyCustomMessage.new

    assert_equal :message_my_custom_message, msg.to_sym
  end

  def test_symbol_equality_with_default_deconstruct_keys
    msg = MyCustomMessage.new

    assert_operator msg, :==, :message_my_custom_message
    refute_operator msg, :==, :message_simple_message
  end

  # === Documentarian Example ===
  #
  # This shows how an app developer creates a custom message type
  # for their domain, using it with a custom command in the full runtime.
  module MyApp
    module Weather
      CurrentWeather = Data.define(:temperature, :conditions)

      class Gateway
        def fetch
          sleep 0.05 # Pretend this is a complex UDP song and dance
          CurrentWeather.new(temperature: 72, conditions: :sunny)
        end
      end
    end
  end

  # A custom message for a weather fetch command.
  # Include Predicates so users can call any predicate safely.
  WeatherResponse = Data.define(:envelope, :temperature, :conditions, :error) do
    include Rooibos::Message::Predicates

    def weather? = true
    def sunny? = conditions == :sunny
    def rainy? = conditions == :rainy

    def deconstruct_keys(_keys)
      if error
        { type: :weather, envelope:, error: }
      else
        { type: :weather, envelope:, temperature:, conditions: }
      end
    end
  end

  # A custom command that fetches weather and emits WeatherResponse.
  FetchWeather = Data.define(:envelope) do
    include Rooibos::Command::Custom

    def call(out, _token)
      current_weather = MyApp::Weather::Gateway.new.fetch
      response = Ractor.make_shareable(
        WeatherResponse.new(
          envelope:,
          temperature: current_weather.temperature,
          conditions: current_weather.conditions,
          error: nil
        )
      )
      out.put(response)
    end
  end

  def test_custom_message_with_predicates_in_runtime_loop
    received = nil
    model = Ractor.make_shareable({})
    view = -> (_model, tui) { tui.clear }

    update = -> (message, model) do
      case message
      in { type: :key, code: "w" }
        FetchWeather.new(envelope: :current)
      in { type: :key, code: "q" }
        Rooibos::Command.exit
      in { type: :weather, envelope: :current, temperature: _, conditions: _ }
        received = message
        model
      else
        model
      end
    end

    with_test_terminal do
      inject_key("w")  # Fetch weather
      inject_sync      # Wait for command to complete
      inject_key("q")  # Quit

      Rooibos::Runtime.run(model:, view:, update:)
    end

    refute_nil received, "Update should receive WeatherResponse"
    assert received.weather?, "weather? should return true"
    assert received.sunny?,   "sunny? should return true for sunny conditions"
    refute received.rainy?,   "rainy? should return false for sunny conditions"
    refute received.http?,    "http? should return false (via Predicates fallback)"
  end
end
