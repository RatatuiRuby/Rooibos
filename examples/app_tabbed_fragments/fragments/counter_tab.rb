# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "rooibos"
require_relative "messages"
require_relative "panel"

# Counter tab fragment — the Seven Counters dashboard from message_routing.md.
#
# Uses Router to:
# - Route to :left_panel and :right_panel
# - intercept_all when inactive (disables input)
# - forward_routed with as: to transform envelopes (API translation)
# - intercept routed :root_increment for self-increment
# - observe resets and milestones
module CounterTab
  include Rooibos::Router

  Command = Rooibos::Command

  Model = Data.define(:left_panel, :right_panel, :count, :total_resets, :milestones, :active)

  Init = -> {
    Ractor.make_shareable Model.new(
      left_panel: Panel::Init[name: "Left", top_leaf_name: "LT", bottom_leaf_name: "LB"],
      right_panel: Panel::Init[name: "Right", top_leaf_name: "RT", bottom_leaf_name: "RB"],
      count: 0, total_resets: 0, milestones: 0, active: true
    )
  }

  View = -> (model, tui, theme: :cyan) {
    dim = model.active ? nil : tui.style(fg: :dark_gray)

    header = tui.paragraph(
      text: tui.text_span(
        content: "Root [#{model.count}] resets:#{model.total_resets} milestones:#{model.milestones}",
        style: dim
      ),
      block: tui.block(borders: [:bottom], border_style: { fg: theme })
    )

    panels = tui.layout(
      direction: :horizontal,
      constraints: [tui.constraint_fill(1), tui.constraint_fill(1)],
      children: [
        tui.block(
          title: "Left [#{model.left_panel.count}] n:#{model.left_panel.nested_resets}",
          borders: [:all],
          border_style: { fg: theme },
          children: [Panel::View.call(model.left_panel, tui, theme:)]
        ),
        tui.block(
          title: "Right [#{model.right_panel.count}] n:#{model.right_panel.nested_resets}",
          borders: [:all],
          border_style: { fg: theme },
          children: [Panel::View.call(model.right_panel, tui, theme:)]
        ),
      ]
    )

    tui.layout(
      direction: :vertical,
      constraints: [tui.constraint_length(2), tui.constraint_fill(1)],
      children: [header, panels]
    )
  }

  route :left_panel, to: Panel
  route :right_panel, to: Panel

  # Block all input when inactive (guard checks model state)
  intercept_all -> (_message, model) { [model, nil] },
    unless: -> (_message, model) { model.active }

  # Root increments itself on routed :root_increment
  receive_routed :root_increment,
    -> (_, model) {
      debug "ROOT_INCREMENT HANDLER RUNNING! count was #{model.count}"
      count = model.count + 1
      if count == 5
        model.with(count:, milestones: model.milestones + 1)
      elsif count == 10
        model.with(count: 0, total_resets: model.total_resets + 1)
      else
        model.with(count:)
      end
    }

  # Track resets bubbled from panels
  observe -> (message, _model) { message.panel_child_reset? || message.panel_reset? },
    -> (_, model) { model.with(total_resets: model.total_resets + 1) }

  # Track milestones delivered from leaves and panels
  observe_instances_of Milestone,
    -> (_, model) { model.with(milestones: model.milestones + 1) }

  # Forward routed messages by envelope to the correct panel
  # CounterTab speaks Panel's API (:leaf_1, :leaf_2, :panel_self)
  # Uses `as:` to TRANSFORM the envelope from our API to Panel's API
  route_to :left_panel do
    forward_routed :counter_1,    as: :leaf_1
    forward_routed :counter_2,    as: :leaf_2
    forward_routed :panel_left,   as: :panel_self
  end
  route_to :right_panel do
    forward_routed :counter_3,    as: :leaf_1
    forward_routed :counter_4,    as: :leaf_2
    forward_routed :panel_right,  as: :panel_self
  end

  Update = from_router
end
