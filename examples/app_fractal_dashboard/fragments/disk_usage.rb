# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "rooibos"
# Fetches and displays disk usage via +df -h+.
# A fragment for fetching and displaying disk usage.
module DiskUsage
  Command = Rooibos::Command

  Model = Data.define(:output, :loading)

  Init = -> do
    Model.new(output: "Press 'd' for disk usage", loading: false)
  end

  View = -> (model, tui, disabled: false) do
    text_style = if disabled && model.output == Init.().output
      tui.style(fg: :dark_gray)
    else
      nil
    end

    tui.paragraph(
      text: tui.text_span(content: model.output, style: text_style),
      block: tui.block(title: "Disk Usage", borders: [:all], border_style: { fg: :cyan })
    )
  end

  Update = -> (message, model) do
    case message
    in { type: :system, envelope: :disk_usage, status: 0, stdout: }
      [model.with(output: Ractor.make_shareable(stdout.strip), loading: false), nil]
    in { type: :system, envelope: :disk_usage, stderr: }
      [model.with(output: Ractor.make_shareable("Error: #{stderr.strip}"), loading: false), nil]
    else
      [model, nil]
    end
  end

  def self.fetch_command
    Command.system("df -h /", :disk_usage)
  end
end
