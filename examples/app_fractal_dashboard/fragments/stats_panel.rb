# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "ratatui_ruby/tea"
require_relative "system_info"
require_relative "disk_usage"

# Composes SystemInfo and DiskUsage in a horizontal layout.
module StatsPanel
  Model = Data.define(:system_info, :disk_usage)

  Init = -> do
    system_info, = RatatuiRuby::Tea.normalize_init(SystemInfo::Init.())
    disk_usage, = RatatuiRuby::Tea.normalize_init(DiskUsage::Init.())
    Model.new(system_info:, disk_usage:)
  end

  View = -> (model, tui, disabled: false) do
    tui.layout(
      direction: :horizontal,
      constraints: [tui.constraint_percentage(50), tui.constraint_percentage(50)],
      children: [
        SystemInfo::View.call(model.system_info, tui, disabled:),
        DiskUsage::View.call(model.disk_usage, tui, disabled:),
      ]
    )
  end

  Update = -> (message, model) do
    case message
    in [:system_info, *rest]
      new_child, command = SystemInfo::Update.call(rest, model.system_info)
      [model.with(system_info: new_child), command]
    in [:disk_usage, *rest]
      new_child, command = DiskUsage::Update.call(rest, model.disk_usage)
      [model.with(disk_usage: new_child), command]
    else
      [model, nil]
    end
  end
end
