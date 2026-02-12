# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "rooibos"
require_relative "messages"

# Color tab fragment with 8 ANSI colors.
#
# Uses Router to:
# - intercept_all when inactive
# - receive_routed for color selection (1-8) and random
# - Command.bubble when selecting a color
module ColorTab
  include Rooibos::Router

  Command = Rooibos::Command

  COLORS = %i[red green yellow blue magenta cyan].freeze

  Model = Data.define(:selected_index, :active)

  Init = -> {
    Ractor.make_shareable Model.new(
      selected_index: 0,
      active: true
    )
  }

  View = -> (model, tui, theme: :cyan) {
    dim = model.active ? nil : tui.style(fg: :dark_gray)

    items = COLORS.each_with_index.map do |color, i|
      style = model.active ? tui.style(fg: color) : dim
      tui.list_item(content: "#{i + 1}. #{color}", style:)
    end

    tui.list(
      items:,
      selected_index: model.selected_index,
      highlight_style: tui.style(modifiers: [:bold, :reversed]),
      highlight_symbol: "▶ ",
      block: tui.block(
        title: "Colors [#{COLORS[model.selected_index]}]",
        borders: [:all],
        border_style: { fg: theme }
      )
    )
  }

  # Block all input when inactive
  intercept_all -> (_, model) { [model, nil] },
    unless: -> (_, model) { model.active }

  # Select color 1-8
  COLORS.each_with_index do |color, i|
    receive_routed :"color_#{i + 1}",
      -> (_, model) {
        [
          model.with(selected_index: i),
          Command.bubble(ColorChanged.new(color_name: color.to_s, hex: color.to_s)),
        ]
      }
  end

  # Random color on Enter
  receive_routed :random_color,
    -> (_, model) {
      i = rand(COLORS.size)
      [
        model.with(selected_index: i),
        Command.bubble(ColorChanged.new(color_name: COLORS[i].to_s, hex: COLORS[i].to_s)),
      ]
    }

  Update = from_router
end
