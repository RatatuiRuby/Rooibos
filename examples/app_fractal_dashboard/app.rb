# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "ratatui_ruby"
require "rooibos"

# Demonstrates three approaches to UPDATE routing in Fractal Architecture.
#
# == Usage
#
#   ruby app.rb           # Defaults to 'manual'
#   ruby app.rb manual    # Verbose pattern matching
#   ruby app.rb helpers   # Rooibos.route and Rooibos.delegate helpers
#   ruby app.rb router    # Rooibos::Router DSL
#
# All three share the same fragments, Model, INITIAL, and VIEW. Only the UPDATE
# implementation differs. Compare the three update_*.rb files to see the
# progression from verbose to declarative.
#
# == Architecture
#
#   app.rb              ← Entry point (you are here)
#   dashboard/
#   ├── base.rb         ← Shared: Model, INITIAL, VIEW
#   ├── update_manual.rb
#   ├── update_helpers.rb
#   └── update_router.rb
#   fragments/
#   ├── system_info.rb
#   ├── disk_usage.rb
#   ├── ping.rb
#   ├── uptime.rb
#   ├── stats_panel.rb
#   └── network_panel.rb

VALID_MODES = %w[manual helpers router].freeze

mode = ARGV[0] || "manual"
unless VALID_MODES.include?(mode)
  warn "Usage: ruby app.rb [#{VALID_MODES.join('|')}]"
  exit 1
end

dashboard = case mode
            when "manual"
              require_relative "dashboard/update_manual"
              DashboardManual
            when "helpers"
              require_relative "dashboard/update_helpers"
              DashboardHelpers
            when "router"
              require_relative "dashboard/update_router"
              DashboardRouter
end

puts "Running with #{mode} UPDATE..."
Rooibos.run(fragment: dashboard)
