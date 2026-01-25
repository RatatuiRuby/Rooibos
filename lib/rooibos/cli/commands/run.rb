# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "pathname"
require "rbconfig"

module Rooibos
  module CLI
    module Commands
      # Runs the Rooibos application in the current directory.
      #
      # Developers switch between editor and terminal constantly. Typing
      # +bundle exec exe/my_app+ every time is tedious and error-prone.
      #
      # This command finds the executable in +exe/+ and runs it via bundler.
      # It walks up the directory tree to find the project root, then
      # executes the first executable it finds.
      #
      # Use it from any directory within your project.
      #
      # === Example
      #
      #   rooibos run
      module Run
        # Runs the run command.
        #
        # [argv] Command-line arguments.
        def self.call(argv)
          if ["--help", "-h"].include?(argv.first)
            puts usage
            exit(0)
          end

          run_app
        end

        # Returns command-specific usage.
        def self.usage # :nodoc:
          <<~USAGE
            Usage: rooibos run [options]

            Runs the Rooibos application in the current directory.

            Options:
              --help, -h  Show this help
          USAGE
        end
        private_class_method :usage

        def self.run_app # :nodoc:
          project_root = find_project_root
          unless project_root
            warn "Error: Not in a Rooibos project directory"
            warn "Could not find a .gemspec or Gemfile"
            exit(1)
          end

          exe_dir = project_root / "exe"
          unless exe_dir.directory?
            warn "Error: No exe/ directory found"
            exit(1)
          end

          executables = Dir.glob(exe_dir / "*").select { |f| File.executable?(f) }
          if executables.empty?
            warn "Error: No executable found in exe/"
            exit(1)
          end

          executable = executables.first
          puts "Running #{File.basename(executable)}..."

          # Run with bundler/setup for gem activation, but skip bundle exec CLI
          # to produce clean stack traces without bundler/thor frames
          Dir.chdir(project_root)
          exec(RbConfig.ruby, "-rbundler/setup", executable)
        end
        private_class_method :run_app

        def self.find_project_root # :nodoc:
          current = Pathname.pwd
          loop do
            return current if (current / "Gemfile").exist?
            return current if Dir.glob(current / "*.gemspec").any?
            parent = current.parent
            return nil if parent == current
            current = parent
          end
        end
        private_class_method :find_project_root
      end
    end
  end
end
