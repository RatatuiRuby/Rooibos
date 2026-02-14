# frozen_string_literal: true

require "test_helper"

class TestInit < Minitest::Test
  def test_returns_model_with_four_entries
    model = FileBrowser::Init.call
    assert_equal 4, model.entries.length
  end

  def test_starts_at_selected_index_zero
    model = FileBrowser::Init.call
    assert_equal 0, model.selected_index
  end

  def test_returns_frozen_model
    model = FileBrowser::Init.call
    assert model.frozen?
  end
end
