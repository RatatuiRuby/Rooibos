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

  # Guard: only handle keys when modal is not active
  MODAL_INACTIVE = -> (_msg, model) { !CustomShellModal.active?(model.shell_modal) }

  # Global Ctrl+C always works
  action :quit, -> { Command.exit }
  receive_events :ctrl_c, :quit

  # Keys only active when modal is inactive
  only when: MODAL_INACTIVE do
    receive_events :q, :quit
    receive_events :s, -> { SystemInfo.fetch_command }
    receive_events :d, -> { DiskUsage.fetch_command }
    receive_events :p, -> { Ping.fetch_command }
    receive_events :u, -> { Uptime.fetch_command }
    receive_events :c, -> { CustomShellModal.open }
  end

  Update = from_router
end
