# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "../../../test_helper"
require_relative "../../../../examples/tutorial/02/app"

describe Tutorial02::FileBrowser::Init do
  it "sets current_directory from Dir.pwd" do
    Dir.stub :pwd, "/test/directory" do
      Dir.stub :children, [] do
        model = Tutorial02::FileBrowser::Init.call

        assert_equal "/test/directory", model.current_directory
      end
    end
  end

  it "loads files from Dir.children" do
    mock_files = ["README.md", "Gemfile", "lib", "test"]

    Dir.stub :pwd, "/test/directory" do
      Dir.stub :children, mock_files do
        model = Tutorial02::FileBrowser::Init.call

        assert_equal 4, model.file_names.length
        assert_equal ["README.md", "Gemfile", "lib", "test"], model.file_names
      end
    end
  end

  it "initializes selected_index to 0" do
    Dir.stub :pwd, "/test" do
      Dir.stub :children, ["a", "b", "c"] do
        model = Tutorial02::FileBrowser::Init.call

        assert_equal 0, model.selected_index
      end
    end
  end

  it "returns a frozen model" do
    Dir.stub :pwd, "/test" do
      Dir.stub :children, [] do
        model = Tutorial02::FileBrowser::Init.call

        assert(model.frozen?)
      end
    end
  end
end
