# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterRoute < Minitest::Test
  # Fake child module for testing
  module FakeChild
    INITIAL = :child_initial
    Update = -> (msg, model) { [model, nil] }
  end

  # route registers a child with a prefix.
  # The prefix is normalized to a symbol via .to_s.to_sym.
  def test_route_registers_child_with_prefix
    test_class = Class.new do
      include Rooibos::Router

      route :stats, to: TestRouterRoute::FakeChild
      route "network", to: TestRouterRoute::FakeChild # String works too
    end

    assert_equal FakeChild, test_class.routes[:stats]
    assert_equal FakeChild, test_class.routes[:network]
  end

  def test_from_router_returns_callable
    test_class = Class.new do
      include Rooibos::Router
    end

    update = test_class.from_router

    assert update.respond_to?(:call)
  end

  def test_generated_update_routes_prefixed_messages_to_child_update
    # FakeChild is defined at class level with proper UPDATE constant
    test_class = Class.new do
      include Rooibos::Router
      route :child, to: TestRouterRoute::FakeChild
    end

    update = test_class.from_router

    # Create a model with a :child accessor (using Data.define)
    model_class = Data.define(:child)
    model = model_class.new(child: { output: "initial" }.freeze)

    message = [:child, :system_info, { stdout: "Darwin" }]

    new_model, _cmd = update.call(message, model)

    # Verify it delegated and returned updated model
    refute_nil new_model
  end

  # ============================================================================
  # [ADD] Callable accessor tests
  # ============================================================================

  def test_route_lambda_accessor_extracts_nested_model
    skip "TODO"
  end

  def test_route_proc_accessor_extracts_nested_model
    skip "TODO"
  end

  def test_route_method_accessor_extracts_nested_model
    skip "TODO"
  end

  def test_route_callable_object_accessor_extracts_nested_model
    skip "TODO"
  end

  def test_route_accessor_updates_nested_model_in_outer
    skip "TODO"
  end

  def test_route_accessor_with_deeply_nested_path
    skip "TODO"
  end

  def test_route_accessor_validates_ractor_shareable_in_debug_mode
    skip "TODO"
  end

  def test_route_accessor_allows_non_ractor_shareable_in_production_mode
    skip "TODO"
  end
end

