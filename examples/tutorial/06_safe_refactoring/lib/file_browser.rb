# frozen_string_literal: true

require "rooibos"
require_relative "file_browser/file_list"

module FileBrowser
  include Rooibos::Router

  Model = Data.define(:file_list)

  Init = lambda {
    Ractor.make_shareable Model.new(file_list: FileList::Init.call)
  }

  View = lambda { |model, tui|
    FileList::View.call(model.file_list, tui)
  }

  route :file_list, to: FileList

  action :quit, -> { Rooibos::Command.exit }

  receive_events %i[q ctrl_c], :quit

  forward_events %i[down j],      to: :file_list, as: :move_down
  forward_events %i[up k],        to: :file_list, as: :move_up
  forward_events %i[home g],      to: :file_list, as: :jump_first
  forward_events %i[end shift_g], to: :file_list, as: :jump_last

  Update = from_router
end
