# frozen_string_literal: true

require "test_helper"

class TestFileBrowser < Minitest::Test
  include Rooibos::TestHelper

  def test_it_displays_file_list
    with_test_terminal do
      inject_key(:q)
      Rooibos.run(FileBrowser)
      assert_snapshots("file_list")
    end
  end

  def test_it_exits_with_ctrl_c
    with_test_terminal do
      inject_key(:ctrl_c)
      Rooibos.run(FileBrowser)
      assert_snapshots("file_list")
    end
  end

  def test_selection_moves_down_with_arrow
    with_test_terminal do
      inject_key(:down)
      inject_key(:q)
      Rooibos.run(FileBrowser)
      assert_snapshots("selection_down_arrow")
    end
  end

  def test_selection_moves_down_with_j
    with_test_terminal do
      inject_key(:j)
      inject_key(:ctrl_c)
      Rooibos.run(FileBrowser)
      assert_snapshots("selection_down_j")
    end
  end

  def test_selection_moves_up_with_arrow
    with_test_terminal do
      inject_key(:down)
      inject_key(:down)
      inject_key(:up)
      inject_key(:q)
      Rooibos.run(FileBrowser)
      assert_snapshots("selection_up_arrow")
    end
  end

  def test_selection_moves_up_with_k
    with_test_terminal do
      inject_key(:down)
      inject_key(:down)
      inject_key(:k)
      inject_key(:ctrl_c)
      Rooibos.run(FileBrowser)
      assert_snapshots("selection_up_k")
    end
  end

  def test_selection_wraps_at_bottom
    with_test_terminal do
      4.times { inject_key(:down) }
      inject_key(:q)
      Rooibos.run(FileBrowser)
      assert_snapshots("selection_wraps_bottom")
    end
  end

  def test_selection_wraps_at_top
    with_test_terminal do
      inject_key(:up)
      inject_key(:ctrl_c)
      Rooibos.run(FileBrowser)
      assert_snapshots("selection_wraps_top")
    end
  end

  def test_jumps_to_last_with_end
    with_test_terminal do
      inject_key(:end)
      inject_key(:q)
      Rooibos.run(FileBrowser)
      assert_snapshots("jump_to_last_end")
    end
  end

  def test_jumps_to_last_with_shift_g
    with_test_terminal do
      inject_key(:shift_g)
      inject_key(:ctrl_c)
      Rooibos.run(FileBrowser)
      assert_snapshots("jump_to_last_shift_g")
    end
  end

  def test_jumps_to_first_with_home
    with_test_terminal do
      inject_key(:end)
      inject_key(:home)
      inject_key(:q)
      Rooibos.run(FileBrowser)
      assert_snapshots("jump_to_first_home")
    end
  end

  def test_jumps_to_first_with_g
    with_test_terminal do
      inject_key(:end)
      inject_key(:g)
      inject_key(:ctrl_c)
      Rooibos.run(FileBrowser)
      assert_snapshots("jump_to_first_g")
    end
  end
end
