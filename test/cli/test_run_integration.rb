# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "open3"
require "tmpdir"
require "fileutils"
require "pty"
require "io/console"

# Integration tests for `rooibos run` command.
class TestCLIRunIntegration < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("rooibos-run-test-")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
  end

  def rooibos(*)
    exe = File.expand_path("../../exe/rooibos", __dir__)
    Open3.capture3("bundle", "exec", exe, *)
  end

  # Helper to skip tests if matching rooibos version is not installed globally.
  def require_global_rooibos!
    require "rooibos/version"
    installed = Gem::Specification.find_all_by_name("rooibos", Rooibos::VERSION)
    if installed.empty?
      flunk "Rooibos #{Rooibos::VERSION} not installed globally. Run: rake install:force"
    end
  end

  # Verifies that when a Rooibos app crashes, the stack trace does not contain
  # Bundler CLI frames (bundler/cli, thor). This ensures clean developer experience.
  def test_run_produces_clean_stack_traces
    require_global_rooibos!

    Dir.chdir(@tmpdir) do
      # Create app
      rooibos_exe = File.expand_path("../../exe/rooibos", __dir__)
      _, stderr, status = Open3.capture3("bundle", "exec", rooibos_exe, "new", "crashing_app")
      unless status.success?
        skip "Could not create app: #{stderr}"
      end

      app_dir = File.join(@tmpdir, "crashing_app")

      # Inject a crash into the app's Init
      lib_file = File.join(app_dir, "lib", "crashing_app.rb")
      content = File.read(lib_file)
      content = content.sub(
        /Init = -> \{/,
        "Init = -> {\n    raise \"Deliberate crash for testing\""
      )
      File.write(lib_file, content)

      # Run the app via rooibos run and capture the crash output
      output_buffer = +""
      Bundler.with_unbundled_env do
        pty_out, _pty_in, pid = PTY.spawn("rooibos", "run", chdir: app_dir)
        pty_out.winsize = [24, 80]

        # Read all output until the process exits
        begin
          Timeout.timeout(10) do
            loop do
              output_buffer << pty_out.read_nonblock(4096)
            rescue IO::WaitReadable
              pty_out.wait_readable(0.1)
            rescue EOFError, Errno::EIO
              break
            end
          end
        rescue Timeout::Error
          Process.kill("KILL", pid) rescue nil
        end

        Process.wait(pid) rescue nil
        pty_out.close rescue nil
      end

      # The output should contain our crash message
      assert_includes output_buffer, "Deliberate crash for testing",
        "Expected output to contain the crash message"

      # The stack trace should NOT contain bundler CLI frames
      refute_match %r{/bundler/cli/}, output_buffer,
        "Stack trace should not contain bundler/cli frames"
      refute_match %r{/bundler/vendor/thor/}, output_buffer,
        "Stack trace should not contain thor frames"
    end
  rescue PTY::ChildExited
    # Expected - the app crashed
    pass
  end
end
