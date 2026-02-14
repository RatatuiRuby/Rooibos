# frozen_string_literal: true

require "rooibos"

module FileBrowser
  Entry = Data.define(:name, :directory?)

  Model = Data.define(:entries, :selected_index)

  EXAMPLE_ENTRIES = [
    Entry.new(name: "Gemfile", directory?: false),
    Entry.new(name: "README.md", directory?: false),
    Entry.new(name: "lib", directory?: true),
    Entry.new(name: "test", directory?: true),
  ].freeze

  Init = -> {
    Ractor.make_shareable Model.new(entries: EXAMPLE_ENTRIES, selected_index: 0)
  }

  View = -> (model, tui) {
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

  Update = -> (message, model) {
    last_index = model.entries.length - 1

    case message
    in { type: :key, code: "q" } | { type: :key, code: "c", modifiers: ["ctrl"] }
      Rooibos::Command.exit
    in { type: :key, code: "end" } | { type: :key, code: "G", modifiers: ["shift"] }
      model.with selected_index: last_index
    in type: :key, code: "home" | "g"
      model.with selected_index: 0
    in type: :key, code: "up" | "k"
      selected_index = if model.selected_index.positive?
        model.selected_index - 1
      else
        last_index
      end
      model.with(selected_index:)
    in type: :key, code: "down" | "j"
      selected_index = if model.selected_index < last_index
        model.selected_index + 1
      else
        0
      end
      model.with(selected_index:)
    else
    end
  }
end
