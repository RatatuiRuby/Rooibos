# frozen_string_literal: true

require "rooibos"

module FileBrowser
  module FileList
    include Rooibos::Router

    Entry = Data.define(:name, :directory?)

    Model = Data.define(:path, :entries, :selected_index)

    Init = -> {
      path = Dir.pwd
      entries = ReadEntries.call(path)
      Ractor.make_shareable Model.new(path:, entries:, selected_index: 0)
    }

    View = -> (model, tui) {
      items = model.entries.map do |entry|
        if entry.directory?
          "#{entry.name}/"
        else
          entry.name
        end
      end

      tui.block(
        borders: [:all],
        padding: [1, 0, 0, 0],
        children: [
          tui.layout(
            direction: :vertical,
            constraints: [tui.constraint_length(2), tui.constraint_fill(1)],
            children: [
              tui.paragraph(text: "Files"),
              tui.list(
                items:,
                selected_index: model.selected_index,
                highlight_style: tui.style(modifiers: [:reversed])
              ),
            ]
          ),
        ]
      )
    }

    receive_routed :move_down, -> (_message, model) {
      last_index = model.entries.length - 1
      selected_index = if model.selected_index < last_index
        model.selected_index + 1
      else
        0
      end
      model.with(selected_index:)
    }

    receive_routed :move_up, -> (_message, model) {
      last_index = model.entries.length - 1
      selected_index = if model.selected_index.positive?
        model.selected_index - 1
      else
        last_index
      end
      model.with(selected_index:)
    }

    receive_routed :jump_first, -> (_message, model) {
      model.with selected_index: 0
    }

    receive_routed :jump_last, -> (_message, model) {
      last_index = model.entries.length - 1
      model.with selected_index: last_index
    }

    receive_routed :enter_directory, -> (_message, model) {
      selected = model.entries[model.selected_index]
      return model unless selected.directory?

      new_path = File.join(model.path, selected.name)
      entries = ReadEntries.call(new_path)
      model.with(path: new_path, entries:, selected_index: 0)
    }

    receive_routed :go_parent, -> (_message, model) {
      parent = File.dirname(model.path)
      return model if parent == model.path

      entries = ReadEntries.call(parent)
      model.with(path: parent, entries:, selected_index: 0)
    }

    Update = from_router

    ReadEntries = -> (path) {
      entries = Dir.children(path).map do |name|
        full_path = File.join(path, name)
        Entry.new(name:, directory?: File.directory?(full_path))
      end

      directories, files = entries.partition(&:directory?)

      sorted_directories = directories.sort_by do |entry|
        entry.name.downcase
      end

      sorted_files = files.sort_by do |entry|
        entry.name.downcase
      end

      sorted_directories + sorted_files
    }
  end
end
