# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require_relative "../../test_helper"
require "rooibos/test_helper"
require_relative "../../../examples/verify_website_first_app/app"

# Unit tests for FileBrowser::View.
#
# View is a pure function: model in, widget out. Test the widget structure
# without rendering to a terminal.
class TestFileBrowserView < Minitest::Test
  include Rooibos::TestHelper

  def setup
    @tui = RatatuiRuby::TUI.new
  end

  def test_returns_block_widget
    model = make_model(path: "/home/user", entries: %w[a b], selected: "a")

    widget = FileBrowser::View.call(model, @tui)

    assert_instance_of RatatuiRuby::Widgets::Block, widget
  end

  def test_shows_path_in_title
    model = make_model(path: "/home/user/projects", entries: %w[a], selected: "a")

    widget = FileBrowser::View.call(model, @tui)

    assert_includes widget.titles.map { |t| t.is_a?(Hash) ? t[:content] : t }, "/home/user/projects"
  end

  def test_shows_error_in_title_when_present
    model = make_model(path: "/test", entries: %w[a], selected: "a", error: "Something went wrong")

    widget = FileBrowser::View.call(model, @tui)

    # Error replaces path in title
    assert_includes widget.titles.map { |t| t.is_a?(Hash) ? t[:content] : t }, "Something went wrong"
  end

  def test_contains_list_with_entries
    model = make_model(path: "/test", entries: %w[README.md Gemfile lib], selected: "README.md")

    widget = FileBrowser::View.call(model, @tui)
    list = widget.children.find { |c| c.is_a?(RatatuiRuby::Widgets::List) }

    refute_nil list, "View should contain a List widget"
    assert_equal 3, list.items.size
  end

  private

  def make_model(path: "/test", entries: [], selected: nil, error: nil)
    Ractor.make_shareable(
      FileBrowser::Model.new(path:, entries:, selected:, error:)
    )
  end
end
