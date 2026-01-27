# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "../../../test_helper"
require "rooibos/test_helper"
require_relative "../../../../examples/tutorial/03/app"

describe Tutorial03::FileBrowser::Update do
  include Rooibos::TestHelper

  def make_entries(*names)
    names.map { |n| Tutorial03::FileBrowser::Entry.new(name: n, directory?: false) }
  end

  def make_model(entries: make_entries("a", "b", "c"), selected_index: 0)
    Tutorial03::FileBrowser::Model.new(
      current_directory: "/test",
      entries:,
      selected_index:
    )
  end

  describe "quit behavior" do
    it "exits on q key" do
      model = make_model
      message = RatatuiRuby::Event::Key.new(code: "q")
      result = Tutorial03::FileBrowser::Update.call(message, model)
      assert_instance_of(Rooibos::Command::Exit, result)
    end

    it "exits on Ctrl+C" do
      model = make_model
      message = RatatuiRuby::Event::Key.new(code: "c", modifiers: [:ctrl])
      result = Tutorial03::FileBrowser::Update.call(message, model)
      assert_instance_of(Rooibos::Command::Exit, result)
    end
  end

  describe "arrow key navigation" do
    it "moves selection down with down arrow" do
      model = make_model(selected_index: 0)
      message = RatatuiRuby::Event::Key.new(code: "down")
      result = Tutorial03::FileBrowser::Update.call(message, model)
      assert_equal 1, result.selected_index
    end

    it "moves selection up with up arrow" do
      model = make_model(selected_index: 1)
      message = RatatuiRuby::Event::Key.new(code: "up")
      result = Tutorial03::FileBrowser::Update.call(message, model)
      assert_equal 0, result.selected_index
    end

    it "wraps from bottom to top" do
      model = make_model(selected_index: 2) # last item
      message = RatatuiRuby::Event::Key.new(code: "down")
      result = Tutorial03::FileBrowser::Update.call(message, model)
      assert_equal 0, result.selected_index
    end

    it "wraps from top to bottom" do
      model = make_model(selected_index: 0)
      message = RatatuiRuby::Event::Key.new(code: "up")
      result = Tutorial03::FileBrowser::Update.call(message, model)
      assert_equal 2, result.selected_index
    end
  end

  describe "vim key navigation" do
    it "moves selection down with j" do
      model = make_model(selected_index: 0)
      message = RatatuiRuby::Event::Key.new(code: "j")
      result = Tutorial03::FileBrowser::Update.call(message, model)
      assert_equal 1, result.selected_index
    end

    it "moves selection up with k" do
      model = make_model(selected_index: 1)
      message = RatatuiRuby::Event::Key.new(code: "k")
      result = Tutorial03::FileBrowser::Update.call(message, model)
      assert_equal 0, result.selected_index
    end

    it "wraps with j at bottom" do
      model = make_model(selected_index: 2)
      message = RatatuiRuby::Event::Key.new(code: "j")
      result = Tutorial03::FileBrowser::Update.call(message, model)
      assert_equal 0, result.selected_index
    end

    it "wraps with k at top" do
      model = make_model(selected_index: 0)
      message = RatatuiRuby::Event::Key.new(code: "k")
      result = Tutorial03::FileBrowser::Update.call(message, model)
      assert_equal 2, result.selected_index
    end
  end

  describe "unhandled keys" do
    it "returns unchanged model for unhandled keys" do
      model = make_model
      message = RatatuiRuby::Event::Key.new(code: "x")
      result = Tutorial03::FileBrowser::Update.call(message, model)
      assert_equal(model, result)
    end
  end

  describe "jump navigation" do
    it "jumps to first item with Home" do
      model = make_model(selected_index: 2)
      message = RatatuiRuby::Event::Key.new(code: "home")
      result = Tutorial03::FileBrowser::Update.call(message, model)
      assert_equal 0, result.selected_index
    end

    it "jumps to first item with g" do
      model = make_model(selected_index: 2)
      message = RatatuiRuby::Event::Key.new(code: "g")
      result = Tutorial03::FileBrowser::Update.call(message, model)
      assert_equal 0, result.selected_index
    end

    it "jumps to last item with End" do
      model = make_model(selected_index: 0)
      message = RatatuiRuby::Event::Key.new(code: "end")
      result = Tutorial03::FileBrowser::Update.call(message, model)
      assert_equal 2, result.selected_index
    end

    it "jumps to last item with G" do
      model = make_model(selected_index: 0)
      message = RatatuiRuby::Event::Key.new(code: "G", modifiers: ["shift"])
      result = Tutorial03::FileBrowser::Update.call(message, model)
      assert_equal 2, result.selected_index
    end
  end

  describe "directory navigation" do
    def make_dir_entry(name)
      Tutorial03::FileBrowser::Entry.new(name:, directory?: true)
    end

    def make_file_entry(name)
      Tutorial03::FileBrowser::Entry.new(name:, directory?: false)
    end

    it "changes current_directory when Enter pressed on directory" do
      entries = [make_dir_entry("subdir"), make_file_entry("file.txt")]
      model = make_model(entries:, selected_index: 0)
      message = RatatuiRuby::Event::Key.new(code: "enter")

      # Stub ReadEntries to avoid filesystem access
      stub_entries = [make_file_entry("inner.txt")]
      Tutorial03::FileBrowser::ReadEntries.stub(:call, stub_entries) do
        result = Tutorial03::FileBrowser::Update.call(message, model)

        assert_equal "/test/subdir", result.current_directory
        assert_equal stub_entries, result.entries
      end
    end

    it "does nothing when Enter pressed on regular file" do
      entries = [make_dir_entry("subdir"), make_file_entry("file.txt")]
      model = make_model(entries:, selected_index: 1) # file.txt selected
      message = RatatuiRuby::Event::Key.new(code: "enter")

      result = Tutorial03::FileBrowser::Update.call(message, model)

      assert_equal model, result
    end

    it "goes to parent directory on Backspace" do
      model = Tutorial03::FileBrowser::Model.new(
        current_directory: "/test/subdir",
        entries: [make_file_entry("file.txt")],
        selected_index: 0
      )
      message = RatatuiRuby::Event::Key.new(code: "backspace")

      stub_entries = [make_dir_entry("subdir")]
      Tutorial03::FileBrowser::ReadEntries.stub(:call, stub_entries) do
        result = Tutorial03::FileBrowser::Update.call(message, model)

        assert_equal "/test", result.current_directory
      end
    end

    it "goes to parent directory on left arrow" do
      model = Tutorial03::FileBrowser::Model.new(
        current_directory: "/test/subdir",
        entries: [make_file_entry("file.txt")],
        selected_index: 0
      )
      message = RatatuiRuby::Event::Key.new(code: "left")

      stub_entries = [make_dir_entry("subdir")]
      Tutorial03::FileBrowser::ReadEntries.stub(:call, stub_entries) do
        result = Tutorial03::FileBrowser::Update.call(message, model)

        assert_equal "/test", result.current_directory
      end
    end

    it "goes to parent directory on h" do
      model = Tutorial03::FileBrowser::Model.new(
        current_directory: "/test/subdir",
        entries: [make_file_entry("file.txt")],
        selected_index: 0
      )
      message = RatatuiRuby::Event::Key.new(code: "h")

      stub_entries = [make_dir_entry("subdir")]
      Tutorial03::FileBrowser::ReadEntries.stub(:call, stub_entries) do
        result = Tutorial03::FileBrowser::Update.call(message, model)

        assert_equal "/test", result.current_directory
      end
    end

    it "enters directory on right arrow" do
      entries = [make_dir_entry("subdir"), make_file_entry("file.txt")]
      model = make_model(entries:, selected_index: 0)
      message = RatatuiRuby::Event::Key.new(code: "right")

      stub_entries = [make_file_entry("inner.txt")]
      Tutorial03::FileBrowser::ReadEntries.stub(:call, stub_entries) do
        result = Tutorial03::FileBrowser::Update.call(message, model)

        assert_equal "/test/subdir", result.current_directory
      end
    end

    it "enters directory on l" do
      entries = [make_dir_entry("subdir"), make_file_entry("file.txt")]
      model = make_model(entries:, selected_index: 0)
      message = RatatuiRuby::Event::Key.new(code: "l")

      stub_entries = [make_file_entry("inner.txt")]
      Tutorial03::FileBrowser::ReadEntries.stub(:call, stub_entries) do
        result = Tutorial03::FileBrowser::Update.call(message, model)

        assert_equal "/test/subdir", result.current_directory
      end
    end

    it "jumps to home directory on ~" do
      model = make_model
      message = RatatuiRuby::Event::Key.new(code: "~", modifiers: ["shift"])

      stub_entries = [make_file_entry("home_file.txt")]
      Tutorial03::FileBrowser::ReadEntries.stub(:call, stub_entries) do
        Dir.stub(:home, "/Users/testuser") do
          result = Tutorial03::FileBrowser::Update.call(message, model)

          assert_equal "/Users/testuser", result.current_directory
        end
      end
    end

    it "jumps to root directory on /" do
      model = make_model
      message = RatatuiRuby::Event::Key.new(code: "/")

      stub_entries = [make_dir_entry("bin"), make_dir_entry("etc")]
      Tutorial03::FileBrowser::ReadEntries.stub(:call, stub_entries) do
        result = Tutorial03::FileBrowser::Update.call(message, model)

        assert_equal "/", result.current_directory
      end
    end

    it "refreshes current view on R" do
      original_entries = [make_file_entry("old.txt")]
      model = Tutorial03::FileBrowser::Model.new(
        current_directory: "/test",
        entries: original_entries,
        selected_index: 0
      )
      message = RatatuiRuby::Event::Key.new(code: "R", modifiers: ["shift"])

      refreshed_entries = [make_file_entry("old.txt"), make_file_entry("new.txt")]
      Tutorial03::FileBrowser::ReadEntries.stub(:call, refreshed_entries) do
        result = Tutorial03::FileBrowser::Update.call(message, model)

        assert_equal "/test", result.current_directory
        assert_equal refreshed_entries, result.entries
      end
    end
  end
end
