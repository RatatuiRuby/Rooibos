# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "rooibos"

module Tutorial03
  module FileBrowser
    Entry = Data.define(:name, :directory?)

    Model = Data.define(:current_directory, :entries, :selected_index)

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
      elsif message.enter? or message.right_arrow? or message.l?
        selected_entry = model.entries[model.selected_index]
        if selected_entry.directory?
          new_dir = File.join(model.current_directory, selected_entry.name)
          new_entries = read_entries(new_dir)
          model.with(current_directory: new_dir, entries: new_entries, selected_index: 0)
        else
          model
        end
      elsif message.backspace? or message.left_arrow? or message.h?
        parent_dir = File.dirname(model.current_directory)
        new_entries = read_entries(parent_dir)
        model.with(current_directory: parent_dir, entries: new_entries, selected_index: 0)
      elsif message.tilde?
        home_dir = Dir.home
        new_entries = read_entries(home_dir)
        model.with(current_directory: home_dir, entries: new_entries, selected_index: 0)
      elsif message.slash?
        new_entries = read_entries("/")
        model.with(current_directory: "/", entries: new_entries, selected_index: 0)
      elsif message.R?
        new_entries = read_entries(model.current_directory)
        model.with(entries: new_entries)
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
      Ractor.make_shareable Model.new(current_directory, entries, 0)
    }

    private_class_method def self.read_entries(path)
      ReadEntries.call(path)
    end
  end
end

if __FILE__ == $0
  Rooibos.run(Tutorial03::FileBrowser)
end
