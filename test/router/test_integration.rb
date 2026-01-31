# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestRouterIntegration < Minitest::Test
  include Rooibos::TestHelper

  # Class variables for order tracking (Ractor-shareable access pattern)
  @@order = []
  ObserveOrderHandler = -> (msg, model) { TestRouterIntegration.class_variable_get(:@@order) << :observe; model }
  InterceptOrderHandler = -> (msg, model) { TestRouterIntegration.class_variable_get(:@@order) << :intercept; model }
  KeymapOrderHandler = -> { TestRouterIntegration.class_variable_get(:@@order) << :keymap; nil }
  MousemapOrderHandler = -> { TestRouterIntegration.class_variable_get(:@@order) << :mousemap; nil }
  ForwardOrderHandler = -> (model, msg) { TestRouterIntegration.class_variable_get(:@@order) << :forward; model }
  OtherwiseOrderHandler = -> (msg, model) { TestRouterIntegration.class_variable_get(:@@order) << :otherwise; model }
  QPredicate = lambda(&:q?)
  ResizePredicate = -> (msg) { msg.respond_to?(:resize?) && msg.resize? }

  # Message processing order contract
  def test_observe_runs_before_intercept
    @@order = []

    # Router with both observe and intercept on same message
    test_class = Class.new do
      include Rooibos::Router

      observe QPredicate, ObserveOrderHandler
      intercept QPredicate, InterceptOrderHandler
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    # Observe should run FIRST, then intercept
    assert_equal [:observe, :intercept], @@order,
      "observe must run before intercept in message processing pipeline"
  end

  # Class variables for message capture (accessible from Ractor-shareable lambdas)
  @@all_messages = []

  def setup
    @@all_messages = []
  end

  def teardown
    @@all_messages = []
  end

  # Commands defined at class level for Ractor-shareability
  ObserveCmd = Rooibos::Command.wait(0.01, :from_observe)
  KeymapCmd = Rooibos::Command.wait(0.01, :from_keymap)

  # Router defined at class level
  class ObserveTestRouter
    include Rooibos::Router

    observe_all -> (msg, model) { [model, ObserveCmd] }

    keymap do |map|
      map.key :q, -> { KeymapCmd }
    end
  end

  # Update defined at class level for Ractor-shareability
  ObserveTestUpdate = -> (msg, m) do
    TestRouterIntegration.class_variable_get(:@@all_messages) << msg

    case msg
    when RatatuiRuby::Event::Key
      ObserveTestRouter.from_router.call(msg, m)
    when -> (x) { x.respond_to?(:type) && x.type == :timer }
      # Timer response - count it and quit after both
      new_count = m[:count] + 1
      if new_count >= 2
        [m.merge(count: new_count), Rooibos::Command.exit]
      else
        [m.merge(count: new_count), nil]
      end
    else
      [m, nil]
    end
  end

  ClearView = -> (_m, t) { t.clear }

  # CRITICAL: observe + keymap returning commands must NOT cause Command::Batch
  # Batch would cause unexpected Message::Batch to be sent to app developers
  def test_observe_commands_do_not_cause_batch
    # Router with observe AND keymap both returning commands
    router_class = Class.new do
      include Rooibos::Router

      observe_all -> (msg, model) { [model, Rooibos::Command.custom(:from_observe)] }

      keymap do |map|
        map.key :q, -> { Rooibos::Command.custom(:from_keymap) }
      end
    end

    update = router_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    _new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    # MUST NOT return a Batch command (causes unexpected Message::Batch)
    refute_kind_of Rooibos::Command::Batch, command,
      "observe + keymap should NOT return a Batch (causes unexpected Message::Batch)"

    # MUST NOT return a raw Array (app devs shouldn't be able to do this either)
    refute_kind_of Array, command,
      "observe + keymap should NOT return raw Array"

    # Should have a commands accessor with exactly 2 commands
    assert_respond_to command, :commands,
      "should return a command wrapper with .commands accessor"
    assert_equal 2, command.commands.size,
      "Should have exactly 2 commands (observe + keymap)"

    # Commands should be in declaration order: observe first, then keymap
    assert_equal :from_observe, command.commands[0].callable,
      "First command should be from observe"
    assert_equal :from_keymap, command.commands[1].callable,
      "Second command should be from keymap"
  end

  def test_intercept_runs_before_keymap
    @@order = []

    # Router with intercept that does NOT match 'q', so keymap should run
    test_class = Class.new do
      include Rooibos::Router

      # Intercept only matches 'x', not 'q'
      intercept lambda(&:x?), InterceptOrderHandler

      keymap do |map|
        map.key :q, KeymapOrderHandler
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    # Press 'q' - intercept won't match, keymap should handle
    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    # Only keymap should run (intercept didn't match)
    assert_equal [:keymap], @@order,
      "keymap should run when intercept predicate doesn't match"

    # Now test that intercept STOPS keymap when it matches
    @@order = []
    update.call(RatatuiRuby::Event::Key.new(code: "x"), model)

    # Only intercept should run (stops before keymap)
    assert_equal [:intercept], @@order,
      "intercept must stop processing before keymap when matched"
  end

  def test_keymap_runs_before_mousemap
    @@order = []

    # Router with both keymap and mousemap
    test_class = Class.new do
      include Rooibos::Router

      keymap do |map|
        map.key :q, KeymapOrderHandler
      end

      mousemap do |map|
        map.scroll :up, MousemapOrderHandler
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    # Key events go to keymap
    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)
    assert_equal [:keymap], @@order,
      "keymap should handle key events"

    # Mouse events go to mousemap (keymap doesn't handle them)
    @@order = []
    update.call(RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0), model)
    assert_equal [:mousemap], @@order,
      "mousemap should handle mouse events"
  end

  def test_mousemap_runs_before_forward
    @@order = []

    # Router with mousemap and forward
    test_class = Class.new do
      include Rooibos::Router

      mousemap do |map|
        map.scroll :up, MousemapOrderHandler
      end

      forward do |messages|
        messages.with_type :resize do |model, message|
          TestRouterIntegration.class_variable_get(:@@order) << :forward
          model
        end
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    # Mouse scroll - mousemap should handle
    update.call(RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0), model)
    assert_equal [:mousemap], @@order,
      "mousemap should handle mouse scroll events"

    # Custom message - forward should handle (mousemap doesn't match)
    @@order = []
    resize_msg = Data.define(:width, :height) do
      def resize? = true
    end.new(width: 100, height: 50)
    update.call(resize_msg, model)
    assert_equal [:forward], @@order,
      "forward should handle custom message types"
  end

  def test_forward_runs_before_otherwise
    @@order = []

    # Child fragment for otherwise routing
    child = Module.new do
      const_set :Init, -> { { received: false } }
      const_set :Update, -> (msg, model) {
        TestRouterIntegration.class_variable_get(:@@order) << :otherwise
        [model.merge(received: true), nil]
      }
    end

    # Router with forward and otherwise
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: child

      forward do |messages|
        messages.with_type :resize do |model, message|
          TestRouterIntegration.class_variable_get(:@@order) << :forward
          model
        end
      end

      otherwise route_to: :child
    end

    model_class = Data.define(:child)
    model = model_class.new(child: child::Init.call)
    update = test_class.from_router

    # Resize message - forward should handle
    resize_msg = Data.define(:width, :height) do
      def resize? = true
    end.new(width: 100, height: 50)
    update.call(resize_msg, model)
    assert_equal [:forward], @@order,
      "forward should handle matching messages"

    # Unhandled message - otherwise should route to child
    @@order = []
    update.call(:completely_random_message, model)
    assert_equal [:otherwise], @@order,
      "otherwise should route unhandled messages to child fragment"
  end

  def test_full_pipeline_order_with_all_handlers
    @@order = []

    # Child fragment for otherwise routing
    child = Module.new do
      const_set :Init, -> { { count: 0 } }
      const_set :Update, -> (msg, model) {
        TestRouterIntegration.class_variable_get(:@@order) << :otherwise
        [model.merge(count: model[:count] + 1), nil]
      }
    end

    # Router with ALL handlers in the pipeline
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: child

      # observe always runs first (for matching messages)
      observe_all -> (msg, model) {
        TestRouterIntegration.class_variable_get(:@@order) << :observe
        model
      }

      # intercept runs after observe, stops on match
      intercept -> (msg) { msg.respond_to?(:ctrl_c?) && msg.ctrl_c? }, -> (msg, model) {
        TestRouterIntegration.class_variable_get(:@@order) << :intercept
        model
      }

      keymap do |map|
        map.key :q, -> {
          TestRouterIntegration.class_variable_get(:@@order) << :keymap
          nil
        }
      end

      mousemap do |map|
        map.scroll :up, -> {
          TestRouterIntegration.class_variable_get(:@@order) << :mousemap
          nil
        }
      end

      forward do |messages|
        messages.with_type :resize do |model, message|
          TestRouterIntegration.class_variable_get(:@@order) << :forward
          model
        end
      end

      otherwise route_to: :child
    end

    model_class = Data.define(:child)
    model = model_class.new(child: child::Init.call)
    update = test_class.from_router

    # Test: Key event - observe then keymap
    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)
    assert_equal [:observe, :keymap], @@order,
      "Key event: observe should run, then keymap"

    # Test: Ctrl+C - observe then intercept (stops before keymap)
    @@order = []
    update.call(RatatuiRuby::Event::Key.new(code: "ctrl_c"), model)
    assert_equal [:observe, :intercept], @@order,
      "Ctrl+C: observe should run, then intercept should stop processing"

    # Test: Mouse scroll - observe then mousemap
    @@order = []
    update.call(RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0), model)
    assert_equal [:observe, :mousemap], @@order,
      "Mouse scroll: observe should run, then mousemap"

    # Test: Resize message - observe then forward
    @@order = []
    resize_msg = Data.define(:width, :height) do
      def resize? = true
    end.new(width: 100, height: 50)
    update.call(resize_msg, model)
    assert_equal [:observe, :forward], @@order,
      "Resize message: observe should run, then forward"

    # Test: Unknown message - observe then otherwise
    @@order = []
    update.call(:unknown_message, model)
    assert_equal [:observe, :otherwise], @@order,
      "Unknown message: observe should run, then otherwise should route to child"
  end
end
