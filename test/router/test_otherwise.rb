# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

# Child fragment for otherwise routing tests
module OtherwiseTestChild
  Model = Data.define(:received_count)
  Init = -> { Model.new(received_count: 0) }
  Update = -> (msg, model) {
    model.with(received_count: model.received_count + 1)
  }
end

# Grandchild fragment for deep hierarchy tests
module OtherwiseTestGrandchild
  Model = Data.define(:received_count)
  Init = -> { Model.new(received_count: 0) }
  Update = -> (msg, model) {
    model.with(received_count: model.received_count + 1)
  }
end

# Middle fragment for deep hierarchy tests
class OtherwiseTestMiddle
  include Rooibos::Router

  Model = Data.define(:grandchild)
  Init = -> { Model.new(grandchild: OtherwiseTestGrandchild::Init.call) }

  route :grandchild, to: OtherwiseTestGrandchild
  otherwise route_to: :grandchild

  Update = from_router
end

class TestRouterOtherwise < Minitest::Test
  # =========================================================================
  # 🧪 TEST WRITER: First failing test
  # =========================================================================
  def test_otherwise_routes_unhandled_messages_to_fragment
    # Parent Router with otherwise fallback
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: OtherwiseTestChild

      otherwise route_to: :child
    end

    parent_model = Data.define(:child).new(
      child: OtherwiseTestChild::Init.call
    )
    update = parent_class.from_router

    # Send an unhandled message - should route to child via otherwise
    unhandled_message = :some_random_message
    new_model, _cmd = update.call(unhandled_message, parent_model)

    # Child should have received the message
    assert_equal 1, new_model.child.received_count,
      "otherwise should route unhandled messages to the specified fragment"
  end

  # =========================================================================
  # 🧪 TEST WRITER: Expose loophole - keymap handles, otherwise shouldn't receive
  # =========================================================================
  def test_otherwise_does_not_route_keymap_handled_messages
    # Parent Router with keymap AND otherwise fallback
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: OtherwiseTestChild

      keymap do |map|
        map.key :q, -> { Rooibos::Command.exit }
      end

      otherwise route_to: :child
    end

    parent_model = Data.define(:child).new(
      child: OtherwiseTestChild::Init.call
    )
    update = parent_class.from_router

    # Send a keymap-handled message - should NOT route to child
    key_message = RatatuiRuby::Event::Key.new(code: "q")
    new_model, cmd = update.call(key_message, parent_model)

    # Child should NOT have received the message (keymap handled it)
    assert_equal 0, new_model.child.received_count,
      "otherwise should NOT route messages that keymap already handled"
    assert_kind_of Rooibos::Command::Exit, cmd,
      "keymap's exit command should be returned"
  end

  # =========================================================================
  # 🧪 TEST WRITER: Mousemap-handled messages should NOT reach otherwise
  # =========================================================================
  def test_otherwise_does_not_route_mousemap_handled_messages
    # Parent Router with mousemap AND otherwise fallback
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: OtherwiseTestChild

      mousemap do |map|
        map.scroll :up, -> { nil }
      end

      otherwise route_to: :child
    end

    parent_model = Data.define(:child).new(
      child: OtherwiseTestChild::Init.call
    )
    update = parent_class.from_router

    # Send a mousemap-handled message - should NOT route to child
    scroll_event = RatatuiRuby::Event::Mouse.new(kind: "scroll_up", button: "left", x: 0, y: 0)
    new_model, _cmd = update.call(scroll_event, parent_model)

    # Child should NOT have received the message (mousemap handled it)
    assert_equal 0, new_model.child.received_count,
      "otherwise should NOT route messages that mousemap already handled"
  end

  # =========================================================================
  # 🧪 TEST WRITER: Forward-handled messages should NOT reach otherwise
  # =========================================================================
  def test_otherwise_does_not_route_forward_handled_messages
    # Parent Router with forward AND otherwise fallback
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: OtherwiseTestChild

      forward do |messages|
        messages.with_type :resize, action: :handle_resize
      end

      action :handle_resize, -> { nil }

      otherwise route_to: :child
    end

    parent_model = Data.define(:child).new(
      child: OtherwiseTestChild::Init.call
    )
    update = parent_class.from_router

    # Create a resize message
    resize_msg = Data.define(:width, :height) do
      def resize? = true
    end.new(width: 100, height: 50)

    new_model, _cmd = update.call(resize_msg, parent_model)

    # Child should NOT have received the message (forward handled it)
    assert_equal 0, new_model.child.received_count,
      "otherwise should NOT route messages that forward already handled"
  end

  # =========================================================================
  # 🧪 TEST WRITER: Guard failure should fall through to otherwise
  # =========================================================================
  def test_otherwise_receives_message_when_guard_fails
    # Parent Router with guarded keymap AND otherwise fallback
    # When guard fails, message should fall through to otherwise
    parent_class = Class.new do
      include Rooibos::Router

      route :child, to: OtherwiseTestChild

      keymap do |map|
        # Guard always fails - message should fall through to otherwise
        map.key :q, -> { Rooibos::Command.exit }, when: -> (_model) { false }
      end

      otherwise route_to: :child
    end

    parent_model = Data.define(:child).new(
      child: OtherwiseTestChild::Init.call
    )
    update = parent_class.from_router

    # Send a message that matches keymap but guard fails
    key_message = RatatuiRuby::Event::Key.new(code: "q")
    new_model, _cmd = update.call(key_message, parent_model)

    # Child SHOULD have received the message (guard failed, fell through to otherwise)
    assert_equal 1, new_model.child.received_count,
      "otherwise should receive messages when keymap guard fails"
  end

  # =========================================================================
  # 🧪 TEST WRITER: Deep hierarchy - otherwise chains through nested fragments
  # =========================================================================
  def test_otherwise_chains_through_deep_hierarchy
    # Parent with otherwise to middle
    parent_class = Class.new do
      include Rooibos::Router

      route :middle, to: OtherwiseTestMiddle

      otherwise route_to: :middle
    end

    # Build nested model
    grandchild_model = OtherwiseTestGrandchild::Init.call
    middle_model = OtherwiseTestMiddle::Model.new(grandchild: grandchild_model)
    parent_model = Data.define(:middle).new(middle: middle_model)

    update = parent_class.from_router

    # Send an unhandled message - should chain through parent -> middle -> grandchild
    unhandled_message = :deeply_unhandled
    new_model, _cmd = update.call(unhandled_message, parent_model)

    # Grandchild should have received the message (chained through otherwise)
    assert_equal 1, new_model.middle.grandchild.received_count,
      "otherwise should chain through deep hierarchy"
  end
end
