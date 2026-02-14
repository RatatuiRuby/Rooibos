# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "file_browser"
require "rooibos/test_helper"
require "fileutils"
require "tmpdir"

require "minitest/autorun"

module TestDirectoryHelper
  EXAMPLE_FILES = %w[lib/ lib/file_browser.rb test/ test/test_file_browser.rb Gemfile README.md].freeze

  private def with_test_directory(entries, &block)
    Dir.mktmpdir do |dir|
      entries.each do |name|
        if name.end_with?("/")
          FileUtils.mkdir_p(File.join(dir, name))
        else
          FileUtils.touch(File.join(dir, name))
        end
      end
      Dir.stub(:pwd, dir, &block)
    end
  end

  private def with_example_files(&)
    with_test_directory(EXAMPLE_FILES, &)
  end

  private def routed(envelope)
    Rooibos::Message::Routed.new(envelope:, event: nil)
  end
end
