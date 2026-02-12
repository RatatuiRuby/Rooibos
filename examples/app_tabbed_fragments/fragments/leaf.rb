# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "rooibos"
require_relative "messages"

# Leaf fragment — a simple counter.
#
# Uses Router to:
# - intercept :increment envelope for counting
# - deliver Milestone at 5, bubble LeafReset at 10
module Leaf
  include Rooibos::Router

  Command = Rooibos::Command

  Model = Data.define(:count, :name)

  Init = -> (name:) {
    Ractor.make_shareable Model.new(count: 0, name:)
  }

  View = -> (model, tui, theme: :cyan) {
    tui.paragraph(
      text: tui.text_span(
        content: "Count: #{model.count}",
        style: tui.style(fg: theme)
      )
    )
  }

  # Increment on routed :increment
  receive_routed :increment,
    -> (_, model) {
      count = model.count + 1
      case count
      when 5
        [model.with(count:), Command.deliver(Milestone.new(envelope: model.name, count:))]
      when 10
        [model.with(count: 0), Command.bubble(LeafReset.new(envelope: model.name, count:))]
      else
        [model.with(count:), nil]
      end
    }

  Update = from_router
end
