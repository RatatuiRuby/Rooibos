# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "rooibos"

module Tutorial01
  module FileBrowser
    Entry = Data.define(:name, :directory?)

    Model = Data.define(:current_directory, :entries)

    View = -> (model, tui) {
      items = model.entries.map { |e| e.directory? ? "#{e.name}/" : e.name }
      tui.layout(children: [
        tui.paragraph(text: model.current_directory),
        tui.list(items:),
      ])
    }

    Update = -> (message, model) {
      if message.ctrl_c? or message.q?
        Rooibos::Command.exit
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
      Ractor.make_shareable Model.new(current_directory, entries)
    }
  end
end

if __FILE__ == $0
  Rooibos.run(Tutorial01::FileBrowser)
end
