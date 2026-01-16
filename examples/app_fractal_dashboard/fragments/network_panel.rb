# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "rooibos"
require_relative "ping"
require_relative "uptime"

# Composes Ping and Uptime in a horizontal layout.
module NetworkPanel
  Model = Data.define(:ping, :uptime)

  Init = -> do
    ping, = Rooibos.normalize_init(Ping::Init.())
    uptime, = Rooibos.normalize_init(Uptime::Init.())
    Model.new(ping:, uptime:)
  end

  View = -> (model, tui, disabled: false) do
    tui.layout(
      direction: :horizontal,
      constraints: [tui.constraint_percentage(50), tui.constraint_percentage(50)],
      children: [
        Ping::View.call(model.ping, tui, disabled:),
        Uptime::View.call(model.uptime, tui, disabled:),
      ]
    )
  end

  Update = -> (message, model) do
    case message
    in [:ping, *rest]
      new_child, command = Ping::Update.call(rest, model.ping)
      [model.with(ping: new_child), command]
    in [:uptime, *rest]
      new_child, command = Uptime::Update.call(rest, model.uptime)
      [model.with(uptime: new_child), command]
    else
      [model, nil]
    end
  end
end
