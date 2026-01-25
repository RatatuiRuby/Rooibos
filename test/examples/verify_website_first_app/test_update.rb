# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require_relative "../../test_helper"
require "rooibos/test_helper"
require_relative "../../../examples/verify_website_first_app/app"

# Unit tests for FileBrowser::Update.
#
# Update is where all your logic lives. Test it without a terminal.
# Fast, focused, no I/O.
class TestFileBrowserUpdate < Minitest::Test
  include Rooibos::TestHelper

  # --- Exit commands ---

  def test_exits_on_q
    model = make_model(entries: %w[a b c], selected: "a")
    message = RatatuiRuby::Event::Key.new(code: "q")

    result = FileBrowser::Update.call(message, model)

    assert_instance_of Rooibos::Command::Exit, result
  end

  def test_exits_on_ctrl_c
    model = make_model(entries: %w[a b c], selected: "a")
    message = RatatuiRuby::Event::Key.new(code: "c", modifiers: ["ctrl"])

    result = FileBrowser::Update.call(message, model)

    assert_instance_of Rooibos::Command::Exit, result
  end

  # --- Navigation: vim keys ---

  def test_moves_selection_down_with_j
    model = make_model(entries: %w[a b c], selected: "a")
    message = RatatuiRuby::Event::Key.new(code: "j")

    result = FileBrowser::Update.call(message, model)

    assert_equal "b", result.selected
  end

  def test_moves_selection_up_with_k
    model = make_model(entries: %w[a b c], selected: "b")
    message = RatatuiRuby::Event::Key.new(code: "k")

    result = FileBrowser::Update.call(message, model)

    assert_equal "a", result.selected
  end

  def test_jumps_to_first_with_g
    model = make_model(entries: %w[a b c], selected: "c")
    message = RatatuiRuby::Event::Key.new(code: "g")

    result = FileBrowser::Update.call(message, model)

    assert_equal "a", result.selected
  end

  def test_jumps_to_last_with_G
    model = make_model(entries: %w[a b c], selected: "a")
    # Capital G: char="G" with shift modifier
    message = RatatuiRuby::Event::Key.new(code: "G", modifiers: ["shift"])

    result = FileBrowser::Update.call(message, model)

    refute_nil result, "Shift+G should be handled"
    assert_equal "c", result.selected
  end

  # --- Navigation: arrow keys ---

  def test_moves_selection_down_with_arrow
    model = make_model(entries: %w[a b c], selected: "a")
    message = RatatuiRuby::Event::Key.new(code: "down")

    result = FileBrowser::Update.call(message, model)

    refute_nil result, "Arrow down should be handled"
    assert_equal "b", result.selected
  end

  def test_moves_selection_up_with_arrow
    model = make_model(entries: %w[a b c], selected: "b")
    message = RatatuiRuby::Event::Key.new(code: "up")

    result = FileBrowser::Update.call(message, model)

    refute_nil result, "Arrow up should be handled"
    assert_equal "a", result.selected
  end

  # --- Boundary clamping ---

  def test_clamps_selection_at_top
    model = make_model(entries: %w[a b c], selected: "a")
    message = RatatuiRuby::Event::Key.new(code: "k")

    result = FileBrowser::Update.call(message, model)

    assert_equal "a", result.selected, "Selection should stay at first item"
  end

  def test_clamps_selection_at_bottom
    model = make_model(entries: %w[a b c], selected: "c")
    message = RatatuiRuby::Event::Key.new(code: "j")

    result = FileBrowser::Update.call(message, model)

    assert_equal "c", result.selected, "Selection should stay at last item"
  end

  # --- File/directory actions ---

  def test_opens_file_with_enter
    Dir.mktmpdir do |dir|
      FileUtils.touch(File.join(dir, "file.txt"))
      model = make_model(path: dir, entries: %w[file.txt], selected: "file.txt")
      message = RatatuiRuby::Event::Key.new(code: "enter")

      result = FileBrowser::Update.call(message, model)

      assert_instance_of Rooibos::Command::Open, result
    end
  end

  def test_navigates_into_directory_with_enter
    Dir.mktmpdir do |dir|
      subdir = File.join(dir, "subdir")
      FileUtils.mkdir(subdir)
      FileUtils.touch(File.join(subdir, "inner.txt"))

      # Model uses trailing slash for directories
      model = make_model(path: dir, entries: %w[subdir/], selected: "subdir/")
      message = RatatuiRuby::Event::Key.new(code: "enter")

      result = FileBrowser::Update.call(message, model)

      assert_equal subdir, result.path
      assert_includes result.entries, "inner.txt"
    end
  end

  def test_navigates_up_with_escape
    Dir.mktmpdir do |dir|
      subdir = File.join(dir, "subdir")
      FileUtils.mkdir(subdir)

      model = make_model(path: subdir, entries: [], selected: nil)
      message = RatatuiRuby::Event::Key.new(code: "escape")

      result = FileBrowser::Update.call(message, model)

      assert_equal dir, result.path
    end
  end

  # --- Error handling ---

  def test_clears_error_on_keypress
    model = make_model(entries: %w[a b], selected: "a", error: "Some error")
    message = RatatuiRuby::Event::Key.new(code: "j")

    result = FileBrowser::Update.call(message, model)

    assert_nil result.error, "Error should be cleared on keypress"
  end

  def test_sets_error_on_error_message
    model = make_model(entries: %w[a b], selected: "a")
    message = Rooibos::Message::Error.new(
      command: :open,
      exception: RuntimeError.new("Failed").freeze
    )

    result = FileBrowser::Update.call(message, model)

    assert_equal FileBrowser::ERROR, result.error
  end

  private

  def make_model(path: "/test", entries: [], selected: nil, error: nil)
    Ractor.make_shareable(
      FileBrowser::Model.new(path:, entries:, selected:, error:)
    )
  end
end
