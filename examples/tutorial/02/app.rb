# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "rooibos"

module Tutorial02
  module FileBrowser
    Model = Data.define(:current_directory, :file_names, :selected_index)

    View = -> (model, tui) {
      tui.layout(children: [
        tui.paragraph(text: model.current_directory),
        tui.list(
          items: model.file_names,
          selected_index: model.selected_index,
          highlight_style: tui.style(modifiers: [:reversed])
        ),
      ])
    }

    Update = -> (message, model) {
      if message.ctrl_c? or message.q?
        Rooibos::Command.exit
      elsif message.down_arrow? or message.j?
        new_index = (model.selected_index + 1) % model.file_names.length
        model.with(selected_index: new_index)
      elsif message.up_arrow? or message.k?
        new_index = (model.selected_index - 1) % model.file_names.length
        model.with(selected_index: new_index)
      elsif message.home? or message.g?
        model.with(selected_index: 0)
      elsif message.end? or message.G?
        model.with(selected_index: model.file_names.length - 1)
      else
        model
      end
    }

    Init = -> {
      current_directory = Dir.pwd
      file_names = Dir.children(current_directory)
      Ractor.make_shareable Model.new(current_directory, file_names, 0)
    }
  end
end

if __FILE__ == $0
  Rooibos.run(Tutorial02::FileBrowser)
end
