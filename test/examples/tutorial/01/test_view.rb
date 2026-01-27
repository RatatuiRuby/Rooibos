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

  it "returns a paragraph widget with current directory path" do
    model = Tutorial01::FileBrowser::Model.new(
      current_directory: "/home/user/projects",
      file_names: []
    )

    widget = Tutorial01::FileBrowser::View.call(model, @tui)

    assert_instance_of(RatatuiRuby::Layout::Layout, widget)
    assert_instance_of(RatatuiRuby::Widgets::Paragraph, widget.children[0])
    assert_instance_of(RatatuiRuby::Widgets::List, widget.children[1])
    assert_equal("/home/user/projects", widget.children[0].text)
    assert_equal([], widget.children[1].items)
  end

  it "displays file names in the widget" do
    file_names = [
      "README.md",
      "Gemfile",
      "lib",
      "test",
    ]

    model = Tutorial01::FileBrowser::Model.new(
      current_directory: "/test",
      file_names:
    )

    widget = Tutorial01::FileBrowser::View.call(model, @tui)

    assert_instance_of(RatatuiRuby::Layout::Layout, widget)
    assert_instance_of(RatatuiRuby::Widgets::Paragraph, widget.children[0])
    assert_instance_of(RatatuiRuby::Widgets::List, widget.children[1])
    assert_equal("/test", widget.children[0].text)
    assert_equal(file_names, widget.children[1].items)
  end
end
