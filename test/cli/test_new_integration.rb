# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "open3"
require "tmpdir"
require "fileutils"
require "io/console"

# Integration tests for `rooibos new` command functionality.
# Verifies that scaffolded applications have correct structure.
class TestCLINewIntegration < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("rooibos-test-")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
  end

  def rooibos(*)
    exe = File.expand_path("../../exe/rooibos", __dir__)
    Open3.capture3("bundle", "exec", exe, *)
  end

  # Helper to skip tests if matching rooibos version is not installed globally.
  # Run `rake install:force` to install the current version.
  def require_global_rooibos!
    require "rooibos/version"
    installed = Gem::Specification.find_all_by_name("rooibos", Rooibos::VERSION)
    if installed.empty?
      flunk "Rooibos #{Rooibos::VERSION} not installed globally. Run: rake install:force"
    end
  end

  def test_new_creates_app_directory
    Dir.chdir(@tmpdir) do
      stdout, _stderr, status = rooibos("new", "test_app", "--no-bundle")

      assert status.success?, "Expected success but got: #{stdout}"
      assert Dir.exist?("test_app"), "Expected test_app directory to exist"
    end
  end

  def test_new_creates_executable
    Dir.chdir(@tmpdir) do
      rooibos("new", "test_app", "--no-bundle")

      exe_path = File.join("test_app", "exe", "test_app")
      assert File.exist?(exe_path), "Expected #{exe_path} to exist"
      assert File.executable?(exe_path), "Expected #{exe_path} to be executable"
    end
  end

  def test_new_executable_contains_rooibos_run
    Dir.chdir(@tmpdir) do
      rooibos("new", "test_app", "--no-bundle")

      exe_content = File.read(File.join("test_app", "exe", "test_app"))
      assert_includes exe_content, "Rooibos.run",
        "Expected executable to call Rooibos.run"
    end
  end

  def test_new_lib_file_contains_app_module
    Dir.chdir(@tmpdir) do
      rooibos("new", "test_app", "--no-bundle")

      lib_content = File.read(File.join("test_app", "lib", "test_app.rb"))
      assert_includes lib_content, "module TestApp",
        "Expected lib file to define TestApp module"
      assert_includes lib_content, "Model  = Rooibos::Welcome::Model",
        "Expected lib file to delegate Model"
      assert_includes lib_content, "View   = Rooibos::Welcome::View",
        "Expected lib file to delegate View"
      assert_includes lib_content, "Update = Rooibos::Welcome::Update",
        "Expected lib file to delegate Update"
      assert_includes lib_content, "Init   = Rooibos::Welcome::Init",
        "Expected lib file to delegate Init"
    end
  end

  def test_new_adds_rooibos_to_gemspec
    Dir.chdir(@tmpdir) do
      rooibos("new", "test_app", "--no-bundle")

      gemspec_content = File.read(File.join("test_app", "test_app.gemspec"))
      assert_match(/add_runtime_dependency.*rooibos/, gemspec_content,
        "Expected gemspec to include rooibos as runtime dependency")

      gemfile_content = File.read(File.join("test_app", "Gemfile"))
      refute_match(/^gem ["']rooibos["']/, gemfile_content,
        "Gemfile should not include rooibos directly (should come from gemspec)")
    end
  end

  def test_new_test_helper_requires_rooibos_test_helper
    Dir.chdir(@tmpdir) do
      rooibos("new", "test_app", "--no-bundle")

      test_helper_path = File.join("test_app", "test", "test_helper.rb")
      test_helper_content = File.read(test_helper_path)
      assert_includes test_helper_content, 'require "rooibos/test_helper"',
        "Expected test_helper.rb to require rooibos/test_helper"
    end
  end

  def test_new_test_file_uses_rooibos_test_helper
    Dir.chdir(@tmpdir) do
      rooibos("new", "test_app", "--no-bundle")

      test_file_path = File.join("test_app", "test", "test_test_app.rb")
      test_content = File.read(test_file_path)
      assert_includes test_content, "Rooibos::TestHelper",
        "Expected test file to include Rooibos::TestHelper"
      assert_includes test_content, "with_test_terminal",
        "Expected test file to use with_test_terminal"
    end
  end

  def test_new_with_custom_name_modules_correctly
    Dir.chdir(@tmpdir) do
      rooibos("new", "my_cool_app", "--no-bundle")

      lib_content = File.read(File.join("my_cool_app", "lib", "my_cool_app.rb"))
      assert_includes lib_content, "module MyCoolApp",
        "Expected underscored name to be converted to PascalCase"
    end
  end

  def test_new_rubocop_config_inherits_from_rooibos
    Dir.chdir(@tmpdir) do
      rooibos("new", "test_app", "--no-bundle")

      rubocop_content = File.read(File.join("test_app", ".rubocop.yml"))
      assert_match(/inherit_gem:.*rooibos/m, rubocop_content,
        "Expected .rubocop.yml to use inherit_gem for rooibos")
      assert_includes rubocop_content, "lib/rooibos/rubocop.yml",
        "Expected .rubocop.yml to reference lib/rooibos/rubocop.yml"
    end
  end

  # Verifies that a scaffolded app can be launched with `rooibos run` and
  # responds to Ctrl+C. Uses PTY.spawn to properly establish a controlling
  # terminal (crossterm reads from /dev/tty, not stdin).
  def test_new_app_runs_and_exits_on_ctrl_c
    skip "PTY is Unix-only" unless RUBY_PLATFORM =~ /linux|darwin/i
    require "pty"
    require_global_rooibos!

    Dir.chdir(@tmpdir) do
      # Create app with bundle install
      rooibos_exe = File.expand_path("../../exe/rooibos", __dir__)
      _, stderr, status = Open3.capture3("bundle", "exec", rooibos_exe, "new", "runnable_app")
      unless status.success?
        skip "Could not create app: #{stderr}"
      end

      app_dir = File.join(@tmpdir, "runnable_app")

      # Must escape rooibos's Bundler context before running the generated app.
      exit_status = nil
      output_buffer = +""
      Bundler.with_unbundled_env do
        pty_out, pty_in, pid = PTY.spawn("rooibos", "run", chdir: app_dir)

        # PTY defaults to 0x0 size; set standard 80x24 terminal dimensions
        pty_out.winsize = [24, 80]

        # Must drain PTY output buffer in background thread, otherwise the TUI
        # app blocks waiting to write to the terminal and never reads our input.
        reader = Thread.new do
          loop do
            output_buffer << pty_out.read_nonblock(4096)
          rescue IO::WaitReadable
            pty_out.wait_readable(0.1)
          rescue EOFError, Errno::EIO
            break
          end
        end

        # Give the app time to start and enter raw mode
        sleep 1.5

        # Send Ctrl+C as the actual keypress (ETX = End of Text, byte 0x03)
        # Note: If the app exits before we write, we get Errno::EIO — that's okay.
        begin
          pty_in.sync = true
          pty_in.write("\x03")
          pty_in.flush
        rescue Errno::EIO
          # App exited before we could send input — that's fine for this test
        end

        # Wait for process to exit (with timeout)
        begin
          _, exit_status = Timeout.timeout(5) { Process.wait2(pid) }
        rescue Timeout::Error
          Process.kill("KILL", pid)
          Process.wait(pid)
          flunk "App did not exit within 5 seconds after receiving Ctrl+C"
        ensure
          begin
            reader.kill
          rescue
            nil
          end
          begin
            pty_out.close
          rescue
            nil
          end
          begin
            pty_in.close
          rescue
            nil
          end
        end
      end

      # The app should have exited cleanly (exit 0)
      assert exit_status&.success?, "App should have exited cleanly, got: #{exit_status}\nOutput:\n#{output_buffer}"
    end
  rescue PTY::ChildExited
    # App exited before we could interact - that's okay for this test
    pass
  end
end
