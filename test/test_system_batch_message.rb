# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestSystemBatchMessage < Minitest::Test
  include Rooibos::TestHelper

  # Class-scope callables for Ractor shareability
  @@messages = []

  def teardown
    @@messages = []
  end

  View = -> (_m, t) { t.clear }

  Update = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "s" then [m, Rooibos::Command.system("echo hello", :build)]
      when "q" then [m, Rooibos::Command.exit]
      else [m, nil]
      end
    else
      @@messages << msg
      [m, nil]
    end
  end

  def test_system_batch_emits_message_not_array
    @@messages = []
    model = Ractor.make_shareable({})

    require "open3"
    mock_status = Object.new
    mock_status.define_singleton_method(:exitstatus) { 0 }
    Open3.stub(:capture3, ["hello\n", "", mock_status]) do
      with_test_terminal do
        inject_key("s")
        inject_sync
        inject_key("q")
        Rooibos::Runtime.run(model:, view: View, update: Update)
      end
    end

    assert_no_errors(@@messages)

    # Should receive Message::System::Batch, not array
    batch_msg = @@messages.find { |m| m.is_a?(Rooibos::Message::System::Batch) }
    refute_nil batch_msg, "Should receive System::Batch message"
    assert_equal :build, batch_msg.envelope
    assert_equal "hello\n", batch_msg.stdout
    assert_equal "", batch_msg.stderr
    assert_equal 0, batch_msg.status
  end
end
