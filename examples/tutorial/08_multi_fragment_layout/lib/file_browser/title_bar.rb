# frozen_string_literal: true

require "rooibos"

module FileBrowser
  module TitleBar
    View = -> (model, tui) {
      tui.paragraph(text: model.path)
    }
  end
end
