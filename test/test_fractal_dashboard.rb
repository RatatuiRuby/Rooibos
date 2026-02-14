# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "test_helper"
require_relative "../examples/app_fractal_dashboard/dashboard/update_manual"

class TestFractalDashboard < Minitest::Test
  def test_update_routes_system_info_batch_to_stats
    model = DashboardManual::Init.()
    batch = Rooibos::Message::System::Batch.new(
      envelope: :system_info,
      stdout: "Darwin\n",
      stderr: "",
      status: 0
    )

    new_model, cmd = DashboardManual::Update.call(batch, model)

    assert_equal "Darwin", new_model.stats.system_info.output
    assert_nil cmd
  end

  def test_update_routes_ping_batch_to_network
    model = DashboardManual::Init.()
    batch = Rooibos::Message::System::Batch.new(
      envelope: :ping,
      stdout: "PING localhost\n",
      stderr: "",
      status: 0
    )

    new_model, cmd = DashboardManual::Update.call(batch, model)

    assert_equal "PING localhost", new_model.network.ping.output
    assert_nil cmd
  end

  def test_s_key_triggers_system_info_command
    model = DashboardManual::Init.()
    msg = RatatuiRuby::Event::Key.new(code: "s", modifiers: [])

    new_model, cmd = DashboardManual::Update.call(msg, model)

    assert new_model.stats.system_info.loading, "Should set loading state"
    assert_kind_of Rooibos::Command::System, cmd
    assert_equal :system_info, cmd.envelope
  end

  def test_p_key_triggers_ping_command
    model = DashboardManual::Init.()
    msg = RatatuiRuby::Event::Key.new(code: "p", modifiers: [])

    new_model, cmd = DashboardManual::Update.call(msg, model)

    assert new_model.network.ping.loading, "Should set loading state"
    assert_kind_of Rooibos::Command::System, cmd
    assert_equal :ping, cmd.envelope
  end

  def test_stream_messages_route_to_modal
    model = DashboardManual::Init.()
    # Activate the modal first
    model = model.with(shell_modal: CustomShellModal.open)
    # Transition from input to output mode
    output = CustomShellOutput::Init.().with(command: "echo hi", running: true)
    model = model.with(shell_modal: model.shell_modal.with(mode: :output, output:))

    stream_msg = Rooibos::Message::System::Stream.new(
      envelope: :shell_output,
      stream: :stdout,
      content: "hi\n",
      status: nil
    )

    new_model, _cmd = DashboardManual::Update.call(stream_msg, model)

    assert_equal 1, new_model.shell_modal.output.chunks.length
    assert_equal "hi\n", new_model.shell_modal.output.chunks.first.text
  end
end
