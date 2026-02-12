# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "rooibos"
require_relative "messages"
require_relative "leaf"

# Panel fragment containing two leaves.
#
# Uses Router to:
# - route to :top_leaf and :bottom_leaf
# - forward_routed by envelope (:leaf_1 -> top, :leaf_2 -> bottom, :panel_self -> self)
# - intercept to transform LeafReset -> PanelChildReset
# - receive :panel_self for self-increment
module Panel
  include Rooibos::Router

  Command = Rooibos::Command

  Model = Data.define(:top_leaf, :bottom_leaf, :count, :nested_resets, :name)

  Init = -> (name:, top_leaf_name:, bottom_leaf_name:) {
    Ractor.make_shareable Model.new(
      top_leaf: Leaf::Init[name: top_leaf_name],
      bottom_leaf: Leaf::Init[name: bottom_leaf_name],
      count: 0, nested_resets: 0, name:
    )
  }

  View = -> (model, tui, theme: :cyan) {
    tui.layout(
      direction: :vertical,
      constraints: [tui.constraint_fill(1), tui.constraint_fill(1)],
      children: [
        tui.block(
          title: "#{model.top_leaf.name} [#{model.top_leaf.count}]",
          borders: [:all],
          border_style: { fg: theme },
          children: [Leaf::View.call(model.top_leaf, tui, theme:)]
        ),
        tui.block(
          title: "#{model.bottom_leaf.name} [#{model.bottom_leaf.count}]",
          borders: [:all],
          border_style: { fg: theme },
          children: [Leaf::View.call(model.bottom_leaf, tui, theme:)]
        ),
      ]
    )
  }

  route :top_leaf, to: Leaf
  route :bottom_leaf, to: Leaf

  # Self-increment on :panel_self
  receive_routed :panel_self,
    -> (_, model) {
      count = model.count + 1
      case count
      when 5
        [model.with(count:), Command.deliver(Milestone.new(envelope: model.name, count:))]
      when 10
        [
          model.with(count: 0, nested_resets: model.nested_resets + 1),
          Command.bubble(PanelReset.new(envelope: model.name, count:)),
        ]
      else
        [model.with(count:), nil]
      end
    }

  # Intercept LeafReset, transform to PanelChildReset, and re-bubble
  # This demonstrates semantic transformation pattern
  intercept_instances_of LeafReset,
    -> (message, model) {
      transformed = PanelChildReset.new(
        envelope: model.name,
        leaf: message.envelope,
        count: message.count
      )
      [model.with(nested_resets: model.nested_resets + 1), Command.bubble(transformed)]
    }

  # Forward by Panel's API (:leaf_1, :leaf_2) to internal routes
  # Each leaf just receives :increment as its envelope
  forward_routed :leaf_1, to: :top_leaf, as: :increment
  forward_routed :leaf_2, to: :bottom_leaf, as: :increment

  Update = from_router
end
