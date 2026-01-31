# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterForward < Minitest::Test
  # Custom message type for testing
  class ResizeMessage < Data.define(:width, :height)
    include Rooibos::Message::Predicates
  end

  # Different message type for no-match tests
  class ThemeMessage < Data.define(:theme)
    include Rooibos::Message::Predicates
  end

  # Message with envelope for with_envelope tests
  class EnvelopedMessage < Data.define(:envelope, :data)
    include Rooibos::Message::Predicates
  end

  # with_type tests
  def test_forward_with_type_matches_message_type_predicate
    handler_called = false

    test_class = Class.new do
      include Rooibos::Router

      forward do |messages|
        messages.with_type :resize_message do |model, message|
          handler_called = true
          model.merge(resized: true)
        end
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ resized: false }, copy: true)

    new_model, _cmd = update.call(ResizeMessage.new(width: 800, height: 600), model)

    assert handler_called, "forward with_type should call handler when type matches"
    assert_equal true, new_model[:resized], "model should be updated by handler"
  end

  def test_forward_with_type_dispatches_to_action
    @@action_called = false

    test_class = Class.new do
      include Rooibos::Router

      action :handle_resize, -> { @@action_called = true; nil }

      forward do |messages|
        messages.with_type :resize_message, action: :handle_resize
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(ResizeMessage.new(width: 800, height: 600), model)

    assert @@action_called, "forward with_type action: should call the named action"
  end

  def test_forward_with_type_broadcast_sends_to_all_routes
    @@sidebar_called = false
    @@main_called = false

    # Child fragments
    sidebar = Module.new do
      const_set :Init, -> { { name: :sidebar } }
      const_set :Update, -> (msg, model) {
        @@sidebar_called = true if msg.resize_message?
        [model, nil]
      }
    end

    main = Module.new do
      const_set :Init, -> { { name: :main } }
      const_set :Update, -> (msg, model) {
        @@main_called = true if msg.resize_message?
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :sidebar, to: sidebar
      route :main, to: main

      forward do |messages|
        messages.with_type :resize_message, broadcast: true
      end
    end

    update = test_class.from_router
    model_class = Data.define(:sidebar, :main)
    model = model_class.new(sidebar: sidebar::Init.call, main: main::Init.call)

    update.call(ResizeMessage.new(width: 800, height: 600), model)

    assert @@sidebar_called, "broadcast: true should send to sidebar route"
    assert @@main_called, "broadcast: true should send to main route"
  end

  def test_forward_with_type_broadcast_to_sends_to_named_routes
    @@sidebar_called = false
    @@main_called = false
    @@footer_called = false

    # Child fragments
    sidebar = Module.new do
      const_set :Init, -> { { name: :sidebar } }
      const_set :Update, -> (msg, model) {
        @@sidebar_called = true if msg.resize_message?
        [model, nil]
      }
    end

    main = Module.new do
      const_set :Init, -> { { name: :main } }
      const_set :Update, -> (msg, model) {
        @@main_called = true if msg.resize_message?
        [model, nil]
      }
    end

    footer = Module.new do
      const_set :Init, -> { { name: :footer } }
      const_set :Update, -> (msg, model) {
        @@footer_called = true if msg.resize_message?
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :sidebar, to: sidebar
      route :main, to: main
      route :footer, to: footer

      forward do |messages|
        messages.with_type :resize_message, broadcast_to: [:sidebar, :main]
      end
    end

    update = test_class.from_router
    model_class = Data.define(:sidebar, :main, :footer)
    model = model_class.new(
      sidebar: sidebar::Init.call,
      main: main::Init.call,
      footer: footer::Init.call
    )

    update.call(ResizeMessage.new(width: 800, height: 600), model)

    assert @@sidebar_called, "broadcast_to: [:sidebar, :main] should send to sidebar"
    assert @@main_called, "broadcast_to: [:sidebar, :main] should send to main"
    refute @@footer_called, "broadcast_to: [:sidebar, :main] should NOT send to footer"
  end

  def test_forward_with_type_no_match_falls_through
    handler_called = false

    test_class = Class.new do
      include Rooibos::Router

      forward do |messages|
        messages.with_type :resize_message do |model, message|
          handler_called = true
          model.merge(resized: true)
        end
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ original: true }, copy: true)

    # Send a ThemeMessage, which should NOT match :resize_message
    new_model, _cmd = update.call(ThemeMessage.new(theme: :dark), model)

    refute handler_called, "handler should NOT be called for non-matching type"
    assert_equal true, new_model[:original], "model should be unchanged"
  end

  # with_envelope tests
  def test_forward_with_envelope_matches_message_envelope
    @@handler_called = false

    test_class = Class.new do
      include Rooibos::Router

      forward do |messages|
        messages.with_envelope :file_list do |model, message|
          @@handler_called = true
          model.merge(handled: true)
        end
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ handled: false }, copy: true)

    new_model, _cmd = update.call(EnvelopedMessage.new(envelope: :file_list, data: "test"), model)

    assert @@handler_called, "with_envelope should call handler when envelope matches"
    assert_equal true, new_model[:handled], "model should be updated by handler"
  end

  def test_forward_with_envelope_routes_to_fragment
    @@fragment_called = false

    file_list = Module.new do
      const_set :Init, -> { { name: :file_list } }
      const_set :Update, -> (msg, model) {
        @@fragment_called = true if msg.enveloped_message?
        [model.merge(received: true), nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :file_list, to: file_list

      forward do |messages|
        messages.with_envelope :file_list, route_to: :file_list
      end
    end

    update = test_class.from_router
    model_class = Data.define(:file_list)
    model = model_class.new(file_list: file_list::Init.call)

    new_model, _cmd = update.call(EnvelopedMessage.new(envelope: :file_list, data: "test"), model)

    assert @@fragment_called, "route_to: should forward message to fragment"
    assert_equal true, new_model.file_list[:received], "fragment model should be updated"
  end

  def test_forward_with_envelope_no_match_falls_through
    handler_called = false

    test_class = Class.new do
      include Rooibos::Router

      forward do |messages|
        messages.with_envelope :sidebar do |model, message|
          handler_called = true
          model
        end
      end
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ original: true }, copy: true)

    # Send message with different envelope
    new_model, _cmd = update.call(EnvelopedMessage.new(envelope: :file_list, data: "test"), model)

    refute handler_called, "handler should NOT be called for non-matching envelope"
    assert_equal true, new_model[:original], "model should be unchanged"
  end
end
