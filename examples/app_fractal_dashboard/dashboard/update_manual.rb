# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require_relative "base"

# UPDATE using verbose manual routing.
#
# This is the most explicit approach: full pattern matching, explicit
# delegation calls, manual model updates. Maximum control, maximum boilerplate.
#
# This manually simulates exactly what DashboardRouter does via the Router DSL.
module DashboardManual
  Command = Rooibos::Command
  Routed = Rooibos::Message::Routed

  # Shared with other UPDATE variants
  Model = DashboardBase::Dashboard
  Init = DashboardBase::Init
  View = DashboardBase::View

  Update = -> (message, model) do
    # Global Force Quit — always handled, even during modal
    return [model, Command.exit] if message.respond_to?(:ctrl_c?) && message.ctrl_c?

    # IMPORTANT: Route async command results BEFORE modal intercept.
    # Command results must always reach their destination, even when a
    # modal is active. Only user input (keys/mouse) should be blocked.

    # Route Message::System::Batch results to the correct panel
    if Rooibos::Message::System::Batch === message
      case message.envelope
      when :system_info, :disk_usage
        new_child, command = StatsPanel::Update.call(message, model.stats)
        return [model.with(stats: new_child), command]
      when :ping, :uptime
        new_child, command = NetworkPanel::Update.call(message, model.network)
        return [model.with(network: new_child), command]
      end
    end

    # Route Message::System::Stream results to the modal
    if Rooibos::Message::System::Stream === message
      new_modal, command = CustomShellModal::Update.call(message, model.shell_modal)
      return [model.with(shell_modal: new_modal), command]
    end

    # Modal intercepts all user input (not command results)
    if CustomShellModal.active?(model.shell_modal)
      new_modal, command = CustomShellModal::Update.call(message, model.shell_modal)
      return [model.with(shell_modal: new_modal), command]
    end

    # Handle user input when modal is inactive
    case message
    in _ if message.q?
      Command.exit

    in _ if message.c?
      [model.with(shell_modal: CustomShellModal.open), nil]

    in _ if message.s?
      routed = Routed.new(envelope: :fetch_system_info, event: message)
      new_child, command = StatsPanel::Update.call(routed, model.stats)
      [model.with(stats: new_child), command]

    in _ if message.d?
      routed = Routed.new(envelope: :fetch_disk_usage, event: message)
      new_child, command = StatsPanel::Update.call(routed, model.stats)
      [model.with(stats: new_child), command]

    in _ if message.p?
      routed = Routed.new(envelope: :fetch_ping, event: message)
      new_child, command = NetworkPanel::Update.call(routed, model.network)
      [model.with(network: new_child), command]

    in _ if message.u?
      routed = Routed.new(envelope: :fetch_uptime, event: message)
      new_child, command = NetworkPanel::Update.call(routed, model.network)
      [model.with(network: new_child), command]

    else
      model
    end
  end
end
