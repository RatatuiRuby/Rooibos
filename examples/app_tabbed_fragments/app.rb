# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "ratatui_ruby"
require "rooibos"
require_relative "fragments/app"

# Tabbed Fragments Example
#
# Demonstrates every documented Router API:
# - route (basic)
# - action (named)
# - forward_events (with as: and route_to blocks)
# - forward_routed (envelope transformation with as:)
# - forward_instances_of (broadcast: true)
# - receive_events, receive_routed, receive_instances_of
# - intercept_events, intercept_all (with unless: guard)
# - observe, observe_all, observe_instances_of
# - only/skip guards
# - otherwise
# - Command.bubble, Command.deliver
# - Message::Predicates
#
# Usage:
#   ruby app.rb
#
# Controls:
#   [/] - Switch tabs
#   Click on tabs - Select tab
#   t - Cycle theme (cyan → green → magenta → yellow)
#   q / Ctrl+C - Quit
#
#   Counter Tab:
#     1-4 - Increment leaves (LT, LB, RT, RB)
#     a/b - Increment panels (Left, Right)
#     Enter - Increment root
#
#   Color Tab:
#     ↑/k, ↓/j - Scroll through colors
#     Enter/Space - Select color

puts "Starting Tabbed Fragments Example..."
puts "Press q or Ctrl+C to quit."
puts

Rooibos.run(App)
