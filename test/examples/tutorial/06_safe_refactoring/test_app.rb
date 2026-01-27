# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "../../../test_helper"
require "rooibos/test_helper"
require_relative "../../../../examples/tutorial/06_safe_refactoring/app"

# Snapshot tests for Tutorial 06: Safe Refactoring
#
# These tests demonstrate that the refactoring (extracting FileList fragment)
# preserved behavior. The snapshots capture the rendered output.
class TestTutorial06SafeRefactoring < Minitest::Test
  include Rooibos::TestHelper

  def test_initial_render
    with_test_terminal(80, 24) do
      with_stubbed_filesystem(%w[lib/ test/ Gemfile README.md]) do
        inject_key(:q)
        Rooibos.run(Tutorial06::FileBrowser)
        assert_snapshots("initial_render")
      end
    end
  end

  def test_selection_moves_down
    with_test_terminal(80, 24) do
      with_stubbed_filesystem(%w[a b c]) do
        inject_key(:down)
        inject_key(:q)
        Rooibos.run(Tutorial06::FileBrowser)
        assert_snapshots("selection_down")
      end
    end
  end

  def test_selection_moves_up_wraps
    with_test_terminal(80, 24) do
      with_stubbed_filesystem(%w[a b c]) do
        inject_key(:up)
        inject_key(:q)
        Rooibos.run(Tutorial06::FileBrowser)
        assert_snapshots("selection_wrap")
      end
    end
  end

  def test_vim_navigation
    with_test_terminal(80, 24) do
      with_stubbed_filesystem(%w[a b c d e]) do
        inject_key("j")  # down
        inject_key("j")  # down
        inject_key("k")  # up
        inject_key(:q)
        Rooibos.run(Tutorial06::FileBrowser)
        assert_snapshots("vim_nav")
      end
    end
  end

  def test_jump_to_end
    with_test_terminal(80, 24) do
      with_stubbed_filesystem(%w[a b c d e]) do
        inject_key(:end)
        inject_key(:q)
        Rooibos.run(Tutorial06::FileBrowser)
        assert_snapshots("jump_end")
      end
    end
  end

  private def with_stubbed_filesystem(entries, &block)
    # Build Entry objects (directories end with /)
    entry_objects = entries.map do |name|
      is_dir = name.end_with?("/")
      Tutorial06::FileList::Entry.new(
        name: name.delete_suffix("/"),
        directory?: is_dir
      )
    end.sort_by { |e| [e.directory? ? 0 : 1, e.name.downcase] }

    Dir.stub(:pwd, "/tmp/test") do
      Tutorial06::FileList::ReadEntries.stub(:call, entry_objects, &block)
    end
  end
end
