# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "version"
require_relative "cli/commands/new"
require_relative "cli/commands/run"

module Rooibos
  # Entry point for the Rooibos command-line interface.
  #
  # Rooibos provides a CLI for common development tasks. Rather than
  # remembering incantations for each tool, use a single command.
  #
  # This module dispatches to subcommands. It routes <tt>new</tt> to
  # project scaffolding and <tt>run</tt> to application execution.
  #
  # Use it via the +rooibos+ executable.
  #
  # === Example
  #
  #   # From terminal:
  #   rooibos new my_app
  #   cd my_app
  #   rooibos run
  #
  #   # Programmatic access:
  #   Rooibos::CLI.call(["new", "my_app"])
  #   Rooibos::CLI.call(["run"])
  module CLI
    # Maps command names to handler modules.
    COMMANDS = { # :nodoc:
      "new" => Commands::New,
      "run" => Commands::Run,
    }.freeze

    # Entry point for the CLI.
    #
    # [argv] Command-line arguments array.
    def self.call(argv)
      command_name = argv.shift

      case command_name
      when "--version", "-v"
        puts "Rooibos #{Rooibos::VERSION}"
      when "--help", "-h", nil
        puts usage
      else
        command = COMMANDS[command_name]
        if command
          command.call(argv)
        else
          warn "Unknown command: #{command_name}"
          warn usage
          exit(1)
        end
      end
    end

    # Returns the main usage message.
    def self.usage
      <<~USAGE
        Usage: rooibos <command> [options]

        Commands:
          new <appname>  Create a new Rooibos application
          run            Run the application in the current directory

        Options:
          --version, -v  Show version
          --help, -h     Show this help
      USAGE
    end
  end
end
