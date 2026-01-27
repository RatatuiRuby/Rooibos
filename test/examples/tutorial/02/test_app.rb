# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "../../../test_helper"
require "rooibos/test_helper"
require_relative "../../../../examples/tutorial/02/app"

describe "Tutorial02::FileBrowser integration" do
  include Rooibos::TestHelper

  it "displays current directory path" do
    with_test_terminal do
      inject_key(:q)
      Rooibos.run(Tutorial02::FileBrowser)

      buffer = buffer_content.join("\n")
      current_dir = Dir.pwd
      _(buffer).must_include current_dir
    end
  end

  it "displays file names from current directory" do
    with_test_terminal do
      inject_key(:q)
      Rooibos.run(Tutorial02::FileBrowser)

      buffer = buffer_content.join("\n")
      # Check that directories appear with / suffix (sorted first)
      _(buffer).must_include "bin/"
      _(buffer).must_include "doc/"
    end
  end

  it "quits with q key" do
    with_test_terminal do
      inject_key(:q)
      Rooibos.run(Tutorial02::FileBrowser)
    end
  end

  it "quits with Ctrl+C" do
    with_test_terminal do
      inject_key(:ctrl_c)
      Rooibos.run(Tutorial02::FileBrowser)
    end
  end

  it "navigates down with arrow key" do
    with_test_terminal do
      inject_key(:down)
      inject_key(:q)
      Rooibos.run(Tutorial02::FileBrowser)
      # Test passes if no hang/crash
    end
  end

  it "navigates with vim keys" do
    with_test_terminal do
      inject_key(:j)
      inject_key(:k)
      inject_key(:q)
      Rooibos.run(Tutorial02::FileBrowser)
      # Test passes if no hang/crash
    end
  end
end
