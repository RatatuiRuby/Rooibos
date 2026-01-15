# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "ratatui_ruby/test_helper"
require "ratatui_ruby/tea/test_helper"

class TestBuiltinCommandProtocol < Minitest::Test
  include RatatuiRuby::TestHelper

  CUSTOM_CALLABLE = Ractor.make_shareable(-> (out, _token) { out.put(:done) })

  def test_command_exit_has_protocol
    cmd = RatatuiRuby::Tea::Command.exit
    validate_tea_command!(cmd)
  end

  def test_command_system_has_protocol
    cmd = RatatuiRuby::Tea::Command.system("echo test", :result)
    validate_tea_command!(cmd)
  end

  def test_command_http_has_protocol
    cmd = RatatuiRuby::Tea::Command.http(:get, "https://example.com", :data)
    validate_tea_command!(cmd)
  end

  def test_command_wait_has_protocol
    cmd = RatatuiRuby::Tea::Command.wait(1.0, :timer)
    validate_tea_command!(cmd)
  end

  def test_command_tick_has_protocol
    cmd = RatatuiRuby::Tea::Command.tick(1.0, :tick)
    validate_tea_command!(cmd)
  end

  def test_command_batch_has_protocol
    cmd1 = RatatuiRuby::Tea::Command.wait(1.0, :t1)
    cmd2 = RatatuiRuby::Tea::Command.wait(1.0, :t2)
    batch = RatatuiRuby::Tea::Command.batch(cmd1, cmd2)
    validate_tea_command!(batch)
  end

  def test_command_all_has_protocol
    cmd1 = RatatuiRuby::Tea::Command.wait(1.0, :t1)
    cmd2 = RatatuiRuby::Tea::Command.wait(1.0, :t2)
    all_cmd = RatatuiRuby::Tea::Command.all(:results, cmd1, cmd2)
    validate_tea_command!(all_cmd)
  end

  def test_command_map_has_protocol
    inner = RatatuiRuby::Tea::Command.wait(1.0, :inner)
    mapped = RatatuiRuby::Tea::Command.map(inner) { |msg| [:outer, msg] }
    validate_tea_command!(mapped)
  end

  def test_command_custom_has_protocol
    custom = RatatuiRuby::Tea::Command.custom(CUSTOM_CALLABLE)
    validate_tea_command!(custom)
  end

  def test_command_cancel_has_protocol
    handle = RatatuiRuby::Tea::Command.wait(1.0, :timer)
    cancel = RatatuiRuby::Tea::Command.cancel(handle)
    validate_tea_command!(cancel)
  end
end
