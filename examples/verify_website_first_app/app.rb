# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "rooibos"

module FileBrowser
  # Model: What state does your app need?
  Model = Data.define(:path, :entries, :selected, :error)

  Init = -> {
    path    = Dir.pwd
    entries = Entries[path]
    Ractor.make_shareable( # Ensures thread safety
      Model.new(path:, entries:, selected: entries.first, error: nil))
  }

  View = -> (model, tui) {
    tui.block(
      titles: [
        model.error || model.path,
        { content: KEYS, position: :bottom, alignment: :right },
],
      borders: [:all],
      border_style: if model.error then tui.style(fg: :red) else nil end,
      children: [
tui.list(items: model.entries.map(&ListItem[model, tui]),
  selected_index: model.entries.index(model.selected),
  highlight_symbol: "",
  highlight_style: tui.style(modifiers: [:reversed])),
]
    )
  }

  Update = -> (message, model) {
    return model.with(error: ERROR) if message.error?
    model = model.with(error: nil) if model.error && message.key?

    if message.ctrl_c? || message.q? then Rooibos::Command.exit
    elsif message.home? || message.g? then model.with(selected: model.entries.first)
    elsif message.end? || (message.key? && message.shift_G?) then model.with(selected: model.entries.last)
    elsif (message.key? && message.up?) || message.k? then Select[:-, model]
    elsif (message.key? && message.down?) || message.j? then Select[:+, model]
    elsif message.enter? then Open[model]
    elsif message.escape? then Navigate[File.dirname(model.path), model]
    end
  }

  KEYS  = "↑/↓/Home/End: Select | Enter: Open | Esc: Navigate Up | q: Quit"
  ERROR = "Sorry, opening the selected file failed."

  ListItem = -> (model, tui) {
    -> (name) {
      modifiers = name.start_with?(".") ? [:dim] : []
      fg        = :blue if name.end_with?("/")
      tui.list_item(content: name, style: tui.style(fg:, modifiers:))
    }
  }

  Select = -> (operator, model) {
    new_index = model.entries.index(model.selected).public_send(operator, 1)
    model.with(selected: model.entries[new_index.clamp(0, model.entries.length - 1)])
  }

  Open = -> (model) {
    full = File.join(model.path, model.selected.delete_suffix("/"))
    model.selected.end_with?("/") ? Navigate[full, model] : Rooibos::Command.open(full)
  }

  Navigate = -> (path, model) {
    entries = Entries[path]
    model.with(path:, entries:, selected: entries.first, error: nil)
  }

  Entries = -> (path) {
    Dir.children(path).map { |name|
      File.directory?(File.join(path, name)) ? "#{name}/" : name
    }.sort_by { |name| [name.end_with?("/") ? 0 : 1, name.downcase] }
  }
end

Rooibos.run(FileBrowser) if __FILE__ == $0
