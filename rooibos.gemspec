# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "lib/rooibos/version"

Gem::Specification.new do |spec|
  spec.name = "rooibos"
  spec.version = Rooibos::VERSION
  spec.authors = ["Kerrick Long"]
  spec.email = ["me@kerricklong.com"]

  spec.summary = "Part of the RatatuiRuby ecosystem"
  spec.description = "Rooibos - part of the RatatuiRuby TUI framework ecosystem"
  spec.homepage = "https://rooibos.run"
  spec.license = "LGPL-3.0-or-later"
  spec.required_ruby_version = [">= 3.2.9", "< 5"]

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["bug_tracker_uri"] = "https://todo.sr.ht/~kerrick/ratatui_ruby"
  spec.metadata["mailing_list_uri"] = "https://lists.sr.ht/~kerrick/ratatui_ruby-discuss"
  spec.metadata["source_code_uri"] = "https://git.sr.ht/~kerrick/rooibos"
  spec.metadata["changelog_uri"] = "https://git.sr.ht/~kerrick/rooibos/tree/stable/item/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://git.sr.ht/~kerrick/rooibos/tree/HEAD/doc/index.md"
  spec.metadata["wiki_uri"] = "https://man.sr.ht/~kerrick/ratatui_ruby/"
  spec.metadata["funding_uri"] = "https://opencollective.com/ratatui"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.end_with?(".gitkeep") ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ratatui_ruby", "~> 0.10.1"
  spec.add_dependency "ostruct", "~> 0.6"
  spec.add_dependency "concurrent-ruby", "~> 1.3"
  spec.add_dependency "concurrent-ruby-edge", "~> 0.7"
  spec.add_development_dependency "rdoc", "~> 7.0"
  spec.add_development_dependency "faker", "~> 3.5"
  spec.add_development_dependency "minitest-mock", "~> 5.27"
end
