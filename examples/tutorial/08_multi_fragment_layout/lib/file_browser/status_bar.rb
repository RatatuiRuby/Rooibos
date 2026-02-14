# frozen_string_literal: true

require "rooibos"

module FileBrowser
  module StatusBar
    View = -> (model, tui) {
      tui.paragraph(text: "#{model.entries.length} items")
    }
  end
end
