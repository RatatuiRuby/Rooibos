# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "shellwords"

module Rooibos
  module Command
    # Opens a file or URL with the system's default application.
    #
    # Terminal applications often need to hand off to external programs.
    # Opening a PDF, launching a URL, or viewing an image requires
    # platform-specific commands.
    #
    # This command detects the platform and runs the appropriate opener:
    # +open+ on macOS, +xdg-open+ on Linux, +start+ on Windows.
    #
    # On success (exit 0), sends +Message::Open+.
    # On failure (non-zero), sends +Message::Error+.
    #
    # === Example
    #
    #   def update(msg, model)
    #     case msg
    #     in :view_clicked
    #       [model, Command.open(model.selected_file)]
    #     in { type: :open, envelope: path }
    #       model.with(status: "Opened #{path}")
    #     in { type: :error, envelope: path }
    #       model.with(error: "Could not open #{path}")
    #     end
    #   end
    #
    class Open < Data.define(:path, :envelope)
      include Custom

      # Builds the platform-specific open command.
      def self.system_command(path, platform = RUBY_PLATFORM)
        escaped = path.shellescape
        case platform
        when /darwin/
          "open #{escaped} 2>/dev/null"
        when /linux/
          "xdg-open #{escaped} 2>/dev/null"
        when /mingw|mswin|cygwin/
          "start #{path} 2>NUL"
        else
          "xdg-open #{escaped} 2>/dev/null"
        end
      end

      # System commands are generally fast; no grace period needed.
      def rooibos_cancellation_grace_period = 0

      def call(out, token)
        return if token.canceled?

        require "open3"
        cmd = self.class.system_command(path)
        _stdout, stderr, status = Open3.capture3(cmd)

        message = if status.exitstatus == 0
          Message::Open.new(envelope:)
        else
          error_msg = stderr.empty? ? "Failed to open: #{path}" : stderr.strip
          Message::Error.new(
            command: envelope,
            exception: RuntimeError.new(error_msg.freeze).freeze
          )
        end

        out.put(Ractor.make_shareable(message))
      rescue => e
        out.put(Ractor.make_shareable(Message::Error.new(
          command: envelope,
          exception: RuntimeError.new(e.message.freeze).freeze
        )))
      end
    end
  end
end
