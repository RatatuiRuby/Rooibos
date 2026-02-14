# frozen_string_literal: true

require "rooibos"

module FileBrowser
  module Preview
    View = -> (model, tui) {
      tui.block(
        borders: [:top, :right, :bottom],
        padding: [1, 0, 0, 0],
        children: [
          tui.layout(
            direction: :vertical,
            constraints: [tui.constraint_length(2), tui.constraint_fill(1)],
            children: [
              tui.paragraph(text: "Preview"),
              tui.paragraph(text: "No preview"),
            ]
          ),
        ]
      )
    }
  end
end
