# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "test_helper"
require_relative "../examples/app_fractal_dashboard/dashboard/update_manual"

class TestFractalDashboard < Minitest::Test
  def test_update_routes_stats_panel_message
    model = DashboardManual::Init.()
    batch = Rooibos::Message::System::Batch.new(
      envelope: :system_info,
      stdout: "Darwin\n",
      stderr: "",
      status: 0
    )
    msg = [:stats, batch]

    result = DashboardManual::Update.call(msg, model)

    new_model, cmd = result
    assert_equal "Darwin", new_model.stats.system_info.output
    assert_nil cmd
  end

  def test_update_routes_network_panel_message
    model = DashboardManual::Init.()
    batch = Rooibos::Message::System::Batch.new(
      envelope: :ping,
      stdout: "PING localhost\n",
      stderr: "",
      status: 0
    )
    msg = [:network, batch]

    result = DashboardManual::Update.call(msg, model)

    new_model, cmd = result
    assert_equal "PING localhost", new_model.network.ping.output
    assert_nil cmd
  end

  def test_s_key_triggers_mapped_system_info_command
    model = DashboardManual::Init.()
    msg = RatatuiRuby::Event::Key.new(code: "s", modifiers: [])

    result = DashboardManual::Update.call(msg, model)

    new_model, cmd = result
    assert new_model.stats.system_info.loading, "Should set loading state"
    assert_kind_of Rooibos::Command::Mapped, cmd
    assert_kind_of Rooibos::Command::System, cmd.inner_command
    assert_equal :system_info, cmd.inner_command.envelope
  end

  def test_p_key_triggers_mapped_ping_command
    model = DashboardManual::Init.()
    msg = RatatuiRuby::Event::Key.new(code: "p", modifiers: [])

    result = DashboardManual::Update.call(msg, model)

    new_model, cmd = result
    assert new_model.network.ping.loading, "Should set loading state"
    assert_kind_of Rooibos::Command::Mapped, cmd
    assert_kind_of Rooibos::Command::System, cmd.inner_command
    assert_equal :ping, cmd.inner_command.envelope
  end

  def test_mapper_wraps_with_panel_prefix
    # Verify the mapper transforms the message correctly
    inner_cmd = SystemInfo.fetch_command
    cmd = Rooibos::Command.map(inner_cmd) { |m| [:stats, m] }

    # Simulate what dispatch would produce (System::Batch object)
    inner_msg = Rooibos::Message::System::Batch.new(
      envelope: :system_info,
      stdout: "test",
      stderr: "",
      status: 0
    )
    transformed = cmd.mapper.call(inner_msg)

    assert_equal :stats, transformed[0]
    assert_kind_of Rooibos::Message::System::Batch, transformed[1]
  end
end
