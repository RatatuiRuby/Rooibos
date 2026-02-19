# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/welcome"
require "rooibos/test_helper"

# Unit tests for the built-in Welcome module used by scaffolded apps.
class TestWelcome < Minitest::Test
  include Rooibos::TestHelper

  def test_init_returns_shareable_model
    with_test_terminal do
      model = Rooibos::Welcome::Init.call

      assert_kind_of Rooibos::Welcome::Model, model
      # Must be Ractor-shareable for the runtime
      assert Ractor.shareable?(model), "Model must be Ractor-shareable"
    end
  end

  def test_update_exits_on_ctrl_c
    with_test_terminal do
      model = Rooibos::Welcome::Init.call
      ctrl_c = RatatuiRuby::Event::Key.new(code: "c", modifiers: ["ctrl"])

      result = Rooibos::Welcome::Update.call(ctrl_c, model)

      assert_kind_of Rooibos::Command::Exit, result
    end
  end

  def test_update_returns_model_on_other_keys
    with_test_terminal do
      model = Rooibos::Welcome::Init.call
      letter_a = RatatuiRuby::Event::Key.new(code: "a")

      result = Rooibos::Welcome::Update.call(letter_a, model)

      assert_same model, result
    end
  end

  def test_view_renders_welcome_content
    with_test_terminal do
      inject_key(:ctrl_c)
      Rooibos.run(Rooibos::Welcome)

      # Strip box-drawing and normalize whitespace
      buffer = buffer_content.join(" ").gsub(/[─│┌┐└┘├┤┬┴┼]/, " ").squeeze(" ")

      # All expected text elements
      expected_words = %w[
        Hello
        Rooibos
        Welcome
        Ruby
        code
        application
        lib/rooibos/welcome.rb
        tests
        test/test_welcome.rb
        bundle
        exec
        rake
        test
        www.rooibos.run
        Control
      ]

      expected_words.each do |word|
        assert_includes buffer, word, "Expected '#{word}' in buffer"
      end
    end
  end

  def test_view_renders_buttons
    with_test_terminal do
      inject_key(:ctrl_c)
      Rooibos.run(Rooibos::Welcome)

      buffer = buffer_content.join(" ")
      assert_includes buffer, "Visit Website"
      assert_includes buffer, "Exit App"
    end
  end

  def test_update_cycles_focus_on_tab
    with_test_terminal do
      model = Rooibos::Welcome::Init.call
      tab = RatatuiRuby::Event::Key.new(code: "tab")

      # First Tab focuses first button
      model = Rooibos::Welcome::Update.call(tab, model)
      assert_equal :website, model.focused

      # Second Tab focuses second button
      model = Rooibos::Welcome::Update.call(tab, model)
      assert_equal :exit, model.focused

      # Third Tab wraps to first button
      model = Rooibos::Welcome::Update.call(tab, model)
      assert_equal :website, model.focused
    end
  end

  def test_enter_on_exit_button_exits
    with_test_terminal do
      model = Rooibos::Welcome::Init.call
      tab = RatatuiRuby::Event::Key.new(code: "tab")
      enter = RatatuiRuby::Event::Key.new(code: "enter")

      # Tab twice to focus Exit button
      model = Rooibos::Welcome::Update.call(tab, model)
      model = Rooibos::Welcome::Update.call(tab, model)
      assert_equal :exit, model.focused

      # Enter should exit
      result = Rooibos::Welcome::Update.call(enter, model)
      assert_kind_of Rooibos::Command::Exit, result
    end
  end

  def test_enter_on_website_button_opens_url
    with_test_terminal do
      model = Rooibos::Welcome::Init.call
      tab = RatatuiRuby::Event::Key.new(code: "tab")
      enter = RatatuiRuby::Event::Key.new(code: "enter")

      # Tab once to focus Website button
      model = Rooibos::Welcome::Update.call(tab, model)
      assert_equal :website, model.focused

      # Enter should return [model, Command.system]
      result = Rooibos::Welcome::Update.call(enter, model)
      assert_kind_of Array, result
      assert_equal model, result[0]
      assert_kind_of Rooibos::Command::System, result[1]
      assert_includes result[1].command, "https://www.rooibos.run"
    end
  end

  def test_update_cycles_focus_backward_on_shift_tab
    with_test_terminal do
      model = Rooibos::Welcome::Init.call
      tab = RatatuiRuby::Event::Key.new(code: "tab")
      shift_tab = RatatuiRuby::Event::Key.new(code: "back_tab", modifiers: ["shift"])

      # Tab to focus first button, then Tab again to focus second
      model = Rooibos::Welcome::Update.call(tab, model)
      model = Rooibos::Welcome::Update.call(tab, model)
      assert_equal :exit, model.focused

      # Shift+Tab should go back to first button
      model = Rooibos::Welcome::Update.call(shift_tab, model)
      assert_equal :website, model.focused
    end
  end

  def test_update_handles_resize
    with_test_terminal do
      model = Rooibos::Welcome::Init.call
      resize = RatatuiRuby::Event::Resize.new(width: 100, height: 50)

      result = Rooibos::Welcome::Update.call(resize, model)

      # Resize should update button_areas to new dimensions
      assert_respond_to result, :button_areas
      refute_nil result.button_areas
    end
  end

  def test_mouse_hover_sets_hovered_state
    with_test_terminal(80, 24) do
      model = Rooibos::Welcome::Init.call
      # Get button area for exit button and hover over it
      exit_area = model.button_areas.exit
      hover = RatatuiRuby::Event::Mouse.new(
        button: nil,
        kind: "moved",
        x: exit_area.x + 1,
        y: exit_area.y,
        modifiers: []
      )

      # Unit: Update sets hovered state
      result = Rooibos::Welcome::Update.call(hover, model)
      assert_equal :exit, result.hovered

      # Integration: View renders hovered button with reversed style
      RatatuiRuby.draw { |f| f.render_widget(Rooibos::Welcome::View.call(result, nil), f.area) }

      # Exit button should have reversed modifier when hovered
      assert_reversed(exit_area.x + 1, exit_area.y)
    end
  end
end
