# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "../../test_helper"
require_relative "../../../examples/app_file_browser/app"

describe FileBrowser::Init do
  it "sets current_directory from Dir.pwd" do
    Dir.stub :pwd, "/test/directory" do
      Dir.stub :children, [] do
        model = FileBrowser::Init.call

        assert_equal "/test/directory", model.current_directory
      end
    end
  end

  it "loads files from Dir.children" do
    mock_files = ["README.md", "Gemfile", "lib", "test"]

    Dir.stub :pwd, "/test/directory" do
      Dir.stub :children, mock_files do
        model = FileBrowser::Init.call

        assert_equal 4, model.file_names.length
        assert_equal ["README.md", "Gemfile", "lib", "test"], model.file_names
      end
    end
  end

  it "creates file entries with name attribute" do
    Dir.stub :pwd, "/test" do
      Dir.stub :children, ["example.txt"] do
        model = FileBrowser::Init.call

        file = model.file_names.first
        assert_equal "example.txt", file
      end
    end
  end

  it "returns a frozen model" do
    Dir.stub :pwd, "/test" do
      Dir.stub :children, [] do
        model = FileBrowser::Init.call

        assert(model.frozen?)
      end
    end
  end
end
