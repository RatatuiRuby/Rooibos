# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require_relative "../../test_helper"
require "rooibos/test_helper"
require_relative "../../../examples/verify_website_first_app/app"

# Integration tests for FileBrowser::View.
#
# Render the View's widget tree to a headless terminal and verify styling
# with style assertions. Tests View + rendering, but not the full runtime.
class TestFileBrowserViewIntegration < Minitest::Test
  include Rooibos::TestHelper

  def setup
    @tui = RatatuiRuby::TUI.new
  end

  def test_error_state_has_red_border
    with_test_terminal(60, 10) do
      model = make_model(entries: %w[a], selected: "a", error: "Error!")
      widget = FileBrowser::View.call(model, @tui)

      RatatuiRuby.draw { |frame| frame.render_widget(widget, frame.area) }

      # Border at top-left should be red
      assert_red(0, 0)
    end
  end

  def test_directories_are_blue
    with_test_terminal(60, 10) do
      # Trailing slash indicates directory (stored in model, no filesystem check)
      model = make_model(entries: %w[file.txt subdir/], selected: "file.txt")
      widget = FileBrowser::View.call(model, @tui)

      RatatuiRuby.draw { |frame| frame.render_widget(widget, frame.area) }

      # "subdir/" is at row 2 (row 0 is border, row 1 is "file.txt")
      assert_blue(1, 2)
    end
  end

  def test_hidden_files_are_dim
    with_test_terminal(60, 10) do
      # Leading dot indicates hidden (no filesystem needed)
      model = make_model(entries: %w[.hidden visible], selected: ".hidden")
      widget = FileBrowser::View.call(model, @tui)

      RatatuiRuby.draw { |frame| frame.render_widget(widget, frame.area) }

      # Hidden file should be dim (row 1 = first entry)
      assert_dim(1, 1)
    end
  end

  def test_selected_item_is_reversed
    with_test_terminal(60, 10) do
      model = make_model(entries: %w[a b c], selected: "b")
      widget = FileBrowser::View.call(model, @tui)

      RatatuiRuby.draw { |frame| frame.render_widget(widget, frame.area) }

      # "b" is at index 1, appears on row 2 (row 0 is border, row 1 is "a")
      assert_reversed(1, 2)
    end
  end

  private def make_model(path: "/test", entries: [], selected: nil, error: nil)
    Ractor.make_shareable(
      FileBrowser::DirectoryListing.new(path:, entries:, selected:, error:)
    )
  end
end
