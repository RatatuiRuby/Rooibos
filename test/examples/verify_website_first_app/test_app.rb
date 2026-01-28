# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require_relative "../../test_helper"
require "rooibos/test_helper"
require_relative "../../../examples/verify_website_first_app/app"

# System tests for FileBrowser.
#
# These tests run the full app with a headless terminal. They demonstrate:
# - Event injection (inject_key)
# - Snapshot testing (assert_snapshots)
class TestFileBrowserSystem < Minitest::Test
  include Rooibos::TestHelper

  def test_initial_render
    with_test_terminal(120, 10) do
      with_test_directory(%w[README.md Gemfile lib/ test/]) do |dir|
        inject_key(:ctrl_c)

        # Directories first (with /), then files, case-insensitive sort
        Rooibos.run(
          model: make_model(path: dir, entries: %w[lib/ test/ Gemfile README.md], selected: "lib/"),
          view: FileBrowser::View,
          update: FileBrowser::Update
        )

        assert_snapshots("initial_render") { |lines| normalize_paths(lines, dir) }
      end
    end
  end

  def test_selection_moves_down
    with_test_terminal(120, 10) do
      with_test_directory(%w[a b c]) do |dir|
        inject_key(:down)
        inject_key(:ctrl_c)

        Rooibos.run(
          model: make_model(path: dir, entries: %w[a b c], selected: "a"),
          view: FileBrowser::View,
          update: FileBrowser::Update
        )

        assert_snapshots("selection_moved_down") { |lines| normalize_paths(lines, dir) }
      end
    end
  end

  def test_error_state_render
    with_test_terminal(120, 10) do
      with_test_directory(%w[a b c]) do |dir|
        inject_key(:q)

        Rooibos.run(
          model: make_model(path: dir, entries: %w[a b c], selected: "a", error: FileBrowser::ERROR),
          view: FileBrowser::View,
          update: FileBrowser::Update
        )

        assert_snapshots("error_state") { |lines| normalize_paths(lines, dir) }
      end
    end
  end

  private def make_model(path: "/test", entries: [], selected: nil, error: nil)
    Ractor.make_shareable(
      FileBrowser::DirectoryListing.new(path:, entries:, selected:, error:)
    )
  end

  private def with_test_directory(files = [], &block)
    Dir.mktmpdir do |dir|
      files.each do |name|
        path = File.join(dir, name)
        if name.end_with?("/")
          FileUtils.mkdir_p(path)
        else
          FileUtils.touch(path)
        end
      end
      block.call(dir)
    end
  end

  # Normalize platform-specific temp paths for snapshot portability.
  # Replaces dynamic path + trailing dashes with canonical 120-char title bar.
  private def normalize_paths(lines, dir)
    title = "┌/tmp/test#{'─' * 107}┐"
    lines.map do |l|
      l.gsub(/┌#{Regexp.escape(dir)}[^┐]*┐/, title)
    end
  end
end
