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
end
