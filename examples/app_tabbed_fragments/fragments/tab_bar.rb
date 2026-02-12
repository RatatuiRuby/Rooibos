# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "rooibos"
require_relative "messages"

# Tab bar fragment with mouse support.
#
# Uses Router to:
# - intercept for Tab/Shift+Tab navigation (needs model access)
# - intercept for click-to-select tabs
# - Bubbles TabSelected when tab changes
module TabBar
  include Rooibos::Router

  Command = Rooibos::Command

  TABS = [:counter, :color].freeze
  TAB_LABELS = { counter: " Counters ", color: " Colors " }.freeze

  Model = Data.define(:selected_index, :message_count)

  Init = -> {
    Ractor.make_shareable Model.new(selected_index: 0, message_count: 0)
  }

  View = -> (model, tui, theme: :cyan) {
    titles = TABS.map.with_index do |tab, i|
      label = TAB_LABELS[tab]
      if i == model.selected_index
        tui.text_line(spans: [tui.text_span(content: label, style: tui.style(modifiers: [:bold]))])
      else
        tui.text_line(spans: [tui.text_span(content: label)])
      end
    end

    tui.tabs(
      titles:,
      selected_index: model.selected_index,
      highlight_style: tui.style(fg: theme, modifiers: [:bold, :reversed]),
      block: tui.block(
        title: "Messages: #{model.message_count}",
        borders: [:all],
        border_style: { fg: theme }
      )
    )
  }

  # Tab navigation with bracket keys
  receive_events :"[",
    -> (_, model) {
      new_index = (model.selected_index - 1) % TABS.size
      [model.with(selected_index: new_index), Command.bubble(TabSelected.new(tab: TABS[new_index]))]
    }
  receive_events :"]",
    -> (_, model) {
      new_index = (model.selected_index + 1) % TABS.size
      [model.with(selected_index: new_index), Command.bubble(TabSelected.new(tab: TABS[new_index]))]
    }

  # Mouse click to select tab
  receive_events :mouse_left_down,
    -> (message, model) {
      # Account for block border (1 char) and rough tab widths
      tab_index = (message.x < 14) ? 0 : 1
      tab_index = [tab_index, TABS.size - 1].min

      return [model, nil] if tab_index == model.selected_index

      [model.with(selected_index: tab_index), Command.bubble(TabSelected.new(tab: TABS[tab_index]))]
    }

  Update = from_router
end
