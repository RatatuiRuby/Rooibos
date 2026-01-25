# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "rooibos"

module Counter
  # Init: How do you create the initial model?
  Init = -> { 0 }

  # View: What does the user see?
  View = -> (model, tui) { tui.paragraph(text: <<~END) }
    Current count: #{model}.
    Press any key to increment.
    Press Ctrl+C to quit.
  END

  # Update: What happens when things change?
  Update = -> (message, model) {
    if message.ctrl_c?
      Rooibos::Command.exit
    elsif message.key?
      model + 1
    end
  }
end

Rooibos.run(Counter) if __FILE__ == $0
