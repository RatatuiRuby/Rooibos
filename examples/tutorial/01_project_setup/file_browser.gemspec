# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require_relative "lib/file_browser/version"

Gem::Specification.new do |spec|
  spec.name = "file_browser"
  spec.version = FileBrowser::VERSION
  spec.authors = ["Author"]
  spec.email = ["author@example.com"]

  spec.summary = "A Rooibos TUI application"
  spec.description = "A terminal user interface application built with Rooibos"
  spec.homepage = "https://www.rooibos.run"
  spec.required_ruby_version = ">= 3.3.11"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile test/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html

  # https://www.rooibos.run
  spec.add_runtime_dependency "rooibos", "~> 0.6"
end
