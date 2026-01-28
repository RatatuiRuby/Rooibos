# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "rooibos"
# Displays system uptime.
# A fragment for displaying system uptime.
module Uptime
  Command = Rooibos::Command

  CommandResult = Data.define(:output, :loading)

  Init = -> do
    CommandResult.new(output: "Press 'u' for uptime", loading: false)
  end

  View = -> (model, tui, disabled: false) do
    text_style = if disabled && model.output == Init.().output
      tui.style(fg: :dark_gray)
    else
      nil
    end

    tui.paragraph(
      text: tui.text_span(content: model.output, style: text_style),
      block: tui.block(title: "Uptime", borders: [:all], border_style: { fg: :magenta })
    )
  end

  Update = -> (message, model) do
    case message
    in { type: :system, envelope: :uptime, status: 0, stdout: }
      [model.with(output: Ractor.make_shareable(stdout.strip), loading: false), nil]
    in { type: :system, envelope: :uptime, stderr: }
      [model.with(output: Ractor.make_shareable("Error: #{stderr.strip}"), loading: false), nil]
    else
      [model, nil]
    end
  end

  def self.fetch_command
    Command.system("uptime", :uptime)
  end
end
