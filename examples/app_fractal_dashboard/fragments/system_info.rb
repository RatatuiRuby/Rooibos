# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "rooibos"
# Fetches and displays system information via +uname -a+.
# A fragment for fetching and displaying system information.
module SystemInfo
  Command = Rooibos::Command

  CommandResult = Data.define(:output, :loading)

  Init = -> do
    CommandResult.new(output: "Press 's' for system info", loading: false)
  end

  View = -> (model, tui, disabled: false) do
    text_style = if disabled && model.output == Init.().output
      tui.style(fg: :dark_gray)
    else
      nil
    end

    tui.paragraph(
      text: tui.text_span(content: model.output, style: text_style),
      block: tui.block(title: "System Info", borders: [:all], border_style: { fg: :cyan })
    )
  end

  Update = -> (message, model) do
    case message
    in { type: :system, envelope: :system_info, status: 0, stdout: }
      [model.with(output: stdout.strip, loading: false), nil]
    in { type: :system, envelope: :system_info, stderr: }
      [model.with(output: "Error: #{stderr.strip}", loading: false), nil]
    else
      [model, nil]
    end
  end

  def self.fetch_command
    Command.system("uname -a", :system_info)
  end
end
