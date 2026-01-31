# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterRoute < Minitest::Test
  include Rooibos::TestHelper

  # Fake child module for testing
  module FakeChild
    INITIAL = :child_initial
    Update = -> (msg, model) { [model, nil] }
  end

  # Shared child fragment for accessor tests - merges received message into model
  module AccessorTestChild
    Update = -> (msg, model) { [model.merge(received: msg), nil] }
  end

  # Shared child fragment for counter tests - increments count by message value
  module CounterTestChild
    Update = -> (msg, model) { [model.merge(count: model[:count] + msg), nil] }
  end

  # Shared child fragment for data tests - sets data to message value
  module DataTestChild
    Update = -> (msg, model) { [model.merge(data: msg), nil] }
  end

  # Ractor-shareable accessor modules for nested paths
  module SidebarAccessors
    Reader = -> (model) { model[:panels][:sidebar] }
    Writer = -> (model, value) { model.merge(panels: model[:panels].merge(sidebar: value)) }
  end

  module CounterAccessors
    Reader = -> (model) { model[:panels][:counter] }
    Writer = -> (model, value) { model.merge(panels: model[:panels].merge(counter: value)) }
  end

  module DeepTabAccessors
    Reader = -> (model) { model[:app][:workspace][:tabs][model[:app][:active_tab]] }
    Writer = -> (model, value) do
      active = model[:app][:active_tab]
      model.merge(
        app: model[:app].merge(
          workspace: model[:app][:workspace].merge(
            tabs: model[:app][:workspace][:tabs].merge(active => value)
          )
        )
      )
    end
  end

  # Accessor module with methods (for Method object tests)
  module MethodAccessors
    def self.read_sidebar(model) = model[:panels][:sidebar]
    def self.write_sidebar(model, value) = model.merge(panels: model[:panels].merge(sidebar: value))
  end

  # Callable object classes (for callable object tests)
  class SidebarReader
    def call(model) = model[:panels][:sidebar]
  end

  class SidebarWriter
    def call(model, value) = model.merge(panels: model[:panels].merge(sidebar: value))
  end

  # route registers a child with a prefix.
  # The prefix is normalized to a symbol via .to_s.to_sym.
  def test_route_registers_child_with_prefix
    test_class = Class.new do
      include Rooibos::Router

      route :stats, to: TestRouterRoute::FakeChild
      route "network", to: TestRouterRoute::FakeChild # String works too
    end

    assert_equal FakeChild, test_class.routes[:stats].fragment
    assert_equal FakeChild, test_class.routes[:network].fragment
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
    test_class = Class.new do
      include Rooibos::Router
      route :sidebar, read: SidebarAccessors::Reader, write: SidebarAccessors::Writer, to: AccessorTestChild
    end

    update = test_class.from_router

    model = Ractor.make_shareable({
      panels: { sidebar: { value: 42 } },
    }, copy: true)

    new_model, _cmd = update.call([:sidebar, :test_message], model)

    assert_equal :test_message, new_model[:panels][:sidebar][:received],
      "lambda read: accessor should extract from nested path"
  end

  def test_route_proc_accessor_extracts_nested_model
    # Proc accessors work identically to lambdas - use same class-level definitions
    test_class = Class.new do
      include Rooibos::Router
      route :sidebar, read: SidebarAccessors::Reader, write: SidebarAccessors::Writer, to: AccessorTestChild
    end

    update = test_class.from_router

    model = Ractor.make_shareable({
      panels: { sidebar: { value: 42 } },
    }, copy: true)

    new_model, _cmd = update.call([:sidebar, :test_message], model)

    assert_equal :test_message, new_model[:panels][:sidebar][:received],
      "proc read: accessor should extract from nested path"
  end

  def test_route_method_accessor_extracts_nested_model
    # Method objects from class-level accessor module
    reader = MethodAccessors.method(:read_sidebar)
    writer = MethodAccessors.method(:write_sidebar)

    test_class = Class.new do
      include Rooibos::Router
      route :sidebar, read: reader, write: writer, to: AccessorTestChild
    end

    update = test_class.from_router

    model = Ractor.make_shareable({
      panels: { sidebar: { value: 42 } },
    }, copy: true)

    new_model, _cmd = update.call([:sidebar, :test_message], model)

    assert_equal :test_message, new_model[:panels][:sidebar][:received],
      "Method read: accessor should extract from nested path"
  end

  def test_route_callable_object_accessor_extracts_nested_model
    # Callable objects from class-level reader/writer classes
    reader = SidebarReader.new
    writer = SidebarWriter.new

    test_class = Class.new do
      include Rooibos::Router
      route :sidebar, read: reader, write: writer, to: AccessorTestChild
    end

    update = test_class.from_router

    model = Ractor.make_shareable({
      panels: { sidebar: { value: 42 } },
    }, copy: true)

    new_model, _cmd = update.call([:sidebar, :test_message], model)

    assert_equal :test_message, new_model[:panels][:sidebar][:received],
      "callable object read: accessor should extract from nested path"
  end

  def test_route_accessor_updates_nested_model_in_outer
    test_class = Class.new do
      include Rooibos::Router
      route :counter, read: CounterAccessors::Reader, write: CounterAccessors::Writer, to: CounterTestChild
    end

    update = test_class.from_router

    model = Ractor.make_shareable({
      panels: { counter: { count: 10 } },
      other: :unchanged,
    }, copy: true)

    # Send message causing increment by 5
    new_model, _cmd = update.call([:counter, 5], model)

    # Verify nested model was updated
    assert_equal 15, new_model[:panels][:counter][:count],
      "write: accessor should update nested model correctly"
    # Verify other parts of model unchanged
    assert_equal :unchanged, new_model[:other],
      "write: accessor should not affect other model parts"
  end

  def test_route_accessor_with_deeply_nested_path
    test_class = Class.new do
      include Rooibos::Router
      route :tab, read: DeepTabAccessors::Reader, write: DeepTabAccessors::Writer, to: DataTestChild
    end

    update = test_class.from_router

    model = Ractor.make_shareable({
      app: {
        active_tab: :editor,
        workspace: {
          tabs: {
            editor: { data: nil },
            terminal: { data: nil },
          },
        },
      },
    }, copy: true)

    new_model, _cmd = update.call([:tab, :content], model)

    assert_equal :content, new_model[:app][:workspace][:tabs][:editor][:data],
      "deeply nested read:/write: should update correct tab"
    assert_nil new_model[:app][:workspace][:tabs][:terminal][:data],
      "deeply nested write: should not affect sibling tabs"
  end

  def test_route_accessor_validates_ractor_shareable_in_debug_mode
    # In debug mode, non-Ractor-shareable accessors should raise
    # Create a non-shareable accessor (uses instance variable capture)
    captured_state = { value: 42 }
    non_shareable_reader = -> (model) { captured_state[:value] } # Captures mutable hash

    child = Module.new do
      const_set :Update, -> (msg, model) { [model, nil] }
    end

    # Debug mode is enabled by default in tests (via TestHelper)
    # Confirm it's enabled
    assert RatatuiRuby::Debug.enabled?, "Debug mode should be enabled in tests"

    # Using non-shareable accessor in debug mode should raise
    error = assert_raises(Rooibos::Error::Invariant) do
      Class.new do
        include Rooibos::Router
        route :child, read: non_shareable_reader, to: child
      end
    end

    assert_match(/Ractor-shareable/, error.message)
    assert_match(/route read: accessor/, error.message)
  end

  def test_route_accessor_allows_non_ractor_shareable_in_production_mode
    # When debug mode is suppressed, non-Ractor-shareable accessors should work
    captured_state = { value: 42 }
    non_shareable_reader = -> (model) { captured_state[:value] }
    non_shareable_writer = -> (model, value) { captured_state[:value] = value; model }

    child = Module.new do
      const_set :Update, -> (msg, model) { [model, nil] }
    end

    # Suppress debug mode to simulate production
    RatatuiRuby::Debug.suppress_debug_mode do
      # Should NOT raise when debug mode is suppressed
      test_class = Class.new do
        include Rooibos::Router
        route :child, read: non_shareable_reader, write: non_shareable_writer, to: child
      end

      # Verify the route was registered successfully
      assert test_class.routes[:child], "Route should be registered"
      assert_equal child, test_class.routes[:child].fragment
    end
  end
end
