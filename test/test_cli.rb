# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "open3"
require "tmpdir"
require "fileutils"

class TestCLI < Minitest::Test
  def rooibos(*)
    exe = File.expand_path("../exe/rooibos", __dir__)
    Open3.capture3("bundle", "exec", exe, *)
  end

  def test_version_flag
    stdout, _stderr, status = rooibos("--version")

    assert status.success?
    assert_match(/Rooibos \d+\.\d+\.\d+/, stdout)
  end

  def test_short_version_flag
    stdout, _stderr, status = rooibos("-v")

    assert status.success?
    assert_match(/Rooibos \d+\.\d+\.\d+/, stdout)
  end

  def test_help_flag
    stdout, _stderr, status = rooibos("--help")

    assert status.success?
    assert_includes stdout, "Usage: rooibos"
    assert_includes stdout, "new <appname>"
    assert_includes stdout, "run"
  end

  def test_short_help_flag
    stdout, _stderr, status = rooibos("-h")

    assert status.success?
    assert_includes stdout, "Usage: rooibos"
  end

  def test_no_args_shows_help
    stdout, _stderr, status = rooibos

    assert status.success?
    assert_includes stdout, "Usage: rooibos"
  end

  def test_unknown_command_exits_with_error
    _stdout, stderr, status = rooibos("unknown")

    refute status.success?
    assert_includes stderr, "Unknown command: unknown"
  end

  def test_new_help
    stdout, _stderr, status = rooibos("new", "--help")

    assert status.success?
    assert_includes stdout, "Usage: rooibos new"
    assert_includes stdout, "bundle gem"
  end

  def test_new_without_appname_exits_with_error
    _stdout, stderr, status = rooibos("new")

    refute status.success?
    assert_includes stderr, "Missing application name"
  end

  def test_run_help
    stdout, _stderr, status = rooibos("run", "--help")

    assert status.success?
    assert_includes stdout, "Usage: rooibos run"
    assert_includes stdout, "current directory"
  end

  def test_run_outside_project_exits_with_error
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        _stdout, stderr, status = rooibos("run")

        refute status.success?
        assert_includes stderr, "Not in a Rooibos project"
      end
    end
  end
end
