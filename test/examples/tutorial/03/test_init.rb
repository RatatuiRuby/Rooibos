# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "../../../test_helper"
require_relative "../../../../examples/tutorial/03/app"

describe Tutorial03::FileBrowser::Init do
  it "sets current_directory from Dir.pwd" do
    Dir.stub :pwd, "/test/directory" do
      Tutorial03::FileBrowser::ReadEntries.stub(:call, []) do
        model = Tutorial03::FileBrowser::Init.call

        assert_equal "/test/directory", model.current_directory
      end
    end
  end

  it "loads entries from ReadEntries" do
    mock_entries = [
      Tutorial03::FileBrowser::Entry.new(name: "lib", directory?: true),
      Tutorial03::FileBrowser::Entry.new(name: "README.md", directory?: false),
    ]

    Dir.stub :pwd, "/test/directory" do
      Tutorial03::FileBrowser::ReadEntries.stub(:call, mock_entries) do
        model = Tutorial03::FileBrowser::Init.call

        assert_equal 2, model.entries.length
        assert_equal "lib", model.entries[0].name
        assert model.entries[0].directory?
        refute model.entries[1].directory?
      end
    end
  end

  it "initializes selected_index to 0" do
    Dir.stub :pwd, "/test" do
      Tutorial03::FileBrowser::ReadEntries.stub(:call, []) do
        model = Tutorial03::FileBrowser::Init.call

        assert_equal 0, model.selected_index
      end
    end
  end

  it "returns a frozen model" do
    Dir.stub :pwd, "/test" do
      Tutorial03::FileBrowser::ReadEntries.stub(:call, []) do
        model = Tutorial03::FileBrowser::Init.call

        assert(model.frozen?)
      end
    end
  end
end
