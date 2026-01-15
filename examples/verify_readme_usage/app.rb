# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "ratatui_ruby"
require "ratatui_ruby/tea"

class VerifyReadmeUsage
  # [SYNC:START:mvu]
  Model = Data.define(:text)

  Init = -> do
    Model.new(text: "Hello, Ratatui! Press 'q' to quit.")
  end

  View = -> (model, tui) do
    tui.paragraph(
      text: model.text,
      alignment: :center,
      block: tui.block(
        title: "My Ruby TUI App",
        borders: [:all],
        border_style: { fg: "cyan" }
      )
    )
  end

  Update = -> (msg, model) do
    if msg.q? || msg.ctrl_c?
      RatatuiRuby::Tea::Command.exit
    else
      model
    end
  end

  def run
    RatatuiRuby::Tea.run(VerifyReadmeUsage)
  end
  # [SYNC:END:mvu]
end

VerifyReadmeUsage.new.run if __FILE__ == $PROGRAM_NAME
