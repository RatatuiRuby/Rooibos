# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "pty"
require "io/console"
require "tmpdir"
require "fileutils"

# PTY-based end-to-end tests for Rooibos::Runtime behavior.
#
# These tests spawn the runtime in a real pseudo-terminal to verify behaviors
# that require a controlling TTY. See doc/contributors/e2e_pty.md for details.
class TestRuntimePTY < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("rooibos-pty-test-")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
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

  # Writes a minimal Rooibos app to disk for PTY testing.
  def write_app(name, init_body:, update_body:, view_body:)
    app_dir = File.join(@tmpdir, name)
    lib_dir = File.join(app_dir, "lib")
    exe_dir = File.join(app_dir, "exe")

    FileUtils.mkdir_p(lib_dir)
    FileUtils.mkdir_p(exe_dir)

    # Write lib file
    File.write(File.join(lib_dir, "#{name}.rb"), <<~RUBY)
      # frozen_string_literal: true

      require "rooibos"

      module #{name.split('_').map(&:capitalize).join}
        Init = -> {
          #{init_body}
        }

        Update = -> (msg, model) {
          #{update_body}
        }

        View = -> (model, tui) {
          #{view_body}
        }
      end
    RUBY

    # Write executable
    exe_path = File.join(exe_dir, name)
    File.write(exe_path, <<~RUBY)
      #!/usr/bin/env ruby
      # frozen_string_literal: true

      require_relative "../lib/#{name}"

      Rooibos.run(#{name.split('_').map(&:capitalize).join})
    RUBY
    File.chmod(0o755, exe_path)

    # Write Gemfile
    File.write(File.join(app_dir, "Gemfile"), <<~RUBY)
      source "https://rubygems.org"
      gem "rooibos", "~> #{Rooibos::VERSION}"
    RUBY

    app_dir
  end

  # Runs an app in a PTY and returns captured output and exit status.
  def run_in_pty(app_dir, timeout: 5)
    output_buffer = +""
    exit_status = nil

    Bundler.with_unbundled_env do
      exe_name = File.basename(app_dir)
      exe_path = File.join(app_dir, "exe", exe_name)

      pty_out, pty_in, pid = PTY.spawn(exe_path, chdir: app_dir)
      pty_out.winsize = [24, 80]

      reader = Thread.new do
        loop do
          output_buffer << pty_out.read_nonblock(4096)
        rescue IO::WaitReadable
          pty_out.wait_readable(0.1)
        rescue EOFError, Errno::EIO
          break
        end
      end

      begin
        yield pty_in if block_given?

        _, exit_status = Timeout.timeout(timeout) { Process.wait2(pid) }
      rescue Timeout::Error
        Process.kill("KILL", pid)
        Process.wait(pid)
        flunk "App did not exit within #{timeout} seconds"
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

    { output: output_buffer, status: exit_status }
  end

  # Verifies Init runs after terminal is initialized.
  #
  # This test must use a real PTY because it verifies that the runtime
  # initializes the terminal before calling Init. The mocked with_test_terminal
  # helper stubs out init_terminal, hiding the real initialization order.
  def test_init_runs_after_terminal_initialized
    require_global_rooibos!

    # Create an app that captures terminal_size in Init (requires terminal ready)
    # and writes the result to a file so we can verify it.
    output_file = File.join(@tmpdir, "init_output.txt")

    app_dir = write_app("init_timing_test",
      init_body: <<~RUBY,
        size = RatatuiRuby.terminal_size
        File.write(#{output_file.inspect}, "width=\#{size.width},height=\#{size.height}")
        Ractor.make_shareable({ width: size.width })
      RUBY
      update_body: "Rooibos::Command.exit",
      view_body: "tui.clear"
    )

    result = run_in_pty(app_dir, timeout: 10) do |pty_in|
      # Give app time to start and write the file
      sleep 1.5

      # Send 'q' to trigger exit (Update returns Command.exit on any message)
      pty_in.sync = true
      pty_in.write("q")
      pty_in.flush
    end

    assert result[:status]&.success?, "App should exit cleanly, got: #{result[:status]}"
    assert File.exist?(output_file), "Init should have written output file"

    output = File.read(output_file)
    assert_match(/width=80/, output, "Init should capture terminal width")
    assert_match(/height=24/, output, "Init should capture terminal height")
  end
end
