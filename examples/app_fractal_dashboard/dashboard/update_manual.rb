# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require_relative "base"

# UPDATE using verbose manual routing.
#
# This is the most explicit approach: full pattern matching, explicit
# Command.map calls, manual model updates. Maximum control, maximum boilerplate.
module DashboardManual
  Command = Rooibos::Command

  # Shared with other UPDATE variants
  Model = DashboardBase::Dashboard
  Init = DashboardBase::Init
  View = DashboardBase::View

  Update = -> (message, model) do
    # Global Force Quit
    return [model, Rooibos::Command.exit] if message.respond_to?(:ctrl_c?) && message.ctrl_c?

    # IMPORTANT: Route command results BEFORE modal intercept.
    # Async command results must always reach their destination, even when a
    # modal is active. Only user input (keys/mouse) should be blocked.
    case message
    # Route command results to panels
    in [:stats, rest]
      new_panel, command = StatsPanel::Update.call(rest, model.stats)
      mapped_command = command ? Command.map(command) { |child_result| [:stats, *child_result] } : nil
      return [model.with(stats: new_panel), mapped_command]

    in [:network, rest]
      new_panel, command = NetworkPanel::Update.call(rest, model.network)
      mapped_command = command ? Command.map(command) { |child_result| [:network, *child_result] } : nil
      return [model.with(network: new_panel), mapped_command]

    in [:shell_output, rest]
      # Route streaming command output to modal
      new_modal, command = CustomShellModal::Update.call(message, model.shell_modal)
      return [model.with(shell_modal: new_modal), command]
    else
      nil # Fall through to input handling
    end

    # Modal intercepts user input (not command results)
    if CustomShellModal.active?(model.shell_modal)
      new_modal, command = CustomShellModal::Update.call(message, model.shell_modal)
      return [model.with(shell_modal: new_modal), command]
    end

    case message
    # Handle user input
    in _ if message.q? || message.ctrl_c?
      Command.exit

    in _ if message.c?
      [model.with(shell_modal: CustomShellModal.open), nil]

    in _ if message.s?
      command = Command.map(SystemInfo.fetch_command) { |batch| [:stats, batch] }
      new_stats = model.stats.with(system_info: model.stats.system_info.with(loading: true))
      [model.with(stats: new_stats), command]

    in _ if message.d?
      command = Command.map(DiskUsage.fetch_command) { |batch| [:stats, batch] }
      new_stats = model.stats.with(disk_usage: model.stats.disk_usage.with(loading: true))
      [model.with(stats: new_stats), command]

    in _ if message.p?
      command = Command.map(Ping.fetch_command) { |batch| [:network, batch] }
      new_network = model.network.with(ping: model.network.ping.with(loading: true))
      [model.with(network: new_network), command]

    in _ if message.u?
      command = Command.map(Uptime.fetch_command) { |batch| [:network, batch] }
      new_network = model.network.with(uptime: model.network.uptime.with(loading: true))
      [model.with(network: new_network), command]

    else
      model
    end
  end
end
