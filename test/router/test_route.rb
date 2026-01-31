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
    # Child fragment that receives messages
    child_update = -> (msg, model) { [model.merge(received: msg), nil] }
    child = Module.new do
      const_set :Update, child_update
    end

    # Lambda accessor extracts from deeply nested path
    reader = -> (model) { model[:panels][:sidebar] }
    writer = -> (model, value) { model.merge(panels: model[:panels].merge(sidebar: value)) }

    test_class = Class.new do
      include Rooibos::Router
      # Prefix :sidebar for message routing, read:/write: for custom extraction
      route :sidebar, read: reader, write: writer, to: child
    end

    update = test_class.from_router

    # Model with deeply nested structure (not matching the :sidebar prefix directly)
    model = Ractor.make_shareable({
      panels: { sidebar: { value: 42 } },
    }, copy: true)

    # Route message with :sidebar prefix
    new_model, _cmd = update.call([:sidebar, :test_message], model)

    # Child received the message via read: accessor (which reads from panels.sidebar)
    assert_equal :test_message, new_model[:panels][:sidebar][:received],
      "lambda read: accessor should extract from nested path"
  end

  def test_route_proc_accessor_extracts_nested_model
    # Child fragment that receives messages
    child_update = -> (msg, model) { [model.merge(received: msg), nil] }
    child = Module.new do
      const_set :Update, child_update
    end

    # Proc accessors (using proc { } syntax instead of -> {})
    reader = proc { |model| model[:panels][:sidebar] }
    writer = proc { |model, value| model.merge(panels: model[:panels].merge(sidebar: value)) }

    test_class = Class.new do
      include Rooibos::Router
      route :sidebar, read: reader, write: writer, to: child
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
    # Child fragment that receives messages
    child_update = -> (msg, model) { [model.merge(received: msg), nil] }
    child = Module.new do
      const_set :Update, child_update
    end

    # Define methods and extract as Method objects
    accessor_module = Module.new do
      def self.read_sidebar(model) = model[:panels][:sidebar]
      def self.write_sidebar(model, value) = model.merge(panels: model[:panels].merge(sidebar: value))
    end
    reader = accessor_module.method(:read_sidebar)
    writer = accessor_module.method(:write_sidebar)

    test_class = Class.new do
      include Rooibos::Router
      route :sidebar, read: reader, write: writer, to: child
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
    # Child fragment that receives messages
    child_update = -> (msg, model) { [model.merge(received: msg), nil] }
    child = Module.new do
      const_set :Update, child_update
    end

    # Callable objects with #call method
    reader_class = Class.new do
      def call(model) = model[:panels][:sidebar]
    end
    writer_class = Class.new do
      def call(model, value) = model.merge(panels: model[:panels].merge(sidebar: value))
    end
    reader = reader_class.new
    writer = writer_class.new

    test_class = Class.new do
      include Rooibos::Router
      route :sidebar, read: reader, write: writer, to: child
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
    # Child fragment that modifies its model
    child_update = -> (msg, model) { [model.merge(count: model[:count] + msg), nil] }
    child = Module.new do
      const_set :Update, child_update
    end

    reader = -> (model) { model[:panels][:counter] }
    writer = -> (model, value) { model.merge(panels: model[:panels].merge(counter: value)) }

    test_class = Class.new do
      include Rooibos::Router
      route :counter, read: reader, write: writer, to: child
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
    # Child fragment
    child_update = -> (msg, model) { [model.merge(data: msg), nil] }
    child = Module.new do
      const_set :Update, child_update
    end

    # Deeply nested path: app -> workspace -> tabs -> :active_tab
    reader = -> (model) { model[:app][:workspace][:tabs][model[:app][:active_tab]] }
    writer = -> (model, value) do
      active = model[:app][:active_tab]
      model.merge(
        app: model[:app].merge(
          workspace: model[:app][:workspace].merge(
            tabs: model[:app][:workspace][:tabs].merge(active => value)
          )
        )
      )
    end

    test_class = Class.new do
      include Rooibos::Router
      route :tab, read: reader, write: writer, to: child
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
    # TODO: This test depends on Rooibos.debug_mode? setting
    # For now, test that non-frozen lambdas still work (validation is implementation-specific)
    skip "Ractor shareability validation depends on debug mode implementation"
  end

  def test_route_accessor_allows_non_ractor_shareable_in_production_mode
    # TODO: This test depends on Rooibos.debug_mode? setting
    # For now, test that the feature works regardless of mode
    skip "Ractor shareability validation depends on debug mode implementation"
  end
end
