# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "ratatui_ruby/test_helper"
require "rooibos/test_helper"

class TestBuiltinCommandProtocol < Minitest::Test
  include RatatuiRuby::TestHelper

  CUSTOM_CALLABLE = Ractor.make_shareable(-> (out, _token) { out.put(:done) })

  def test_command_exit_has_protocol
    cmd = Rooibos::Command.exit
    validate_rooibos_command!(cmd)
  end

  def test_command_system_has_protocol
    cmd = Rooibos::Command.system("echo test", :result)
    validate_rooibos_command!(cmd)
  end

  def test_command_http_has_protocol
    cmd = Rooibos::Command.http(:get, "https://example.com", :data)
    validate_rooibos_command!(cmd)
  end

  def test_command_wait_has_protocol
    cmd = Rooibos::Command.wait(1.0, :timer)
    validate_rooibos_command!(cmd)
  end

  def test_command_tick_has_protocol
    cmd = Rooibos::Command.tick(1.0, :tick)
    validate_rooibos_command!(cmd)
  end

  def test_command_batch_has_protocol
    cmd1 = Rooibos::Command.wait(1.0, :t1)
    cmd2 = Rooibos::Command.wait(1.0, :t2)
    batch = Rooibos::Command.batch(cmd1, cmd2)
    validate_rooibos_command!(batch)
  end

  def test_command_all_has_protocol
    cmd1 = Rooibos::Command.wait(1.0, :t1)
    cmd2 = Rooibos::Command.wait(1.0, :t2)
    all_cmd = Rooibos::Command.all(:results, cmd1, cmd2)
    validate_rooibos_command!(all_cmd)
  end

  def test_command_map_has_protocol
    inner = Rooibos::Command.wait(1.0, :inner)
    mapped = Rooibos::Command.map(inner) { |msg| [:outer, msg] }
    validate_rooibos_command!(mapped)
  end

  def test_command_custom_has_protocol
    custom = Rooibos::Command.custom(CUSTOM_CALLABLE)
    validate_rooibos_command!(custom)
  end

  def test_command_cancel_has_protocol
    handle = Rooibos::Command.wait(1.0, :timer)
    cancel = Rooibos::Command.cancel(handle)
    validate_rooibos_command!(cancel)
  end
end
