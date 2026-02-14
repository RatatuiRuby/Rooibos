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
    # Key events forwarded from Router as semantic routed messages
    in { type: :routed, envelope: :fetch_ping }
      new_model = model.with(ping: model.ping.with(loading: true))
      [new_model, Ping.fetch_command]

    in { type: :routed, envelope: :fetch_uptime }
      new_model = model.with(uptime: model.uptime.with(loading: true))
      [new_model, Uptime.fetch_command]

    # Async command results forwarded from Router
    in { type: :system, envelope: :ping }
      new_child, command = Ping::Update.call(message, model.ping)
      [model.with(ping: new_child), command]

    in { type: :system, envelope: :uptime }
      new_child, command = Uptime::Update.call(message, model.uptime)
      [model.with(uptime: new_child), command]

    else
      [model, nil]
    end
  end
end
