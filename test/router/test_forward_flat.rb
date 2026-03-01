# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterForwardFlat < Minitest::Test
  module TrackingChild
    Model = Data.define(:received_messages)
    Init = -> { Model.new(received_messages: []) }
    Update = -> (msg, model) {
      [model.with(received_messages: model.received_messages + [msg]), nil]
    }
  end

  module CounterChild
    Model = Data.define(:count)
    Init = -> { Model.new(count: 0) }
    Update = -> (msg, model) {
      if msg.routed? && msg.envelope == :increment
        model.with(count: model.count + 1)
      else
        model
      end
    }
  end

  def test_forward_events_routes_to_named_fragment
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForwardFlat::TrackingChild

      forward_events :enter, to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert_equal 1, new_model.child.received_messages.size
    refute new_model.child.received_messages.first.routed?,
      "without as:, forward_events passes the raw event (not wrapped in Routed)"
  end

  def test_forward_events_with_as_transforms_envelope
    test_class = Class.new do
      include Rooibos::Router

      route :counter, to: TestRouterForwardFlat::CounterChild

      forward_events :enter, to: :counter, as: :increment
    end

    update = test_class.from_router
    model_class = Data.define(:counter)
    model = model_class.new(counter: CounterChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert_equal 1, new_model.counter.count, "as: should transform event to :increment envelope"
  end

  def test_forward_events_with_multiple_keys
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForwardFlat::TrackingChild

      forward_events [:up, :k], to: :child, as: :move_up
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "k"), model)
    assert_equal 1, new_model.child.received_messages.size

    new_model2, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "up"), new_model)
    assert_equal 2, new_model2.child.received_messages.size
  end

  def test_forward_events_broadcast_to_sends_to_named_routes
    @@left_received = false
    @@right_received = false

    left = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :left) }
      const_set :Update, -> (msg, model) {
        @@left_received = true
        [model, nil]
      }
    end

    right = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :right) }
      const_set :Update, -> (msg, model) {
        @@right_received = true
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :left, to: left
      route :right, to: right

      forward_events :enter, broadcast_to: [:left, :right], as: :submit
    end

    update = test_class.from_router
    model_class = Data.define(:left, :right)
    model = model_class.new(left: left::Init.call, right: right::Init.call)

    update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert @@left_received, "broadcast_to: should send to left"
    assert @@right_received, "broadcast_to: should send to right"
  end

  def test_forward_routed_routes_by_envelope
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForwardFlat::TrackingChild

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

      route :counter, to: TestRouterForwardFlat::CounterChild

      forward_routed :counter_1, to: :counter, as: :increment
    end

    update = test_class.from_router
    model_class = Data.define(:counter)
    model = model_class.new(counter: CounterChild::Init.call)

    routed_msg = Rooibos::Message::Routed.new(
      envelope: :counter_1,
      event: RatatuiRuby::Event::Key.new(code: "1")
    )

    new_model, _cmd = update.call(routed_msg, model)

    assert_equal 1, new_model.counter.count, "as: should transform :counter_1 to :increment"
  end

  def test_forward_routed_broadcast_true_sends_to_all
    @@left_received = false
    @@right_received = false

    left = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :left) }
      const_set :Update, -> (msg, model) {
        @@left_received = true if msg.routed? && msg.envelope == :clock
        [model, nil]
      }
    end

    right = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :right) }
      const_set :Update, -> (msg, model) {
        @@right_received = true if msg.routed? && msg.envelope == :clock
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :left, to: left
      route :right, to: right

      forward_routed :clock, broadcast: true
    end

    update = test_class.from_router
    model_class = Data.define(:left, :right)
    model = model_class.new(left: left::Init.call, right: right::Init.call)

    routed_msg = Rooibos::Message::Routed.new(
      envelope: :clock,
      event: :tick
    )
    update.call(routed_msg, model)

    assert @@left_received, "broadcast: true should send :clock to left"
    assert @@right_received, "broadcast: true should send :clock to right"
  end

  class ResizeEvent < Data.define(:width, :height)
    include Rooibos::Message::Predicates
  end

  class ThemeChanged < Data.define(:theme)
    include Rooibos::Message::Predicates
  end

  def test_forward_instances_of_routes_by_class
    test_class = Class.new do
      include Rooibos::Router

      route :layout, to: TestRouterForwardFlat::TrackingChild

      forward_instances_of TestRouterForwardFlat::ResizeEvent, to: :layout
    end

    update = test_class.from_router
    model_class = Data.define(:layout)
    model = model_class.new(layout: TrackingChild::Init.call)

    resize = ResizeEvent.new(width: 800, height: 600)
    new_model, _cmd = update.call(resize, model)

    assert_equal 1, new_model.layout.received_messages.size
    assert_equal resize, new_model.layout.received_messages.first
  end

  def test_forward_instances_of_broadcast_true_sends_to_all
    @@sidebar_received = false
    @@main_received = false

    sidebar = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :sidebar) }
      const_set :Update, -> (msg, model) {
        @@sidebar_received = true if msg.is_a?(TestRouterForwardFlat::ResizeEvent)
        [model, nil]
      }
    end

    main = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :main) }
      const_set :Update, -> (msg, model) {
        @@main_received = true if msg.is_a?(TestRouterForwardFlat::ResizeEvent)
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :sidebar, to: sidebar
      route :main, to: main

      forward_instances_of TestRouterForwardFlat::ResizeEvent, broadcast: true
    end

    update = test_class.from_router
    model_class = Data.define(:sidebar, :main)
    model = model_class.new(sidebar: sidebar::Init.call, main: main::Init.call)

    update.call(ResizeEvent.new(width: 800, height: 600), model)

    assert @@sidebar_received, "broadcast: true should send to sidebar"
    assert @@main_received, "broadcast: true should send to main"
  end

  def test_forward_instances_of_broadcast_to_sends_to_named_routes
    @@sidebar_received = false
    @@main_received = false
    @@footer_received = false

    sidebar = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :sidebar) }
      const_set :Update, -> (msg, model) {
        @@sidebar_received = true if msg.is_a?(TestRouterForwardFlat::ThemeChanged)
        [model, nil]
      }
    end

    main = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :main) }
      const_set :Update, -> (msg, model) {
        @@main_received = true if msg.is_a?(TestRouterForwardFlat::ThemeChanged)
        [model, nil]
      }
    end

    footer = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :footer) }
      const_set :Update, -> (msg, model) {
        @@footer_received = true if msg.is_a?(TestRouterForwardFlat::ThemeChanged)
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :sidebar, to: sidebar
      route :main, to: main
      route :footer, to: footer

      forward_instances_of TestRouterForwardFlat::ThemeChanged, broadcast_to: [:sidebar, :main]
    end

    update = test_class.from_router
    model_class = Data.define(:sidebar, :main, :footer)
    model = model_class.new(
      sidebar: sidebar::Init.call,
      main: main::Init.call,
      footer: footer::Init.call
    )

    update.call(ThemeChanged.new(theme: :dark), model)

    assert @@sidebar_received
    assert @@main_received
    refute @@footer_received, "broadcast_to: should NOT send to footer"
  end

  def test_forward_instances_of_broadcast_true_with_as_wraps_in_routed
    @@sidebar_envelope = nil
    @@main_envelope = nil

    sidebar = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :sidebar) }
      const_set :Update, -> (msg, model) {
        @@sidebar_envelope = msg.envelope if msg.routed?
        [model, nil]
      }
    end

    main = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :main) }
      const_set :Update, -> (msg, model) {
        @@main_envelope = msg.envelope if msg.routed?
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :sidebar, to: sidebar
      route :main, to: main

      forward_instances_of TestRouterForwardFlat::ResizeEvent, broadcast: true, as: :layout_changed
    end

    update = test_class.from_router
    model_class = Data.define(:sidebar, :main)
    model = model_class.new(sidebar: sidebar::Init.call, main: main::Init.call)

    update.call(ResizeEvent.new(width: 800, height: 600), model)

    assert_equal :layout_changed, @@sidebar_envelope,
      "broadcast: true with as: should wrap in Routed with :layout_changed envelope for sidebar"
    assert_equal :layout_changed, @@main_envelope,
      "broadcast: true with as: should wrap in Routed with :layout_changed envelope for main"
  end

  def test_forward_instances_of_broadcast_to_with_as_wraps_in_routed
    @@sidebar_envelope = nil
    @@main_envelope = nil
    @@footer_received_routed = false

    sidebar = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :sidebar) }
      const_set :Update, -> (msg, model) {
        @@sidebar_envelope = msg.envelope if msg.routed?
        [model, nil]
      }
    end

    main = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :main) }
      const_set :Update, -> (msg, model) {
        @@main_envelope = msg.envelope if msg.routed?
        [model, nil]
      }
    end

    footer = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :footer) }
      const_set :Update, -> (msg, model) {
        @@footer_received_routed = true if msg.routed?
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :sidebar, to: sidebar
      route :main, to: main
      route :footer, to: footer

      forward_instances_of TestRouterForwardFlat::ThemeChanged, broadcast_to: [:sidebar, :main], as: :retheme
    end

    update = test_class.from_router
    model_class = Data.define(:sidebar, :main, :footer)
    model = model_class.new(
      sidebar: sidebar::Init.call,
      main: main::Init.call,
      footer: footer::Init.call
    )

    update.call(ThemeChanged.new(theme: :dark), model)

    assert_equal :retheme, @@sidebar_envelope,
      "broadcast_to: with as: should wrap in Routed with :retheme for sidebar"
    assert_equal :retheme, @@main_envelope,
      "broadcast_to: with as: should wrap in Routed with :retheme for main"
    refute @@footer_received_routed,
      "broadcast_to: should NOT send to footer"
  end

  def test_forward_all_routes_all_messages
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForwardFlat::TrackingChild

      forward_all to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), model)

    assert_equal 1, new_model.child.received_messages.size
  end

  def test_forward_all_with_guard
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForwardFlat::TrackingChild

      forward_all to: :child, when: -> (_msg, model) { model.active }
    end

    update = test_class.from_router
    model_class = Data.define(:child, :active)
    model = model_class.new(child: TrackingChild::Init.call, active: false)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), model)
    assert_equal 0, new_model.child.received_messages.size

    active_model = model.with(active: true)
    new_model2, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), active_model)
    assert_equal 1, new_model2.child.received_messages.size
  end

  def test_forward_with_predicate_lambda
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterForwardFlat::TrackingChild

      forward -> (msg, _) { msg.key? && msg.ctrl? }, to: :child
    end

    update = test_class.from_router
    model_class = Data.define(:child)
    model = model_class.new(child: TrackingChild::Init.call)

    new_model, _cmd = update.call(
      RatatuiRuby::Event::Key.new(code: "c", modifiers: ["ctrl"]),
      model
    )
    assert_equal 1, new_model.child.received_messages.size

    new_model2, _cmd = update.call(
      RatatuiRuby::Event::Key.new(code: "c"),
      new_model
    )
    assert_equal 1, new_model2.child.received_messages.size
  end

  def test_forward_with_predicate_broadcast_to_sends_to_named_routes
    @@left_received = false
    @@right_received = false

    left = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :left) }
      const_set :Update, -> (msg, model) {
        @@left_received = true
        [model, nil]
      }
    end

    right = Module.new do
      const_set :Model, Data.define(:name)
      const_set :Init, -> { self::Model.new(name: :right) }
      const_set :Update, -> (msg, model) {
        @@right_received = true
        [model, nil]
      }
    end

    test_class = Class.new do
      include Rooibos::Router

      route :left, to: left
      route :right, to: right

      forward -> (msg, _) { msg.theme_changed? }, broadcast_to: [:left, :right]
    end

    update = test_class.from_router
    model_class = Data.define(:left, :right)
    model = model_class.new(left: left::Init.call, right: right::Init.call)

    msg = TestRouterForwardFlat::ThemeChanged.new(theme: :dark)
    update.call(msg, model)

    assert @@left_received, "broadcast_to: should send to left"
    assert @@right_received, "broadcast_to: should send to right"
  end

  def test_route_to_block_scopes_destination
    test_class = Class.new do
      include Rooibos::Router

      route :counter, to: TestRouterForwardFlat::CounterChild

      route_to :counter do
        forward_events :enter, as: :increment
        forward_events :space, as: :increment
      end
    end

    update = test_class.from_router
    model_class = Data.define(:counter)
    model = model_class.new(counter: CounterChild::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)
    assert_equal 1, new_model.counter.count

    new_model2, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "space"), new_model)
    assert_equal 2, new_model2.counter.count
  end
end
