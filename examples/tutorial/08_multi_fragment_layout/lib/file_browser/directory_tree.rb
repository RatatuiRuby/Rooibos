# frozen_string_literal: true

require "rooibos"

module FileBrowser
  module DirectoryTree
    View = -> (model, tui) {
      tui.block(
        borders: [:top, :left, :bottom],
        padding: [1, 0, 0, 0],
        children: [
          tui.layout(
            direction: :vertical,
            constraints: [tui.constraint_length(2), tui.constraint_fill(1)],
            children: [
              tui.paragraph(text: "Directory Tree"),
              tui.paragraph(text: model.path),
            ]
          ),
        ]
      )
    }
  end
end
