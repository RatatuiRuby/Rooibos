# frozen_string_literal: true

require "rooibos"
require_relative "file_browser/file_list"
require_relative "file_browser/title_bar"
require_relative "file_browser/directory_tree"
require_relative "file_browser/preview"
require_relative "file_browser/status_bar"

module FileBrowser
  include Rooibos::Router

  Model = Data.define(:file_list)

  Init = -> {
    Ractor.make_shareable Model.new(file_list: FileList::Init.call)
  }

  View = -> (model, tui) {
    title_bar = TitleBar::View.call(model.file_list, tui)
    directory_tree = DirectoryTree::View.call(model.file_list, tui)
    file_list = FileList::View.call(model.file_list, tui)
    preview = Preview::View.call(model.file_list, tui)
    status_bar = StatusBar::View.call(model.file_list, tui)

    content = tui.layout(
      direction: :horizontal,
      constraints: [
        tui.constraint_percentage(25),
        tui.constraint_percentage(40),
        tui.constraint_percentage(35),
      ],
      children: [directory_tree, file_list, preview]
    )

    tui.layout(
      direction: :vertical,
      constraints: [
        tui.constraint_length(1),
        tui.constraint_fill(1),
        tui.constraint_length(1),
      ],
      children: [title_bar, content, status_bar]
    )
  }

  route :file_list, to: FileList

  action :quit, -> { Rooibos::Command.exit }

  receive_events %i[q ctrl_c], :quit

  forward_events %i[down j],           to: :file_list, as: :move_down
  forward_events %i[up k],             to: :file_list, as: :move_up
  forward_events %i[home g],           to: :file_list, as: :jump_first
  forward_events %i[end shift_g],      to: :file_list, as: :jump_last
  forward_events :enter,               to: :file_list, as: :enter_directory
  forward_events %i[backspace escape], to: :file_list, as: :go_parent

  Update = from_router
end
