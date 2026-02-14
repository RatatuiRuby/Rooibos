# frozen_string_literal: true

require "rooibos"

module FileBrowser
  module FileList
    include Rooibos::Router

    Entry = Data.define(:name, :directory?)

    Model = Data.define(:entries, :selected_index)

    Init = lambda {
      entries = ReadEntries.call(Dir.pwd)
      Ractor.make_shareable Model.new(entries:, selected_index: 0)
    }

    View = lambda { |model, tui|
      items = model.entries.map do |entry|
        if entry.directory?
          "#{entry.name}/"
        else
          entry.name
        end
      end

      tui.layout(children: [
                   tui.list(
                     items:,
                     selected_index: model.selected_index,
                     highlight_style: tui.style(modifiers: [:reversed])
                   ),
                 ])
    }

    receive_routed :move_down, lambda { |_message, model|
      last_index = model.entries.length - 1
      model.with selected_index: if model.selected_index < last_index
                                   model.selected_index + 1
                                 else
                                   0
      end
    }

    receive_routed :move_up, lambda { |_message, model|
      last_index = model.entries.length - 1
      model.with selected_index: if model.selected_index.positive?
                                   model.selected_index - 1
                                 else
                                   last_index
      end
    }

    receive_routed :jump_first, lambda { |_message, model|
      model.with selected_index: 0
    }

    receive_routed :jump_last, lambda { |_message, model|
      last_index = model.entries.length - 1
      model.with selected_index: last_index
    }

    Update = from_router

    ReadEntries = lambda { |path|
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
