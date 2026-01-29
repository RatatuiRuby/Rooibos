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
  MODAL_INACTIVE = -> (model) { !CustomShellModal.active?(model.shell_modal) }

  keymap do |map|
    map.key :ctrl_c, -> { Command.exit }
    map.only when: MODAL_INACTIVE do
      map.key :q, -> { Command.exit }
      map.key :s, -> { SystemInfo.fetch_command }
      map.key :d, -> { DiskUsage.fetch_command }
      map.key :p, -> { Ping.fetch_command }
      map.key :u, -> { Uptime.fetch_command }
      map.key :c, -> { CustomShellModal.open }
    end
  end

  Update = from_router
end
