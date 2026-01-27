# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "../../../test_helper"
require "rooibos/test_helper"
require_relative "../../../../examples/tutorial/02/app"

describe Tutorial02::FileBrowser::Update do
  include Rooibos::TestHelper

  def make_model(file_names: %w[a b c], selected_index: 0)
    Tutorial02::FileBrowser::Model.new(
      current_directory: "/test",
      file_names:,
      selected_index:
    )
  end

  describe "quit behavior" do
    it "exits on q key" do
      model = make_model
      message = RatatuiRuby::Event::Key.new(code: "q")
      result = Tutorial02::FileBrowser::Update.call(message, model)
      assert_instance_of(Rooibos::Command::Exit, result)
    end

    it "exits on Ctrl+C" do
      model = make_model
      message = RatatuiRuby::Event::Key.new(code: "c", modifiers: [:ctrl])
      result = Tutorial02::FileBrowser::Update.call(message, model)
      assert_instance_of(Rooibos::Command::Exit, result)
    end
  end

  describe "arrow key navigation" do
    it "moves selection down with down arrow" do
      model = make_model(selected_index: 0)
      message = RatatuiRuby::Event::Key.new(code: "down")
      result = Tutorial02::FileBrowser::Update.call(message, model)
      assert_equal 1, result.selected_index
    end

    it "moves selection up with up arrow" do
      model = make_model(selected_index: 1)
      message = RatatuiRuby::Event::Key.new(code: "up")
      result = Tutorial02::FileBrowser::Update.call(message, model)
      assert_equal 0, result.selected_index
    end

    it "wraps from bottom to top" do
      model = make_model(selected_index: 2) # last item
      message = RatatuiRuby::Event::Key.new(code: "down")
      result = Tutorial02::FileBrowser::Update.call(message, model)
      assert_equal 0, result.selected_index
    end

    it "wraps from top to bottom" do
      model = make_model(selected_index: 0)
      message = RatatuiRuby::Event::Key.new(code: "up")
      result = Tutorial02::FileBrowser::Update.call(message, model)
      assert_equal 2, result.selected_index
    end
  end

  describe "vim key navigation" do
    it "moves selection down with j" do
      model = make_model(selected_index: 0)
      message = RatatuiRuby::Event::Key.new(code: "j")
      result = Tutorial02::FileBrowser::Update.call(message, model)
      assert_equal 1, result.selected_index
    end

    it "moves selection up with k" do
      model = make_model(selected_index: 1)
      message = RatatuiRuby::Event::Key.new(code: "k")
      result = Tutorial02::FileBrowser::Update.call(message, model)
      assert_equal 0, result.selected_index
    end

    it "wraps with j at bottom" do
      model = make_model(selected_index: 2)
      message = RatatuiRuby::Event::Key.new(code: "j")
      result = Tutorial02::FileBrowser::Update.call(message, model)
      assert_equal 0, result.selected_index
    end

    it "wraps with k at top" do
      model = make_model(selected_index: 0)
      message = RatatuiRuby::Event::Key.new(code: "k")
      result = Tutorial02::FileBrowser::Update.call(message, model)
      assert_equal 2, result.selected_index
    end
  end

  describe "unhandled keys" do
    it "returns unchanged model for unhandled keys" do
      model = make_model
      message = RatatuiRuby::Event::Key.new(code: "x")
      result = Tutorial02::FileBrowser::Update.call(message, model)
      assert_equal(model, result)
    end
  end

  describe "jump navigation" do
    it "jumps to first item with Home" do
      model = make_model(selected_index: 2)
      message = RatatuiRuby::Event::Key.new(code: "home")
      result = Tutorial02::FileBrowser::Update.call(message, model)
      assert_equal 0, result.selected_index
    end

    it "jumps to first item with g" do
      model = make_model(selected_index: 2)
      message = RatatuiRuby::Event::Key.new(code: "g")
      result = Tutorial02::FileBrowser::Update.call(message, model)
      assert_equal 0, result.selected_index
    end

    it "jumps to last item with End" do
      model = make_model(selected_index: 0)
      message = RatatuiRuby::Event::Key.new(code: "end")
      result = Tutorial02::FileBrowser::Update.call(message, model)
      assert_equal 2, result.selected_index
    end

    it "jumps to last item with G" do
      model = make_model(selected_index: 0)
      message = RatatuiRuby::Event::Key.new(code: "G", modifiers: ["shift"])
      result = Tutorial02::FileBrowser::Update.call(message, model)
      assert_equal 2, result.selected_index
    end
  end
end
