# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "command"
require_relative "message"

module Rooibos
  # Convenient short aliases for Rooibos APIs.
  #
  # The library uses intention-revealing names that match Ruby built-ins:
  # +Command+, +System+, +Exit+. These are great for readability.
  #
  # This module provides the short aliases common in TEA-style code:
  #
  # === Example
  #
  #   require "rooibos/shortcuts"
  #   include Rooibos::Shortcuts
  #
  #   # Now use short names freely:
  #   Cmd.exit               # → Command.exit
  #   Cmd.sh("ls", :files)   # → Command.system("ls", :files)
  #   Cmd.map(child) { ... } # → Command.map(child) { ... }
  module Shortcuts
    # Short alias for +Command+.
    module Cmd
      # Creates an exit command.
      # Alias for +Command.exit+.
      def self.exit
        Command.exit
      end

      # Creates a shell execution command.
      # Short alias for +Command.system+.
      def self.sh(command, envelope)
        Command.system(command, envelope)
      end

      # Creates a mapped command.
      # Short alias for +Command.map+.
      def self.map(inner_command, &mapper)
        Command.map(inner_command, &mapper)
      end
    end

    # Short aliases for +Message+ types.
    #
    # App developers pattern-match against message types frequently.
    # The full names (+Rooibos::Message::HttpResponse+) are verbose.
    # These shortcuts save characters and improve readability.
    #
    # === Example
    #
    #   case message
    #   in Msg::Timer[envelope: :dismiss]
    #     [model.with(notification: nil), nil]
    #   in Msg::Http[status: 200, body:]
    #     [model.with(data: JSON.parse(body)), nil]
    #   in Msg::Sh::Batch[status: 0, stdout:]
    #     [model.with(output: stdout), nil]
    #   end
    module Msg
      # Timer message type.
      # Alias for +Message::Timer+.
      Timer = Message::Timer

      # HTTP response message type.
      # Alias for +Message::HttpResponse+.
      Http = Message::HttpResponse

      # Shell command message types.
      # Mirrors +Cmd.sh+ for symmetry.
      module Sh
        # Batch mode shell output.
        # Alias for +Message::System::Batch+.
        Batch = Message::System::Batch

        # Streaming mode shell output.
        # Alias for +Message::System::Stream+.
        Stream = Message::System::Stream
      end

      # Aggregated parallel results.
      # Alias for +Message::All+.
      All = Message::All

      # Batch completion signal.
      # Alias for +Message::Batch+.
      Batch = Message::Batch
    end
  end
end
