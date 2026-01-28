# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "../../../test_helper"
require_relative "../../../../examples/tutorial/01/app"

describe Tutorial01::FileBrowser::View do
  before do
    @tui = RatatuiRuby::TUI.new
  end

  def make_entry(name, directory: false)
    Tutorial01::FileBrowser::Entry.new(name:, directory?: directory)
  end

  it "returns a layout with paragraph and list" do
    model = Tutorial01::FileBrowser::DirectoryListing.new(
      current_directory: "/home/user/projects",
      entries: []
    )

    widget = Tutorial01::FileBrowser::View.call(model, @tui)

    assert_instance_of(RatatuiRuby::Layout::Layout, widget)
    assert_instance_of(RatatuiRuby::Widgets::Paragraph, widget.children[0])
    assert_instance_of(RatatuiRuby::Widgets::List, widget.children[1])
    assert_equal("/home/user/projects", widget.children[0].text)
    assert_equal([], widget.children[1].items)
  end

  it "displays entry names in list with / suffix for directories" do
    entries = [
      make_entry("lib", directory: true),
      make_entry("README.md"),
      make_entry("test", directory: true),
    ]
    model = Tutorial01::FileBrowser::DirectoryListing.new(
      current_directory: "/test",
      entries:
    )

    widget = Tutorial01::FileBrowser::View.call(model, @tui)

    assert_equal(["lib/", "README.md", "test/"], widget.children[1].items)
  end
end
