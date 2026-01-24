# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "../../test_helper"
require "rooibos/test_helper"
require_relative "../../../examples/app_file_browser/app"

describe FileBrowser::Update do
  include Rooibos::TestHelper

  it "exits on q key" do
    model = FileBrowser::Model.new(current_directory: "/test", file_names: [])
    message = RatatuiRuby::Event::Key.new(code: "q")

    result = FileBrowser::Update.call(message, model)

    assert_instance_of(Rooibos::Command::Exit, result)
  end

  it "exits on Ctrl+C" do
    model = FileBrowser::Model.new(current_directory: "/test", file_names: [])
    message = RatatuiRuby::Event::Key.new(code: "c", modifiers: [:ctrl])

    result = FileBrowser::Update.call(message, model)

    assert_instance_of(Rooibos::Command::Exit, result)
  end

  it "returns unchanged model for unhandled keys" do
    model = FileBrowser::Model.new(current_directory: "/test", file_names: [])
    message = RatatuiRuby::Event::Key.new(code: "a")

    result = FileBrowser::Update.call(message, model)

    assert_equal(model, result)
  end
end
