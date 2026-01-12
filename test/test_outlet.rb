# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "ratatui_ruby/test_helper"
require "concurrent-edge"

class TestOutlet < Minitest::Test
  include RatatuiRuby::TestHelper
  def test_put_pushes_message_to_channel
    channel = Concurrent::Promises::Channel.new
    outlet = RatatuiRuby::Tea::Command::Outlet.new(channel)

    outlet.put(:hello, :world)

    assert_equal [:hello, :world], channel.pop
  end

  def test_put_raises_in_debug_mode_for_non_shareable_payload
    channel = Concurrent::Promises::Channel.new
    outlet = RatatuiRuby::Tea::Command::Outlet.new(channel)
    mutable_hash = { data: "not frozen" } # NOT Ractor-shareable

    error = assert_raises(RatatuiRuby::Error::Invariant) do
      outlet.put(:bad, mutable_hash)
    end

    assert_match(/ractor|shareable/i, error.message)
  end

  def test_put_allows_non_shareable_in_production_mode
    channel = Concurrent::Promises::Channel.new
    outlet = RatatuiRuby::Tea::Command::Outlet.new(channel)
    mutable_hash = { data: "not frozen" }

    RatatuiRuby::Debug.suppress_debug_mode do
      outlet.put(:ok, mutable_hash) # Should NOT raise
    end

    assert_equal [:ok, mutable_hash], channel.pop
  end
end
