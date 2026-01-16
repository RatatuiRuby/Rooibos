# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestNormalizeUpdateWarnings < Minitest::Test
  def test_warns_in_debug_mode_for_callable_without_rooibos_command
    # Direct test of normalize_update_return warning via normalize_init public API
    bad_command = Object.new
    def bad_command.call(_out, _token); end

    model = { test: true }.freeze

    warning_output = nil
    original_stderr = $stderr
    $stderr = StringIO.new
    begin
      RatatuiRuby::Debug.enable!(source: :test) # Ensure debug enabled
      # normalize_init calls normalize_update_return internally
      Rooibos.normalize_init([model, bad_command])
    ensure
      warning_output = $stderr.string
      $stderr = original_stderr
    end

    assert_match(/WARNING/, warning_output)
    assert_match(/rooibos_command\?/, warning_output)
    assert_match(/Command::Custom/, warning_output)
  end

  def test_no_warning_for_proper_commands
    good_command = Rooibos::Command.exit
    model = { test: true }.freeze

    warning_output = nil
    original_stderr = $stderr
    $stderr = StringIO.new
    begin
      Rooibos.normalize_init([model, good_command])
    ensure
      warning_output = $stderr.string
      $stderr = original_stderr
    end

    refute_match(/WARNING/, warning_output)
  end

  def test_no_warning_for_nil_commands
    model = { test: true }.freeze

    warning_output = nil
    original_stderr = $stderr
    $stderr = StringIO.new
    begin
      Rooibos.normalize_init([model, nil])
    ensure
      warning_output = $stderr.string
      $stderr = original_stderr
    end

    refute_match(/WARNING/, warning_output)
  end

  def test_no_warning_for_shareable_tuple_with_callable
    # If they return Ractor.make_shareable([foo, callable]), they clearly
    # intended the tuple itself to be the model, not [model, command]
    callable_data = Data.define do
      def call(x); x + 1; end
    end
    callable = callable_data.new
    model = { test: true }
    shareable_tuple = Ractor.make_shareable([model, callable])

    warning_output = nil
    original_stderr = $stderr
    $stderr = StringIO.new
    begin
      RatatuiRuby::Debug.enable!(source: :test)
      Rooibos.normalize_init(shareable_tuple)
    ensure
      warning_output = $stderr.string
      $stderr = original_stderr
    end

    refute_match(/WARNING/, warning_output,
      "Should not warn for Ractor.make_shareable([model, callable]) - clear intent as model")
  end
end
