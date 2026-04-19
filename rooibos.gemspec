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

  spec.summary = "☕ Confidently Build Terminal Apps"
  spec.description = File.read(File.expand_path("README.rdoc", __dir__))
  spec.homepage = "https://rooibos.run"
  spec.license = "LGPL-3.0-or-later"
  spec.required_ruby_version = [">= 3.3.11", "< 5"]

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["bug_tracker_uri"] = "https://forum.setdef.com/tags/c/rooibos/bug"
  spec.metadata["mailing_list_uri"] = "https://forum.setdef.com/c/rooibos"
  spec.metadata["source_code_uri"] = "https://github.com/setdef/Rooibos"
  spec.metadata["changelog_uri"] = "https://rooibos.run/docs/trunk/CHANGELOG_md.html"
  spec.metadata["documentation_uri"] = "https://rooibos.run/docs/"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  root_allowlist = %w[LICENSE REUSE.toml]
  dir_denylist = %w[bin/ test/ spec/ features/ doc/ examples/ tasks/ .git .github appveyor Gemfile]

  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).select do |f|
      next false if f == gemspec
      next true if root_allowlist.include?(f)
      next false unless f.include?("/")
      !f.start_with?(*dir_denylist)
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ratatui_ruby", "~> 1.5"
  spec.add_dependency "concurrent-ruby", "~> 1.3"
  spec.add_dependency "concurrent-ruby-edge", "~> 0.7"
  spec.add_dependency "ostruct", "~> 0.6"
  spec.add_development_dependency "rdoc", "~> 7.0"
  spec.add_development_dependency "faker", "~> 3.5"
  spec.add_development_dependency "minitest-mock"
  spec.add_development_dependency "steep"
  spec.add_development_dependency "debug", ">= 1.0"
end
