# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "../../../test_helper"
require "rooibos/test_helper"
require_relative "../../../../examples/tutorial/01/app"

describe "Tutorial01::FileBrowser integration" do
  include Rooibos::TestHelper

  it "displays current directory path" do
    with_test_terminal do
      inject_key(:q)
      Rooibos.run(Tutorial01::FileBrowser)

      buffer = buffer_content.join("\n")
      current_dir = Dir.pwd
      _(buffer).must_include current_dir
    end
  end

  it "displays file names from current directory" do
    with_test_terminal do
      inject_key(:q)
      Rooibos.run(Tutorial01::FileBrowser)

      buffer = buffer_content.join("\n")
      # Check that at least some files from the current directory are displayed
      files = Dir.children(Dir.pwd).first(3)
      files.each do |file|
        _(buffer).must_include file
      end
    end
  end

  it "quits with q key without hanging" do
    with_test_terminal do
      inject_key(:q)
      Rooibos.run(Tutorial01::FileBrowser)
    end
  end

  it "quits with Ctrl+C without hanging" do
    with_test_terminal do
      inject_key(:ctrl_c)
      Rooibos.run(Tutorial01::FileBrowser)
    end
  end
end
