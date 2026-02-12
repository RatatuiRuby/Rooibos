# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "rooibos"
require_relative "messages"
require_relative "tab_bar"
require_relative "counter_tab"
require_relative "color_tab"
require_relative "controls"

DEBUG_LOG = File.open("/tmp/tabbed_debug.log", "a")
def debug(msg)
  DEBUG_LOG.puts("[#{Time.now}] #{msg}")
  DEBUG_LOG.flush
end

# Root app fragment with tab navigation.
#
# Uses Router to demonstrate:
# - route (basic routes to TabBar and tab content)
# - action (named handlers for quit)
# - intercept (theme cycling with model access)
# - keymap with guards for conditional tab-based routing
# - keymap with action: + route: for semantic envelope routing
# - forward broadcast: for resize
# - observe_all for message counting
# - observe for tab selection and color changes
# - otherwise for routing to active tab
module App
  include Rooibos::Router

  Command = Rooibos::Command

  THEMES = %i[cyan green magenta yellow].freeze

  Model = Data.define(:counter_tab, :color_tab, :tab_bar, :active_tab, :theme, :message_count)

  Init = -> {
    Ractor.make_shareable Model.new(
      counter_tab: CounterTab::Init.call,
      color_tab: ColorTab::Init.call,
      tab_bar: TabBar::Init.call,
      active_tab: :counter,
      theme: :cyan,
      message_count: 0
    )
  }

  View = -> (model, tui) {
    theme = model.theme

    tab_bar_view = TabBar::View.call(model.tab_bar, tui, theme:)

    # Active tab content
    active_tab_view = case model.active_tab
    when :counter
      CounterTab::View.call(model.counter_tab, tui, theme:)
    when :color
      ColorTab::View.call(model.color_tab, tui, theme:)
    end

    # Controls for active tab
    controls_view = Controls::View.call(model.active_tab, tui, theme:)

    tui.layout(
      direction: :vertical,
      constraints: [
        tui.constraint_length(3),  # Tab bar
        tui.constraint_fill(1),    # Content
        tui.constraint_length(3),  # Controls
      ],
      children: [tab_bar_view, active_tab_view, controls_view]
    )
  }

  route :tab_bar, to: TabBar
  route :counter_tab, to: CounterTab
  route :color_tab, to: ColorTab

  # Guards for conditional routing
  COUNTER_ACTIVE = -> (_message, model) { model.active_tab == :counter }
  COLOR_ACTIVE = -> (_message, model) { model.active_tab == :color }

  # Named action for quit
  action :quit, -> { Command.exit }

  # Theme cycling - intercept 't' key
  intercept_events :t,
    -> (_, model) {
      current_idx = THEMES.index(model.theme) || 0
      new_theme = THEMES[(current_idx + 1) % THEMES.size]
      model.with(theme: new_theme) # TODO: Was bubbling ThemeChanged, but this is Root
    }

  # Apply theme from child bubbles
  observe_instances_of ThemeChanged,
    -> (message, model) { model.with(theme: message.theme) }

  # Count all messages
  observe_all -> (message, model) {
    debug "MSG: #{message.class} #{message.inspect[0..100]}"
    new_count = model.message_count + 1
    new_tab_bar = model.tab_bar.with(message_count: new_count)
    [model.with(message_count: new_count, tab_bar: new_tab_bar), nil]
  }

  # Handle tab selection from TabBar
  observe_instances_of TabSelected,
    -> (message, model) {
      new_tab = message.tab
      return model if new_tab == model.active_tab

      counter_model = model.counter_tab.with(active: new_tab == :counter)
      color_model = model.color_tab.with(active: new_tab == :color)

      model.with(
        counter_tab: counter_model,
        color_tab: color_model,
        active_tab: new_tab
      )
    }

  # Global key bindings
  intercept_events :ctrl_c, :quit
  intercept_events :q, :quit

  # Counter tab keys - forward to child with envelope transformation
  only when: COUNTER_ACTIVE do
    route_to :counter_tab do
      forward_events :"1",   as: :counter_1
      forward_events :"2",   as: :counter_2
      forward_events :"3",   as: :counter_3
      forward_events :"4",   as: :counter_4
      forward_events :a,     as: :panel_left
      forward_events :b,     as: :panel_right
      forward_events :enter, as: :root_increment
    end
  end

  # Color tab keys
  only when: COLOR_ACTIVE do
    route_to :color_tab do
      forward_events :"1", as: :color_1
      forward_events :"2", as: :color_2
      forward_events :"3", as: :color_3
      forward_events :"4", as: :color_4
      forward_events :"5", as: :color_5
      forward_events :"6", as: :color_6
      forward_events :enter, as: :random_color
    end
  end

  # Broadcast resize to all child routes
  forward_instances_of RatatuiRuby::Event::Resize, broadcast: true

  # Route unhandled messages to tab_bar (for Tab key)
  otherwise route_to: :tab_bar

  Update = from_router
end
