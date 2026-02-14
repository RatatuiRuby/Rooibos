# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require_relative "base"

# UPDATE using the declarative Rooibos::Router DSL.
#
# This is the minimal-boilerplate approach: declare routes and keymaps,
# let from_router generate the UPDATE lambda. Maximum DX, least control.
module DashboardRouter
  include Rooibos::Router

  Command = Rooibos::Command

  # Shared with other Update variants
  Model = DashboardBase::Dashboard
  Init = DashboardBase::Init
  View = DashboardBase::View

  route :stats, to: StatsPanel
  route :network, to: NetworkPanel
  route :shell_modal, to: CustomShellModal

  # Guard: only handle keys when modal is not active
  MODAL_INACTIVE = -> (_msg, model) { !CustomShellModal.active?(model.shell_modal) }

  # Global Ctrl+C always works
  action :quit, -> { Command.exit }
  receive_events :ctrl_c, :quit

  # Forward async command results (Message::System::Batch) to the correct panel.
  # These must be forwarded BEFORE the modal otherwise guard, because command
  # results must reach their destination even when a modal is active.
  forward -> (msg, _) { Rooibos::Message::System::Batch === msg && %i[system_info disk_usage].include?(msg.envelope) },
    to: :stats
  forward -> (msg, _) { Rooibos::Message::System::Batch === msg && %i[ping uptime].include?(msg.envelope) },
    to: :network
  forward_instances_of Rooibos::Message::System::Stream, to: :shell_modal

  # When modal is active, forward all user input to the modal fragment.
  only when: -> (_msg, model) { CustomShellModal.active?(model.shell_modal) } do
    otherwise route_to: :shell_modal
  end

  # Keys only active when modal is inactive
  only when: MODAL_INACTIVE do
    receive_events :q, :quit

    # Forward key presses to panels as semantic routed messages.
    # The panel's Update handles the routed message to set loading + dispatch command.
    forward_events :s, to: :stats, as: :fetch_system_info
    forward_events :d, to: :stats, as: :fetch_disk_usage
    forward_events :p, to: :network, as: :fetch_ping
    forward_events :u, to: :network, as: :fetch_uptime

    # Open modal: model update at dashboard level
    receive_events :c, -> (_, model) {
      model.with(shell_modal: CustomShellModal.open)
    }
  end

  Update = from_router
end
