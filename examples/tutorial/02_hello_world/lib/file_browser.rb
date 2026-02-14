# frozen_string_literal: true

require "rooibos"

module FileBrowser
  Init = -> { nil }

  View = lambda { |_model, tui|
    tui.layout(children: [
      tui.paragraph(text: "Hello, File Browser!"),
      tui.paragraph(text: "Press 'q' to quit"),
               ])
  }

  Update = lambda { |message, _model|
    case message
    in { type: :key, code: "q" } | { type: :key, code: "c", modifiers: ["ctrl"] }
      Rooibos::Command.exit
    else
    end
  }
end
