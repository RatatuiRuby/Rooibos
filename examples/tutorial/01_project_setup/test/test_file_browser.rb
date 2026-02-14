# frozen_string_literal: true

require "test_helper"

class TestFileBrowser < Minitest::Test
  include Rooibos::TestHelper

  def test_it_exits_with_ctrl_c
    with_test_terminal do
      inject_key(:ctrl_c)
      Rooibos.run(FileBrowser)
      assert true, "Should reach this point without hanging."
    end
  end
end
