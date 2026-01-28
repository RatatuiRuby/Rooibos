# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "rooibos"

module Tutorial06
  # A Fragment is a module with Model, Init, Update, View.
  # This FileList fragment handles the list of files and navigation.
  module FileList
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
      if message.move_down?
        new_index = (model.selected_index + 1) % model.entries.length
        model.with(selected_index: new_index)
      elsif message.move_up?
        new_index = (model.selected_index - 1) % model.entries.length
        model.with(selected_index: new_index)
      elsif message.jump_to_first?
        model.with(selected_index: 0)
      elsif message.jump_to_last?
        model.with(selected_index: model.entries.length - 1)
      elsif message.enter?
        selected_entry = model.entries[model.selected_index]
        if selected_entry.directory?
          new_dir = File.join(model.current_directory, selected_entry.name)
          new_entries = read_entries(new_dir)
          model.with(current_directory: new_dir, entries: new_entries, selected_index: 0)
        else
          nil
        end
      elsif message.go_back?
        parent_dir = File.dirname(model.current_directory)
        new_entries = read_entries(parent_dir)
        model.with(current_directory: parent_dir, entries: new_entries, selected_index: 0)
      elsif message.go_home?
        home_dir = Dir.home
        new_entries = read_entries(home_dir)
        model.with(current_directory: home_dir, entries: new_entries, selected_index: 0)
      elsif message.go_root?
        root = File.expand_path("/")
        new_entries = read_entries(root)
        model.with(current_directory: root, entries: new_entries, selected_index: 0)
      elsif message.refresh?
        new_entries = read_entries(model.current_directory)
        model.with(entries: new_entries)
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

    private_class_method def self.read_entries(path)
      ReadEntries.call(path)
    end
  end

  # The main FileBrowser delegates to the FileList fragment via Router.
  module FileBrowser
    include Rooibos::Router

    Command = Rooibos::Command

    # Parent model wraps child fragment
    Model = Data.define(:file_list)

    route :file_list, to: FileList

    action go_back: FileList, keys: %i[backspace left h]
    action go_home: FileList, key: :~
    action go_root: FileList, key: :/
    action refresh: FileList, key: :R
    action enter: FileList, keys: %i[enter right l]
    action move_down: FileList, keys: %i[down j]
    action move_up: FileList, keys: %i[up k]
    action jump_to_first: FileList, keys: %i[home g]
    action jump_to_last: FileList, keys: %i[end G]
    action -> { Command.exit }, keys: %i[ctrl_c q]

    View = -> (model, tui) {
      FileList::View.call(model.file_list, tui)
    }

    Update = from_router

    Init = -> {
      file_list = FileList::Init.()
      Ractor.make_shareable Model.new(file_list:)
    }
  end
end

if __FILE__ == $0
  Rooibos.run(Tutorial06::FileBrowser)
end
