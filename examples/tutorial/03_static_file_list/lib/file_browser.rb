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

  Init = lambda {
    Ractor.make_shareable Model.new(entries: EXAMPLE_ENTRIES, selected_index: 0)
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

  Update = lambda { |message, _model|
    case message
    in { type: :key, code: "q" } | { type: :key, code: "c", modifiers: ["ctrl"] }
      Rooibos::Command.exit
    else
    end
  }
end
