# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "rooibos/version"
require_relative "rooibos/error"
require_relative "rooibos/message"
require_relative "rooibos/command"
require_relative "rooibos/transition"
require_relative "rooibos/configuration"
require_relative "rooibos/runtime"
require_relative "rooibos/router"
require_relative "rooibos/welcome"

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
end
