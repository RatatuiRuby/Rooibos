# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "rubygems"

namespace :install do
  desc "Force install rooibos gem globally (required for integration tests)"
  task :force do
    require "rooibos/version"

    # Build the gem first
    Rake::Task["build"].invoke

    gem_file = "pkg/rooibos-#{Rooibos::VERSION}.gem"
    unless File.exist?(gem_file)
      abort "Gem not found at #{gem_file}. Run 'rake build' first."
    end

    puts "Installing rooibos #{Rooibos::VERSION} globally..."
    system("gem", "install", gem_file, "--force", "--no-document") ||
      abort("Failed to install gem")

    puts "✓ rooibos #{Rooibos::VERSION} installed globally"
  end
end
