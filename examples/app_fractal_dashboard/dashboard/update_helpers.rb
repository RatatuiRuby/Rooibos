# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require_relative "base"

# UPDATE using Rooibos.route and Rooibos.delegate helpers.
#
# This is the medium-verbosity approach: routing helpers reduce boilerplate
# while keeping the case statement visible. A good middle ground.
module DashboardHelpers
  Command = Rooibos::Command
  # Alias for readability

  # Shared with other UPDATE variants
  Model = DashboardBase::Model
  Init = DashboardBase::Init
  View = DashboardBase::View

  Update = -> (message, model) do
    # Global Force Quit
    return [model, Rooibos::Command.exit] if message.respond_to?(:ctrl_c?) && message.ctrl_c?

    # IMPORTANT: Route command results BEFORE modal intercept.
    # Async command results must always reach their destination, even when a
    # modal is active. Only user input (keys/mouse) should be blocked.

    # Route streaming command output to modal
    if (result = Rooibos.delegate(message, :shell_output, CustomShellModal::Update, model.shell_modal))
      new_modal, command = result
      return [model.with(shell_modal: new_modal), command]
    end

    # Route to child fragments
    if (result = Rooibos.delegate(message, :stats, StatsPanel::Update, model.stats))
      new_child, command = result
      return [model.with(stats: new_child), command && Rooibos.route(command, :stats)]
    end

    if (result = Rooibos.delegate(message, :network, NetworkPanel::Update, model.network))
      new_child, command = result
      return [model.with(network: new_child), command && Rooibos.route(command, :network)]
    end

    # Modal intercepts user input (not command results)
    if CustomShellModal.active?(model.shell_modal)
      new_modal, command = CustomShellModal::Update.call(message, model.shell_modal)
      return [model.with(shell_modal: new_modal), command]
    end

    # Handle user input
    case message
    in _ if message.q? || message.ctrl_c?
      Command.exit

    in _ if message.c?
      [model.with(shell_modal: CustomShellModal.open), nil]

    in _ if message.s?
      command = Rooibos.route(SystemInfo.fetch_command, :stats)
      new_stats = model.stats.with(system_info: model.stats.system_info.with(loading: true))
      [model.with(stats: new_stats), command]

    in _ if message.d?
      command = Rooibos.route(DiskUsage.fetch_command, :stats)
      new_stats = model.stats.with(disk_usage: model.stats.disk_usage.with(loading: true))
      [model.with(stats: new_stats), command]

    in _ if message.p?
      command = Rooibos.route(Ping.fetch_command, :network)
      new_network = model.network.with(ping: model.network.ping.with(loading: true))
      [model.with(network: new_network), command]

    in _ if message.u?
      command = Rooibos.route(Uptime.fetch_command, :network)
      new_network = model.network.with(uptime: model.network.uptime.with(loading: true))
      [model.with(network: new_network), command]

    else
      model
    end
  end
end
