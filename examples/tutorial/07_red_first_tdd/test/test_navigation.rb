# frozen_string_literal: true

require "test_helper"

class TestEnterDirectory < Minitest::Test
  include TestDirectoryHelper

  def test_enter_navigates_into_directory
    with_example_files do
      model = FileBrowser::FileList::Init.call

      result, _command = FileBrowser::FileList::Update.call(routed(:enter_directory), model)

      assert_equal File.join(Dir.pwd, "lib"), result.path
      assert_equal 0, result.selected_index
      assert_equal ["file_browser.rb"], result.entries.map(&:name)
    end
  end

  def test_enter_does_nothing_on_file
    with_example_files do
      model = FileBrowser::FileList::Init.call
      model = model.with(selected_index: 2) # Gemfile

      result, _command = FileBrowser::FileList::Update.call(routed(:enter_directory), model)

      assert_equal Dir.pwd, result.path
      assert_equal model, result
    end
  end

  def test_enter_resets_selection_to_first
    with_example_files do
      model = FileBrowser::FileList::Init.call
      model = model.with(selected_index: 3) # README.md is last, so select something else

      # Move to test/ (index 1) which is a directory
      model = model.with(selected_index: 1)

      result, _command = FileBrowser::FileList::Update.call(routed(:enter_directory), model)

      assert_equal 0, result.selected_index
    end
  end
end

class TestGoParent < Minitest::Test
  include TestDirectoryHelper

  def test_backspace_goes_to_parent_directory
    with_example_files do
      model = FileBrowser::FileList::Init.call
      model, _command = FileBrowser::FileList::Update.call(routed(:enter_directory), model)

      result, _command = FileBrowser::FileList::Update.call(routed(:go_parent), model)

      assert_equal Dir.pwd, result.path
      entry_names = result.entries.map(&:name)
      assert_includes entry_names, "lib"
      assert_includes entry_names, "Gemfile"
    end
  end

  def test_backspace_does_nothing_at_root
    Dir.stub(:pwd, "/") do
      model = FileBrowser::FileList::Init.call

      result, _command = FileBrowser::FileList::Update.call(routed(:go_parent), model)

      assert_equal "/", result.path
      assert_equal model, result
    end
  end

  def test_backspace_resets_selection_to_first
    with_example_files do
      model = FileBrowser::FileList::Init.call
      model, _command = FileBrowser::FileList::Update.call(routed(:enter_directory), model)

      result, _command = FileBrowser::FileList::Update.call(routed(:go_parent), model)

      assert_equal 0, result.selected_index
    end
  end
end
