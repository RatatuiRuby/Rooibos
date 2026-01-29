# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestFragmentFirstAPI < Minitest::Test
  include Rooibos::TestHelper

  # Class-scope fixtures for Ractor shareability
  @@init_called = false

  def teardown
    @@init_called = false
  end

  module FragmentFixture
    Model = Data.define(:initialized)

    module Init
      def self.call
        TestFragmentFirstAPI.class_variable_set(:@@init_called, true)
        Ractor.make_shareable(Model.new(initialized: true))
      end
    end

    module View
      def self.call(_model, tui)
        tui.clear
      end
    end

    module Update
      def self.call(_msg, _model)
        Rooibos::Command.exit
      end
    end
  end

  def test_fragment_first_api_calls_init
    @@init_called = false

    with_test_terminal do
      inject_key("q")
      Rooibos.run(FragmentFixture)
    end

    assert @@init_called, "Fragment Init should have been called"
  end

  # Fixtures for error tests - these should raise before callable validation
  module ErrorTestFragment
    Model = Data.define(:value)

    module Init
      def self.call
        Ractor.make_shareable(Model.new(value: 1))
      end
    end

    module View
      def self.call(_model, tui)
        tui.clear
      end
    end

    module Update
      def self.call(_msg, _model)
        Rooibos::Command.exit
      end
    end
  end

  def test_raises_invariant_error_when_both_fragment_and_model_provided
    model = ErrorTestFragment::Model.new(value: 2)

    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        Rooibos.run(ErrorTestFragment, model:)
      end
    end

    assert_match(/fragment.*model/i, error.message)
  end

  module ExtraViewFixture
    def self.call(_m, tui)
      tui.clear
    end
  end

  def test_raises_invariant_error_when_both_fragment_and_view_provided
    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        Rooibos.run(ErrorTestFragment, view: ExtraViewFixture)
      end
    end

    assert_match(/fragment.*view/i, error.message)
  end

  module ExtraUpdateFixture
    def self.call(_m, _mdl)
      Rooibos::Command.exit
    end
  end

  def test_raises_invariant_error_when_both_fragment_and_update_provided
    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        Rooibos.run(ErrorTestFragment, update: ExtraUpdateFixture)
      end
    end

    assert_match(/fragment.*update/i, error.message)
  end

  def test_raises_invariant_error_when_both_fragment_and_command_provided
    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        Rooibos.run(ErrorTestFragment, command: Rooibos::Command.exit)
      end
    end

    assert_match(/fragment.*command/i, error.message)
  end
end
