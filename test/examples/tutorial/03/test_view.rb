# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "../../../test_helper"
require_relative "../../../../examples/tutorial/03/app"

describe Tutorial03::FileBrowser::View do
  before do
    @tui = RatatuiRuby::TUI.new
  end

  def make_entry(name, directory: false)
    Tutorial03::FileBrowser::Entry.new(name:, directory?: directory)
  end

  def make_model(current_directory: "/test", entries: [], selected_index: 0)
    Tutorial03::FileBrowser::Model.new(
      current_directory:,
      entries:,
      selected_index:
    )
  end

  it "returns a layout with paragraph and list" do
    model = make_model(
      current_directory: "/home/user/projects",
      entries: []
    )

    widget = Tutorial03::FileBrowser::View.call(model, @tui)

    assert_instance_of(RatatuiRuby::Layout::Layout, widget)
    assert_instance_of(RatatuiRuby::Widgets::Paragraph, widget.children[0])
    assert_instance_of(RatatuiRuby::Widgets::List, widget.children[1])
  end

  it "displays current directory in paragraph" do
    model = make_model(current_directory: "/home/user/projects")

    widget = Tutorial03::FileBrowser::View.call(model, @tui)

    assert_equal("/home/user/projects", widget.children[0].text)
  end

  it "displays entry names in list with / suffix for directories" do
    entries = [
      make_entry("lib", directory: true),
      make_entry("README.md"),
      make_entry("test", directory: true),
    ]
    model = make_model(entries:)

    widget = Tutorial03::FileBrowser::View.call(model, @tui)

    assert_equal(["lib/", "README.md", "test/"], widget.children[1].items)
  end

  it "passes selected_index to list widget" do
    entries = [make_entry("a"), make_entry("b"), make_entry("c")]
    model = make_model(entries:, selected_index: 1)

    widget = Tutorial03::FileBrowser::View.call(model, @tui)

    assert_equal(1, widget.children[1].selected_index)
  end

  it "applies highlight style to selected item" do
    entries = [make_entry("a"), make_entry("b"), make_entry("c")]
    model = make_model(entries:, selected_index: 0)

    widget = Tutorial03::FileBrowser::View.call(model, @tui)

    assert widget.children[1].highlight_style, "Expected highlight_style to be set"
    assert_includes widget.children[1].highlight_style.modifiers, :reversed
  end
end
