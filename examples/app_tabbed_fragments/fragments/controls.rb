# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

# Controls display fragment — stateless view component.
#
# Receives active_tab from parent and renders appropriate keybinds.
module Controls
  COUNTER_BINDS = [
    ["1-4", "Leaves"],
    ["a/b", "Panels"],
    ["Enter", "Root"],
  ].freeze

  COLOR_BINDS = [
    ["1-6", "Color"],
    ["Enter", "Random"],
  ].freeze

  COMMON_BINDS = [
    ["[/]", "Switch"],
    ["t", "Theme"],
    ["q", "Quit"],
  ].freeze

  View = -> (active_tab, tui, theme: :cyan) {
    binds = case active_tab
            when :counter then COUNTER_BINDS + COMMON_BINDS
            when :color then COLOR_BINDS + COMMON_BINDS
            else COMMON_BINDS
    end

    spans = binds.flat_map do |key, label|
      [
        tui.text_span(content: key, style: tui.style(modifiers: [:bold, :underlined])),
        tui.text_span(content: ":#{label}  "),
      ]
    end

    tui.paragraph(
      text: [tui.text_line(spans:)],
      block: tui.block(
        title: "Controls",
        borders: [:all],
        border_style: { fg: theme }
      )
    )
  }
end
