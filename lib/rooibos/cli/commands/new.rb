# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "open3"
require "fileutils"
require "pathname"
require "optparse"

module Rooibos
  module CLI
    module Commands # :nodoc:
      # Scaffolds a new Rooibos TUI application.
      #
      # Starting a TUI project from scratch is tedious. Gem structure,
      # test setup, executable wiring, and dependency management all
      # take time before you write your first line of application code.
      #
      # This command delegates to +bundle gem+ for the boilerplate, then
      # customizes the result for Rooibos. It creates a working Model-View-Update
      # skeleton with a passing test.
      #
      # Use it to bootstrap new projects.
      #
      # === Example
      #
      #   rooibos new my_app
      #   rooibos new my_app --no-git
      #   rooibos new my_app --test=rspec  # warns about TestHelper
      module New
        # Default flags for bundle gem.
        # Note: We use --no-bundle so we can add rooibos to Gemfile first.
        BUNDLE_GEM_DEFAULTS = %w[
          --exe
          --no-coc
          --changelog
          --no-ext
          --git
          --no-mit
          --test=minitest
          --no-ci
          --linter=rubocop
          --no-bundle
        ].freeze

        # Runs the new command.
        #
        # [argv] Command-line arguments (expects app name as first element).
        def self.call(argv)
          options = parse_options(argv)

          if options[:help]
            puts usage
            exit(0)
          end

          if argv.empty?
            warn "Error: Missing application name"
            warn usage
            exit(1)
          end

          app_name = argv.shift
          passthrough_args = argv # Remaining args passed to bundle gem

          create_app(app_name, passthrough_args, options)
        end

        # Returns command-specific usage.
        def self.usage
          <<~USAGE
            Usage: rooibos new <appname> [options]

            Creates a new Rooibos TUI application using `bundle gem`.

            Arguments:
              <appname>   Name of the application to create

            Options:
              --help, -h  Show this help

            Bundle Gem Defaults (can be overridden):
              --exe           Create executable (enabled by default)
              --no-coc        No Code of Conduct (default)
              --changelog     Generate CHANGELOG.md (default)
              --no-ext        No native extension (default)
              --git           Initialize git repo (default)
              --no-mit        No MIT license (default)
              --test=minitest Use Minitest (default, recommended)
              --no-ci         No CI config (default)
              --linter=rubocop Use RuboCop (default)
              --bundle        Run bundle install (default)

            Any bundle gem option can be passed through, for example:
              rooibos new my_app --no-git
              rooibos new my_app --test=rspec  # warns about TestHelper

            Note: Rooibos::TestHelper is only verified to work with Minitest.
          USAGE
        end

        def self.parse_options(argv)
          options = { help: false, test_framework: "minitest", skip_bundle: false }

          # Extract --help before OptionParser to avoid conflicts with passthrough
          if argv.include?("--help") || argv.include?("-h")
            argv.delete("--help")
            argv.delete("-h")
            options[:help] = true
          end

          # Detect test framework from passthrough args
          argv.each do |arg|
            if arg.start_with?("--test=")
              options[:test_framework] = arg.sub("--test=", "")
            end
          end

          # Detect if user wants to skip bundle install
          if argv.include?("--no-bundle")
            options[:skip_bundle] = true
          end

          options
        end
        private_class_method :parse_options

        def self.create_app(app_name, passthrough_args, options)
          puts "Creating new Rooibos application: #{app_name}"

          # Warn about non-minitest frameworks
          test_framework = options[:test_framework].to_s
          if %w[rspec test-unit].include?(test_framework)
            warn "Warning: Rooibos::TestHelper has not been verified to work with #{test_framework}."
            warn "         You may need to adapt the test helpers for your framework."
          end

          # Build bundle gem command
          bundle_args = build_bundle_gem_args(passthrough_args)
          cmd = ["bundle", "gem", app_name] + bundle_args

          puts "Running: #{cmd.join(' ')}"
          stdout, stderr, status = Open3.capture3(*cmd)
          unless status.success?
            warn "Error running bundle gem:"
            warn stderr
            exit(1)
          end
          puts stdout

          # Determine the normalized gem name by looking at lib/
          app_path = Pathname.new(app_name)
          lib_path = app_path / "lib"
          lib_files = Dir.glob(lib_path / "*.rb")
          gem_name = lib_files.map { |f| File.basename(f, ".rb") }
            .reject { |n| n.end_with?("_version") }
            .first

          unless gem_name
            warn "Could not determine gem name from lib/ directory"
            exit(1)
          end

          module_name = to_module_name(gem_name)

          # Overwrite lib/<gem_name>.rb with Rooibos template
          lib_file = lib_path / "#{gem_name}.rb"
          File.write(lib_file.to_s, app_template(module_name))
          puts "Updated #{lib_file}"

          # Update the bundler-created executable to call Rooibos.run
          exe_file = app_path / "exe" / gem_name
          if exe_file.exist?
            File.write(exe_file.to_s, exe_template(gem_name, module_name))
            puts "Updated #{exe_file}"
          end

          # Add rooibos dependency to Gemfile with twiddle-waka constraint
          gemfile = app_path / "Gemfile"
          if gemfile.exist?
            content = File.read(gemfile.to_s)
            # Check for exact gem declaration to avoid false positives
            # (e.g., app named "rooibos_dashboard" contains "rooibos")
            unless content.match?(/^gem\s+["']rooibos["']/)
              # Use Gem::Version to handle prerelease versions correctly
              segments = Gem::Version.new(Rooibos::VERSION).segments
              minor_version = segments.first(2).map(&:to_s).join(".")
              File.open(gemfile.to_s, "a") do |f|
                f.puts ""
                f.puts "# https://rooibos.run"
                f.puts "gem \"rooibos\", \"~> #{minor_version}\""
              end
              puts "Added rooibos to #{gemfile}"
            end
          end

          # Run bundle install unless user passed --no-bundle
          unless options[:skip_bundle]
            Dir.chdir(app_path) do
              puts "Running bundle install..."
              system("bundle", "install")
            end
          end

          # Update test infrastructure for Rooibos
          if test_framework == "minitest"
            # Add rooibos/test_helper to the project's test_helper.rb
            test_helper = app_path / "test" / "test_helper.rb"
            if test_helper.exist?
              content = File.read(test_helper.to_s)
              unless content.include?("rooibos/test_helper")
                # Add after the gem require line
                content = content.sub(
                  /require\s+["']#{gem_name}["']/,
                  "\\0\nrequire \"rooibos/test_helper\""
                )
                File.write(test_helper.to_s, content)
                puts "Updated #{test_helper}"
              end
            end

            # Replace test file with real Rooibos test
            test_file = app_path / "test" / "test_#{gem_name}.rb"
            if test_file.exist?
              File.write(test_file.to_s, test_template(gem_name, module_name))
              puts "Updated #{test_file}"
            end
          end

          # Make initial git commit if git is enabled and bundle didn't
          if git_enabled?(passthrough_args)
            make_initial_commit(app_path)
          end

          puts "\nDone! Your Rooibos application is ready."
          puts "  cd #{app_name}"
          puts "  rooibos run"
        end
        private_class_method :create_app

        def self.build_bundle_gem_args(passthrough_args)
          # Start with defaults
          args = BUNDLE_GEM_DEFAULTS.dup

          # Override with user-provided args (later args win in bundle gem)
          args + passthrough_args
        end
        private_class_method :build_bundle_gem_args

        def self.git_enabled?(passthrough_args)
          # Git is enabled by default unless --no-git is passed
          !passthrough_args.include?("--no-git")
        end
        private_class_method :git_enabled?

        def self.make_initial_commit(app_path)
          Dir.chdir(app_path) do
            # Check if there are uncommitted changes
            _, _, status = Open3.capture3("git", "status", "--porcelain")
            return unless status.success?

            uncommitted, = Open3.capture3("git", "status", "--porcelain")
            return if uncommitted.strip.empty?

            # Stage and commit
            system("git", "add", "-A", out: File::NULL, err: File::NULL)
            system("git", "commit", "-m", "Hello, Rooibos!\n\nhttps://rooibos.run",
              out: File::NULL, err: File::NULL)
            puts "Created initial git commit"
          end
        end
        private_class_method :make_initial_commit

        def self.to_module_name(gem_name)
          gem_name.split(/[-_]/).map(&:capitalize).join
        end
        private_class_method :to_module_name

        def self.exe_template(gem_name, module_name)
          <<~RUBY
            #!/usr/bin/env ruby
            # frozen_string_literal: true

            require "#{gem_name}"
            Rooibos.run(#{module_name})
          RUBY
        end
        private_class_method :exe_template

        def self.app_template(module_name)
          <<~RUBY
            # frozen_string_literal: true

            require "rooibos"

            module #{module_name}
              Model = Data.define

              View = -> (model, tui) {
                tui.paragraph(text: "Hello, Rooibos! (press Control + C to quit)")
              }

              Update = -> (message, model) {
                if message.ctrl_c?
                  Rooibos::Command.exit
                else
                  model
                end
              }

              Init = -> {
                Ractor.make_shareable Model.new
              }
            end
          RUBY
        end
        private_class_method :app_template

        def self.test_template(gem_name, module_name)
          <<~RUBY
            # frozen_string_literal: true

            require "test_helper"

            class Test#{module_name} < Minitest::Test
              include Rooibos::TestHelper

              def test_it_exits_with_ctrl_c
                with_test_terminal do
                  inject_key(:ctrl_c)
                  Rooibos.run(#{module_name})
                  assert true, "Should reach this point without hanging."
                end
              end
            end
          RUBY
        end
        private_class_method :test_template
      end
    end
  end
end
