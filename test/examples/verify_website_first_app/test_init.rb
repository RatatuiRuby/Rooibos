# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require_relative "../../test_helper"
require "rooibos/test_helper"
require_relative "../../../examples/verify_website_first_app/app"

# Unit tests for FileBrowser::Init.
#
# Init creates the initial model. Test it without a terminal.
class TestFileBrowserInit < Minitest::Test
  include Rooibos::TestHelper

  def test_init_returns_shareable_model
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        FileUtils.touch("README.md")
        FileUtils.touch("Gemfile")

        model = FileBrowser::Init.call

        assert Ractor.shareable?(model), "Model should be Ractor-shareable"
        assert_instance_of FileBrowser::Model, model
      end
    end
  end

  def test_init_uses_current_directory
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        model = FileBrowser::Init.call

        # Use realpath to handle macOS /var -> /private/var symlink
        assert_equal File.realpath(dir), model.path
      end
    end
  end

  def test_init_lists_directories_first_case_insensitive
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        FileUtils.touch("zebra.txt")
        FileUtils.touch("Apple.txt")
        FileUtils.mkdir("middle")

        model = FileBrowser::Init.call

        # Directories first (with /), then files, case-insensitive
        assert_equal %w[middle/ Apple.txt zebra.txt], model.entries
      end
    end
  end

  def test_init_selects_first_entry
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        FileUtils.mkdir("adir")
        FileUtils.touch("bfile.txt")

        model = FileBrowser::Init.call

        # Directory comes first
        assert_equal "adir/", model.selected
      end
    end
  end

  def test_init_has_no_error
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        FileUtils.touch("file.txt")

        model = FileBrowser::Init.call

        assert_nil model.error
      end
    end
  end
end
