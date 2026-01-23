# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "rooibos"

module FileBrowser
  Model = Data.define(:current_directory, :file_names)

  View = -> (model, tui) {
    tui.layout(children: [
      tui.paragraph(text: model.current_directory),
      tui.list(items: model.file_names),
    ])
  }

  Update = -> (message, model) {
    if message.ctrl_c? or message.q?
      Rooibos::Command.exit
    else
      model
    end
  }

  Init = -> {
    current_directory = Dir.pwd
    file_names = Dir.children(current_directory)
    Ractor.make_shareable Model.new(current_directory, file_names)
  }
end

if __FILE__ == $0
  Rooibos.run(FileBrowser)
end
