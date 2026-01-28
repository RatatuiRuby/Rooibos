# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "rooibos"

module Tutorial02
  module FileBrowser
    Entry = Data.define(:name, :directory?)

    DirectoryListing = Data.define(:current_directory, :entries, :selected_index)

    View = -> (model, tui) {
      items = model.entries.map { |e| e.directory? ? "#{e.name}/" : e.name }
      tui.layout(children: [
        tui.paragraph(text: model.current_directory),
        tui.list(
          items:,
          selected_index: model.selected_index,
          highlight_style: tui.style(modifiers: [:reversed])
        ),
      ])
    }

    Update = -> (message, model) {
      if message.ctrl_c? or message.q?
        Rooibos::Command.exit
      elsif message.down_arrow? or message.j?
        new_index = (model.selected_index + 1) % model.entries.length
        model.with(selected_index: new_index)
      elsif message.up_arrow? or message.k?
        new_index = (model.selected_index - 1) % model.entries.length
        model.with(selected_index: new_index)
      elsif message.home? or message.g?
        model.with(selected_index: 0)
      elsif message.end? or message.G?
        model.with(selected_index: model.entries.length - 1)
      else
        model
      end
    }

    ReadEntries = -> (path) {
      Dir.children(path).map { |name|
        full_path = File.join(path, name)
        Entry.new(name:, directory?: File.directory?(full_path))
      }.sort_by { |e| [e.directory? ? 0 : 1, e.name.downcase] }
    }

    Init = -> {
      current_directory = Dir.pwd
      entries = ReadEntries.call(current_directory)
      Ractor.make_shareable DirectoryListing.new(current_directory, entries, 0)
    }
  end
end

if __FILE__ == $0
  Rooibos.run(Tutorial02::FileBrowser)
end
