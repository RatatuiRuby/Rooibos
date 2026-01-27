# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "../../../test_helper"
require_relative "../../../../examples/tutorial/02/app"

describe Tutorial02::FileBrowser::View do
  before do
    @tui = RatatuiRuby::TUI.new
  end

  def make_model(current_directory: "/test", file_names: [], selected_index: 0)
    Tutorial02::FileBrowser::Model.new(
      current_directory:,
      file_names:,
      selected_index:
    )
  end

  it "returns a layout with paragraph and list" do
    model = make_model(
      current_directory: "/home/user/projects",
      file_names: []
    )

    widget = Tutorial02::FileBrowser::View.call(model, @tui)

    assert_instance_of(RatatuiRuby::Layout::Layout, widget)
    assert_instance_of(RatatuiRuby::Widgets::Paragraph, widget.children[0])
    assert_instance_of(RatatuiRuby::Widgets::List, widget.children[1])
  end

  it "displays current directory in paragraph" do
    model = make_model(current_directory: "/home/user/projects")

    widget = Tutorial02::FileBrowser::View.call(model, @tui)

    assert_equal("/home/user/projects", widget.children[0].text)
  end

  it "displays file names in list" do
    file_names = ["README.md", "Gemfile", "lib", "test"]
    model = make_model(file_names:)

    widget = Tutorial02::FileBrowser::View.call(model, @tui)

    assert_equal(file_names, widget.children[1].items)
  end

  it "passes selected_index to list widget" do
    model = make_model(file_names: %w[a b c], selected_index: 1)

    widget = Tutorial02::FileBrowser::View.call(model, @tui)

    assert_equal(1, widget.children[1].selected_index)
  end

  it "applies highlight style to selected item" do
    model = make_model(file_names: %w[a b c], selected_index: 0)

    widget = Tutorial02::FileBrowser::View.call(model, @tui)

    assert widget.children[1].highlight_style, "Expected highlight_style to be set"
    assert_includes widget.children[1].highlight_style.modifiers, :reversed
  end
end
