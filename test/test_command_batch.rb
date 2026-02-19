# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestCommandBatch < Minitest::Test
  def test_batch_creates_batch_command
    cmd1 = Rooibos::Command.wait(1.0, :a)
    cmd2 = Rooibos::Command.wait(1.0, :b)

    result = Rooibos::Command.batch(cmd1, cmd2)

    assert_kind_of Rooibos::Command::Batch, result
    assert_equal 2, result.commands.size
  end

  def test_batch_accepts_array_form
    cmd1 = Rooibos::Command.wait(1.0, :a)
    cmd2 = Rooibos::Command.wait(1.0, :b)

    result = Rooibos::Command.batch([cmd1, cmd2])

    assert_equal 2, result.commands.size
  end

  def test_batch_is_ractor_shareable
    cmd1 = Rooibos::Command.wait(1.0, :a)
    cmd2 = Rooibos::Command.wait(1.0, :b)

    result = Rooibos::Command.batch(cmd1, cmd2)

    assert Ractor.shareable?(result), "Command::Batch should be Ractor-shareable"
  end
end
