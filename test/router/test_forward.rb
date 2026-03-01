# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterForward < Minitest::Test
  class ResizeMessage < Data.define(:width, :height)
    include Rooibos::Message::Predicates
  end

  class ThemeMessage < Data.define(:theme)
    include Rooibos::Message::Predicates
  end

  class EnvelopedMessage < Data.define(:envelope, :data)
    include Rooibos::Message::Predicates
  end

  module TrackingChild
    Model = Data.define(:received_messages, :last_envelope)
    Init = -> { Model.new(received_messages: [], last_envelope: nil) }
    Update = -> (msg, model) {
      envelope = msg.routed? ? msg.envelope : nil
      [
        model.with(
          received_messages: model.received_messages + [msg],
          last_envelope: envelope || model.last_envelope
        ),
        nil,
]
    }
  end

  def test_forward_instances_of_matches_message_class
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_instances_of TestRouterForward::ResizeMessage, to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(ResizeMessage.new(width: 800, height: 600), model)

    assert_equal 1, new_model.child.received_messages.size
  end

  def test_forward_instances_of_does_not_match_other_types
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_instances_of TestRouterForward::ResizeMessage, to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(ThemeMessage.new(theme: :dark), model)

    assert_equal 0, new_model.child.received_messages.size
  end

  def test_forward_instances_of_with_as_transforms_envelope
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_instances_of TestRouterForward::ResizeMessage, to: :child, as: :layout_resize
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(ResizeMessage.new(width: 800, height: 600), model)

    assert_equal :layout_resize, new_model.child.last_envelope
  end

  def test_forward_instances_of_to_captured_route
    captured_route = nil
    test_class = Class.new do
      include Rooibos::Router

      captured_route = route :child, to: TestRouterForward::TrackingChild

      forward_instances_of TestRouterForward::ResizeMessage, to: captured_route
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(ResizeMessage.new(width: 800, height: 600), model)

    assert_equal 1, new_model.child.received_messages.size,
      "forward_instances_of to: Route should resolve the captured route"
  end

  def test_forward_events_matches_key_event
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_events :enter, to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert_equal 1, new_model.child.received_messages.size
  end

  def test_forward_events_with_as_sets_envelope
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_events :enter, to: :child, as: :submit
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert_equal :submit, new_model.child.last_envelope
  end

  def test_forward_events_does_not_match_other_keys
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_events :enter, to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal 0, new_model.child.received_messages.size
  end

  def test_forward_events_to_fragment_module
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_events :enter, to: TestRouterForward::TrackingChild
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert_equal 1, new_model.child.received_messages.size,
      "forward_events to: Module should resolve the route by fragment"
  end

  def test_forward_routed_matches_envelope
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_routed :submit, to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    routed_msg = Rooibos::Message::Routed.new(
      envelope: :submit,
      event: RatatuiRuby::Event::Key.new(code: "enter")
    )

    new_model, _cmd = update.call(routed_msg, model)

    assert_equal 1, new_model.child.received_messages.size
  end

  def test_forward_routed_with_as_transforms_envelope
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_routed :outer_submit, to: :child, as: :inner_submit
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    routed_msg = Rooibos::Message::Routed.new(
      envelope: :outer_submit,
      event: RatatuiRuby::Event::Key.new(code: "enter")
    )

    new_model, _cmd = update.call(routed_msg, model)

    assert_equal :inner_submit, new_model.child.last_envelope
  end

  def test_forward_instances_of_broadcast_sends_to_all_routes
    sidebar_count = 0
    main_count = 0

    sidebar = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        sidebar_count += 1 if msg.is_a?(TestRouterForward::ResizeMessage) || msg.routed?
        [model, nil]
      }
    end

    main = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        main_count += 1 if msg.is_a?(TestRouterForward::ResizeMessage) || msg.routed?
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :sidebar, to: sidebar
      route :main, to: main

      forward_instances_of TestRouterForward::ResizeMessage, broadcast: true
    end

    update = test_class.from_router
    model_class = Data.define(:sidebar, :main)
    model = model_class.new(sidebar: sidebar::Init.call, main: main::Init.call)

    update.call(ResizeMessage.new(width: 800, height: 600), model)

    assert_equal 1, sidebar_count, "broadcast should send to sidebar"
    assert_equal 1, main_count, "broadcast should send to main"
  end

  def test_forward_instances_of_broadcast_to_sends_to_named_routes
    sidebar_count = 0
    main_count = 0
    footer_count = 0

    sidebar = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        sidebar_count += 1
        [model, nil]
      }
    end

    main = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        main_count += 1
        [model, nil]
      }
    end

    footer = Module.new do
      const_set :Model, Data.define(:x)
      const_set :Init, -> { self::Model.new(x: 0) }
      const_set :Update, -> (msg, model) {
        footer_count += 1
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :sidebar, to: sidebar
      route :main, to: main
      route :footer, to: footer

      forward_instances_of TestRouterForward::ResizeMessage,
        broadcast_to: [:sidebar, :main] # Not footer
    end

    update = test_class.from_router
    model_class = Data.define(:sidebar, :main, :footer)
    model = model_class.new(
      sidebar: sidebar::Init.call,
      main: main::Init.call,
      footer: footer::Init.call
    )

    update.call(ResizeMessage.new(width: 800, height: 600), model)

    assert_equal 1, sidebar_count
    assert_equal 1, main_count
    assert_equal 0, footer_count, "footer should NOT receive (not in broadcast_to)"
  end

  def test_forward_with_predicate_matches_on_true
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward -> (msg, _model) { msg.key? && msg.ctrl? }, to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(
      RatatuiRuby::Event::Key.new(code: "c", modifiers: ["ctrl"]),
      model
    )

    assert_equal 1, new_model.child.received_messages.size
  end

  def test_forward_with_predicate_skips_on_false
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward -> (msg, _model) { msg.key? && msg.ctrl? }, to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "c"), model)

    assert_equal 0, new_model.child.received_messages.size
  end

  def test_forward_events_with_guard
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_events :enter, to: :child,
        when: -> (_msg, model) { model.active }
    end

    update = test_class.from_router
    model_class = Data.define(:child, :active)

    inactive = model_class.new(child: TrackingChild::Init.call, active: false)
    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), inactive)
    assert_equal 0, new_model.child.received_messages.size

    active = model_class.new(child: TrackingChild::Init.call, active: true)
    new_model2, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), active)
    assert_equal 1, new_model2.child.received_messages.size
  end

  def test_forward_instances_of_preserves_message_attribute_values
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_instances_of TestRouterForward::ResizeMessage, to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(ResizeMessage.new(width: 1920, height: 1080), model)

    received = new_model.child.received_messages.first
    assert_equal 1920, received.width, "message width must be preserved"
    assert_equal 1080, received.height, "message height must be preserved"
  end

  def test_forward_instances_of_forwards_exact_message_instance
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_instances_of TestRouterForward::ResizeMessage, to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    original_message = ResizeMessage.new(width: 800, height: 600)
    new_model, _cmd = update.call(original_message, model)

    received = new_model.child.received_messages.first
    assert_same original_message, received, "exact message instance must be forwarded"
  end

  def test_forward_events_array_preserves_each_events_content
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_events [:left, :right], to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    left_event = RatatuiRuby::Event::Key.new(code: "left")
    right_event = RatatuiRuby::Event::Key.new(code: "right")

    new_model, _cmd = update.call(left_event, model)
    new_model, _cmd = update.call(right_event, new_model)

    received = new_model.child.received_messages
    assert_equal "left", received[0].code, "first event code must be preserved"
    assert_equal "right", received[1].code, "second event code must be preserved"
  end

  def test_forward_events_with_as_preserves_original_event_inside_routed
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_events :enter, to: :child, as: :submit
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    enter_event = RatatuiRuby::Event::Key.new(code: "enter")
    new_model, _cmd = update.call(enter_event, model)

    received = new_model.child.received_messages.first
    assert received.routed?, "message must be routed"
    assert_equal :submit, received.envelope
    assert_same enter_event, received.event, "original event must be preserved inside Routed"
  end

  def test_forward_routed_with_as_transforms_envelope_preserving_original_event
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_routed :inner, to: :child, as: :outer
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    original_event = RatatuiRuby::Event::Key.new(code: "tab")
    inner_routed = Rooibos::Message::Routed.new(envelope: :inner, event: original_event)
    new_model, _cmd = update.call(inner_routed, model)

    received = new_model.child.received_messages.first
    assert received.routed?, "message must be routed"
    assert_equal :outer, received.envelope
    assert_same original_event, received.event, "original event must be preserved (not double-wrapped)"
  end

  def test_forward_events_with_empty_array_matches_nothing
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_events [], to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert_equal 0, new_model.child.received_messages.size, "empty array should match nothing"
  end

  def test_forward_events_with_duplicate_keys_in_array_forwards_once
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForward::TrackingChild

      forward_events [:enter, :enter, :enter], to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert_equal 1, new_model.child.received_messages.size, "duplicates should forward once"
  end
end
