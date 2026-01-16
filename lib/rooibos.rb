# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "rooibos/version"
require_relative "rooibos/error"
require_relative "rooibos/message"
require_relative "rooibos/command"
require_relative "rooibos/runtime"
require_relative "rooibos/router"

# The Elm Architecture for Ruby.
#
# Building TUI applications means managing state, events, and rendering. Mixing them leads to
# spaghetti code. Bugs hide in the tangles.
#
# This module implements The Elm Architecture (TEA). It separates your application into three
# pure functions: model, view, and update. The runtime handles the rest.
#
# Use it to build applications with predictable, testable state management.
module Rooibos
  # Starts the MVU event loop.
  #
  # Convenience delegator to Runtime.run. See Runtime for full documentation.
  def self.run(root_fragment = nil, **)
    Runtime.run(root_fragment, **)
  end

  # Normalizes Init callable return value to <tt>[model, command]</tt> tuple.
  #
  # Init callables use DWIM syntax. They can return just a model, just a command,
  # or a full <tt>[model, command]</tt> tuple.
  #
  # This method handles all formats. Use it when composing child fragment Inits
  # in fractal architecture.
  #
  # [result] The Init return value.
  #
  # === Examples
  #
  #--
  # SPDX-SnippetBegin
  # SPDX-FileCopyrightText: 2026 Kerrick Long
  # SPDX-License-Identifier: MIT-0
  #++
  #   # Parent fragment composes children
  #   Init = ->(theme:) do
  #     stats_model, stats_cmd = Rooibos.normalize_init(StatsPanel::Init.(theme: theme))
  #     network_model, network_cmd = Rooibos.normalize_init(NetworkPanel::Init.(theme: theme))
  #
  #     model = Model.new(stats: stats_model, network: network_model)
  #     command = Command.batch(stats_cmd, network_cmd)
  #     [model, command]
  #   end
  #--
  # SPDX-SnippetEnd
  #++
  def self.normalize_init(result)
    Runtime.normalize_init(result)
  end

  # Wraps a command with a routing prefix.
  #
  # Parent fragments trigger child fragment commands. The results need routing back
  # to the correct child fragment. Manually wrapping every command is tedious.
  #
  # This method prefixes command results automatically. Use it to route
  # child fragment command results in Fractal Architecture.
  #
  # [command] The child fragment command to wrap.
  # [prefix] Symbol prepended to results (e.g., <tt>:stats</tt>).
  #
  # === Example
  #
  #   # Verbose:
  #   Command.map(child_fragment.fetch_command) { |r| [:stats, *r] }
  #
  #   # Concise:
  #   Rooibos.route(child_fragment.fetch_command, :stats)
  def self.route(command, prefix)
    Command.map(command) { |result| [prefix, *result] }
  end

  # Delegates a prefixed message to a child fragment's UPDATE.
  #
  # Parent fragment UPDATE functions route messages to child fragments. Each route
  # requires pattern matching, calling the child, and rewrapping any returned
  # command. The boilerplate adds up fast.
  #
  # This method handles the dispatch. It checks the prefix, calls the child,
  # and wraps any command. Returns <tt>nil</tt> if the prefix does not match.
  #
  # [message] Incoming message (e.g., <tt>[:stats, :system_info, {...}]</tt>).
  # [prefix] Expected prefix symbol (e.g., <tt>:stats</tt>).
  # [child_update] The child's UPDATE callable.
  # [child_model] The child's current model.
  #
  # === Example
  #
  #   # Verbose:
  #   case message
  #   in [:stats, *rest]
  #     new_child, cmd = StatsPanel::UPDATE.call(rest, model.stats)
  #     mapped = cmd ? Command.map(cmd) { |r| [:stats, *r] } : nil
  #     [new_child, mapped]
  #   end
  #
  #   # Concise:
  #   Rooibos.delegate(message, :stats, StatsPanel::UPDATE, model.stats)
  def self.delegate(message, prefix, child_update, child_model)
    return nil unless message.is_a?(Array) && message.first == prefix

    rest = message[1..]
    new_child, command = child_update.call(rest, child_model)
    wrapped = command ? route(command, prefix) : nil
    [new_child, wrapped]
  end
end
